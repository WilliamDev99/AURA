-- =============================================================================
-- Patch 06: jam istirahat
--
-- Orang tua mengatur jam berapa semua aplikasi di HP anak terkunci (mis.
-- 22.00 sampai 09.00) dan pada hari apa saja. HP anak melaporkan apakah izin
-- untuk mengunci aplikasi sudah diberikan, supaya orang tua tidak mengira
-- jam istirahat berjalan padahal belum.
--
-- Jalankan sekali di Supabase SQL Editor. Aman dijalankan ulang.
-- =============================================================================

-- {"enabled": true, "start": "22:00", "end": "09:00", "days": [1,2,3,4,5,6,7]}
-- Hari memakai 1 = Senin ... 7 = Minggu, yaitu hari mulainya kunci.
alter table public.profiles add column if not exists lock_schedule jsonb;

-- Dilaporkan HP anak: izin "Akses penggunaan" dan "Tampil di atas aplikasi
-- lain" sudah diberikan.
alter table public.profiles add column if not exists lock_ready boolean;

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
