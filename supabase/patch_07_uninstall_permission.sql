-- =============================================================================
-- Patch 07: PIN dari orang tua untuk menghapus AURA
--
-- Di HP anak, AURA dilindungi sebagai admin perangkat, sehingga Android menolak
-- menghapusnya. Untuk menghapusnya, anak meminta PIN. PIN dibuat di sini, di
-- basis data, dan hanya bisa dibaca orang tua: muncul di notifikasi HP orang
-- tua (Edge Function notify-parents) dan di aplikasinya. Anak memasukkan PIN
-- itu; pemeriksaannya juga di sini. Bila benar, AURA di HP anak melepas
-- perlindungannya dan membuka dialog hapus aplikasi.
--
-- Jalankan sekali di Supabase SQL Editor. Aman dijalankan ulang, juga bila
-- versi awal patch ini (tombol Izinkan) sudah pernah dijalankan.
-- =============================================================================

-- Dilaporkan HP anak: AURA aktif sebagai admin perangkat.
alter table public.profiles add column if not exists uninstall_protected boolean;

-- Kapan anak terakhir meminta PIN.
alter table public.profiles add column if not exists uninstall_requested_at timestamptz;

-- Versi awal patch ini memakai tombol Izinkan; tidak dipakai lagi.
alter table public.profiles drop column if exists uninstall_answer;

-- Satu PIN aktif per anak. Tidak ada yang menulis langsung: hanya lewat
-- fungsi di bawah. Anak tidak bisa membacanya.
create table if not exists public.uninstall_pins (
  child_id     uuid primary key references public.profiles on delete cascade,
  family_id    uuid not null references public.families on delete cascade,
  pin          text not null check (pin ~ '^[0-9]{6}$'),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  attempts     int not null default 0,
  -- Diisi saat PIN dipakai anak atau dibatalkan orang tua.
  closed_at    timestamptz,
  closed_by    text check (closed_by in ('used', 'cancelled'))
);

alter table public.uninstall_pins enable row level security;

drop policy if exists uninstall_pins_read on public.uninstall_pins;
create policy uninstall_pins_read on public.uninstall_pins for select
  using (public.my_role() = 'parent' and family_id = public.my_family_id());

revoke insert, update, delete on public.uninstall_pins from anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'uninstall_pins'
  ) then
    alter publication supabase_realtime add table public.uninstall_pins;
  end if;
end
$$;

-- Penjaga profil kembali seperti patch 06: orang tua hanya boleh menyalakan/
-- menjeda perlindungan anak dan mengatur jam istirahatnya.
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'Peran pengguna tidak dapat diubah.'
      using errcode = 'check_violation';
  end if;

  if auth.uid() is distinct from old.id then
    if (to_jsonb(new) - 'protection_active' - 'lock_schedule')
       = (to_jsonb(old) - 'protection_active' - 'lock_schedule')
    then
      return new;
    end if;

    raise exception 'Hanya pemilik profil yang dapat mengubah data ini.'
      using errcode = 'insufficient_privilege';
  end if;

  if old.role = 'child'
     and new.lock_schedule is distinct from old.lock_schedule then
    raise exception 'Jam istirahat hanya bisa diubah orang tua.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

-- HP anak meminta PIN. Mengembalikan kapan PIN-nya kedaluwarsa, bukan
-- PIN-nya.
create or replace function public.request_uninstall_pin()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  me public.profiles%rowtype;
  active_pin public.uninstall_pins%rowtype;
  code text;
  expires timestamptz := now() + interval '30 minutes';
begin
  select * into me from public.profiles where id = auth.uid();
  if not found or me.role <> 'child' or me.family_id is null then
    raise exception 'Hanya HP anak yang tertaut yang bisa meminta PIN.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Supaya HP orang tua tidak dibanjiri notifikasi.
  select * into active_pin from public.uninstall_pins where child_id = me.id;
  if found and active_pin.closed_at is null and active_pin.expires_at > now()
     and active_pin.created_at > now() - interval '1 minute' then
    raise exception 'Tunggu sebentar sebelum meminta PIN lagi.'
      using errcode = 'check_violation';
  end if;

  -- 6 angka dari bilangan acak yang kuat (gen_random_uuid).
  code := lpad((
    (('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
      ::bit(32)::int::bigint + 2147483648) % 1000000
  )::text, 6, '0');

  insert into public.uninstall_pins
    (child_id, family_id, pin, created_at, expires_at, attempts, closed_at, closed_by)
  values (me.id, me.family_id, code, now(), expires, 0, null, null)
  on conflict (child_id) do update
    set family_id = excluded.family_id,
        pin = excluded.pin,
        created_at = excluded.created_at,
        expires_at = excluded.expires_at,
        attempts = 0,
        closed_at = null,
        closed_by = null;

  update public.profiles set uninstall_requested_at = now() where id = me.id;
  return expires;
end;
$$;

-- HP anak memasukkan PIN dari orang tua. Mengembalikan 'ok', 'wrong',
-- 'locked' (5 kali salah), 'expired', atau 'none'. PIN hanya bisa dipakai
-- sekali.
create or replace function public.verify_uninstall_pin(entered text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  active_pin public.uninstall_pins%rowtype;
begin
  select * into active_pin
    from public.uninstall_pins
   where child_id = auth.uid()
     for update;

  if not found or active_pin.closed_at is not null then
    return 'none';
  end if;
  if active_pin.expires_at <= now() then
    return 'expired';
  end if;
  if active_pin.attempts >= 5 then
    return 'locked';
  end if;

  if active_pin.pin = trim(entered) then
    update public.uninstall_pins
       set closed_at = now(), closed_by = 'used'
     where child_id = auth.uid();
    return 'ok';
  end if;

  update public.uninstall_pins
     set attempts = attempts + 1
   where child_id = auth.uid();
  return case when active_pin.attempts + 1 >= 5 then 'locked' else 'wrong' end;
end;
$$;

-- Orang tua membatalkan PIN yang belum dipakai (tidak mengizinkan).
create or replace function public.cancel_uninstall_pin(child uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.my_role() is distinct from 'parent' then
    raise exception 'Hanya orang tua yang bisa membatalkan PIN.'
      using errcode = 'insufficient_privilege';
  end if;

  update public.uninstall_pins
     set closed_at = now(), closed_by = 'cancelled'
   where child_id = child
     and family_id = public.my_family_id()
     and closed_at is null;
end;
$$;

revoke all on function public.request_uninstall_pin() from public, anon;
revoke all on function public.verify_uninstall_pin(text) from public, anon;
revoke all on function public.cancel_uninstall_pin(uuid) from public, anon;
grant execute on function public.request_uninstall_pin() to authenticated;
grant execute on function public.verify_uninstall_pin(text) to authenticated;
grant execute on function public.cancel_uninstall_pin(uuid) to authenticated;
