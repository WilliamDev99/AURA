-- =============================================================================
-- Skema basis data AURA untuk Supabase (PostgreSQL)
--
-- Cara memakai: buka Supabase Dashboard > SQL Editor > New query, tempel
-- seluruh isi berkas ini, lalu Run. Aman dijalankan ulang.
--
-- Prinsip yang ditegakkan di sini sama dengan versi Firestore, tetapi lebih
-- kuat karena dijamin oleh basis datanya sendiri:
--   1. Bukti bersifat sekali tulis. Tidak ada peran mana pun dari sisi klien
--      yang bisa mengubah atau menghapusnya.
--   2. Ruang curhat anak dengan AI Guardian tidak bisa dibaca orang tua.
--   3. Perangkat anak boleh memunculkan peringatan, tetapi tidak boleh
--      menutupnya.
-- =============================================================================

create extension if not exists pgcrypto;



create table if not exists public.families (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  owner_id           uuid not null references auth.users on delete cascade,
  pairing_code       text unique,
  pairing_expires_at timestamptz,
  created_at         timestamptz not null default now()
);

create table if not exists public.profiles (
  id                    uuid primary key references auth.users on delete cascade,
  name                  text not null,
  role                  text not null check (role in ('parent', 'child')),
  family_id             uuid references public.families on delete set null,
  age                   int check (age is null or (age between 3 and 17)),
  device_label          text,
 
  monitoring_consent_at timestamptz,
  last_seen_at          timestamptz,
  protection_active     boolean not null default true,
  -- Nomor orang tua untuk telepon otomatis saat SOS (format +628...).
  phone                 text check (phone is null or phone ~ '^\+628[0-9]{8,12}$'),
  -- Dilaporkan ponsel anak: apakah "Akses notifikasi" untuk AURA menyala.
  chat_scan_enabled     boolean,
  chat_scan_checked_at  timestamptz,
  -- Letak foto profil di Storage (bucket privat "avatars").
  avatar_path           text,
  -- Jam istirahat anak, diatur orang tua (lihat patch_06_lock_schedule.sql).
  lock_schedule         jsonb,
  -- Dilaporkan ponsel anak: izin untuk mengunci aplikasi sudah diberikan.
  lock_ready            boolean,
  created_at            timestamptz not null default now()
);

create table if not exists public.alerts (
  id               uuid primary key default gen_random_uuid(),
  family_id        uuid not null references public.families on delete cascade,
  child_id         uuid not null references auth.users on delete cascade,
  child_name       text not null,
  risk_level       text not null check (risk_level in ('safe','low','medium','high','critical')),
  categories       text[] not null default '{}',
  source           text not null,
  platform         text not null,
  detected_at      timestamptz not null,
  summary          text not null,
  excerpt          text,
  counterpart_name text,
  status           text not null default 'unread'
                     check (status in ('unread','reviewed','escalated','dismissed')),
  score            double precision not null default 0,
  matched_signals  text[] not null default '{}',
  latitude         double precision,
  longitude        double precision,
  location_label   text,
  evidence_ids     uuid[] not null default '{}',
  created_at       timestamptz not null default now()
);

create index if not exists alerts_family_detected_idx
  on public.alerts (family_id, detected_at desc);

create table if not exists public.evidence (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families on delete cascade,
  child_id      uuid not null,
  alert_id      uuid,
  kind          text not null,
  captured_at   timestamptz not null,
  recorded_at   timestamptz not null default now(),
  description   text not null,
  payload       text,
  content_hash  text not null,
  chain_hash    text not null,
  previous_hash text,
  sequence      int not null,
  storage_path  text,
  captured_by   text not null default 'AURA',
  consent_note  text,
  
  constraint evidence_sequence_unique unique (family_id, sequence)
);

create index if not exists evidence_family_sequence_idx
  on public.evidence (family_id, sequence desc);


create table if not exists public.guardian_messages (
  id            uuid primary key default gen_random_uuid(),
  child_id      uuid not null references auth.users on delete cascade,
  author        text not null check (author in ('child', 'guardian')),
  text          text not null,
  sent_at       timestamptz not null,
  quick_replies text[] not null default '{}',
  risk_level    text,
  escalated     boolean not null default false
);

create index if not exists guardian_messages_child_idx
  on public.guardian_messages (child_id, sent_at);

-
create table if not exists public.device_tokens (
  user_id    uuid not null references auth.users on delete cascade,
  token      text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);


create or replace function public.my_family_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select family_id from public.profiles where id = auth.uid();
$$;

create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;



revoke update, delete on public.evidence from anon, authenticated;

create or replace function public.block_evidence_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception
    'Bukti bersifat sekali tulis dan tidak dapat diubah atau dihapus (id=%).',
    old.id
    using errcode = 'check_violation';
end;
$$;

drop trigger if exists evidence_is_immutable on public.evidence;
create trigger evidence_is_immutable
  before update or delete on public.evidence
  for each row execute function public.block_evidence_mutation();



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
    -- Orang tua hanya boleh menyalakan/menjeda perlindungan anak dan mengatur
    -- jam istirahatnya. Semua kolom lain (nomor HP, foto, status yang
    -- dilaporkan HP anak, dan kolom yang ditambahkan kelak) harus tetap sama.
    if (to_jsonb(new) - 'protection_active' - 'lock_schedule')
       = (to_jsonb(old) - 'protection_active' - 'lock_schedule')
    then
      return new;
    end if;

    raise exception 'Hanya pemilik profil yang dapat mengubah data ini.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Anak tidak boleh mengubah jam istirahatnya sendiri.
  if old.role = 'child'
     and new.lock_schedule is distinct from old.lock_schedule then
    raise exception 'Jam istirahat hanya bisa diubah orang tua.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_are_guarded on public.profiles;
create trigger profiles_are_guarded
  before update on public.profiles
  for each row execute function public.guard_profile_update();


create or replace function public.guard_alert_update()
returns trigger
language plpgsql
as $$
begin
  if new.risk_level  is distinct from old.risk_level
  or new.categories  is distinct from old.categories
  or new.summary     is distinct from old.summary
  or new.excerpt     is distinct from old.excerpt
  or new.detected_at is distinct from old.detected_at
  or new.child_id    is distinct from old.child_id
  or new.platform    is distinct from old.platform
  or new.score       is distinct from old.score
  then
    raise exception 'Isi peringatan tidak dapat diubah; hanya statusnya.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists alerts_content_is_locked on public.alerts;
create trigger alerts_content_is_locked
  before update on public.alerts
  for each row execute function public.guard_alert_update();


-- Anak yang belum punya keluarga tidak boleh membaca baris keluarga mana pun,
-- karena itu akan membuka kode penautan keluarga lain. Pencocokan kode
-- dikerjakan di dalam basis data, hanya hasilnya yang kembali ke perangkat.
create or replace function public.join_family_with_code(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.families%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Belum masuk.' using errcode = 'insufficient_privilege';
  end if;

  select * into target
    from public.families
   where pairing_code = upper(trim(code));

  if not found then
    raise exception 'Kode penautan tidak ditemukan.'
      using errcode = 'no_data_found';
  end if;

  if target.pairing_expires_at is not null
     and target.pairing_expires_at < now() then
    raise exception 'Kode penautan sudah kedaluwarsa. Minta kode baru.'
      using errcode = 'no_data_found';
  end if;

  update public.profiles
     set family_id = target.id
   where id = auth.uid();

  return target.id;
end;
$$;

revoke all on function public.join_family_with_code(text) from public, anon;
grant execute on function public.join_family_with_code(text) to authenticated;


alter table public.families          enable row level security;
alter table public.profiles          enable row level security;
alter table public.alerts            enable row level security;
alter table public.evidence          enable row level security;
alter table public.guardian_messages enable row level security;
alter table public.device_tokens     enable row level security;


drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (
    id = auth.uid()
    or (family_id is not null and family_id = public.my_family_id())
  );

drop policy if exists profiles_create_own on public.profiles;
create policy profiles_create_own on public.profiles for insert
  with check (id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update
  using (
    id = auth.uid()
    or (public.my_role() = 'parent' and family_id = public.my_family_id())
  );


drop policy if exists families_read on public.families;
create policy families_read on public.families for select
  using (id = public.my_family_id() or owner_id = auth.uid());

drop policy if exists families_create on public.families;
create policy families_create on public.families for insert
  with check (owner_id = auth.uid());

drop policy if exists families_update_own on public.families;
create policy families_update_own on public.families for update
  using (owner_id = auth.uid());


drop policy if exists alerts_read on public.alerts;
create policy alerts_read on public.alerts for select
  using (family_id = public.my_family_id());

drop policy if exists alerts_raise on public.alerts;
create policy alerts_raise on public.alerts for insert
  with check (family_id = public.my_family_id() and status = 'unread');


drop policy if exists alerts_triage on public.alerts;
create policy alerts_triage on public.alerts for update
  using (family_id = public.my_family_id() and public.my_role() = 'parent');


drop policy if exists evidence_read on public.evidence;
create policy evidence_read on public.evidence for select
  using (family_id = public.my_family_id());

drop policy if exists evidence_append on public.evidence;
create policy evidence_append on public.evidence for insert
  with check (family_id = public.my_family_id());

drop policy if exists guardian_messages_own on public.guardian_messages;
create policy guardian_messages_own on public.guardian_messages for select
  using (child_id = auth.uid());

drop policy if exists guardian_messages_write on public.guardian_messages;
create policy guardian_messages_write on public.guardian_messages for insert
  with check (child_id = auth.uid());


drop policy if exists device_tokens_own on public.device_tokens;
create policy device_tokens_own on public.device_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'alerts'
  ) then
    alter publication supabase_realtime add table public.alerts;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'evidence'
  ) then
    alter publication supabase_realtime add table public.evidence;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'guardian_messages'
  ) then
    alter publication supabase_realtime add table public.guardian_messages;
  end if;
end
$$;


-- Foto profil ------------------------------------------------------------

-- Bucket privat, maksimal 2 MB, hanya gambar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Melihat: foto sendiri, atau foto anggota keluarga yang sama.
drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.profiles p
      where p.id::text = (storage.foldername(objects.name))[1]
        and (
          p.id = auth.uid()
          or (p.family_id is not null and p.family_id = public.my_family_id())
        )
    )
  );

-- Mengunggah, mengganti, dan menghapus: hanya di folder sendiri.
drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
