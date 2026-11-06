-- =============================================================================
-- Patch 03: status pemindaian chat di ponsel anak
--
-- Ponsel anak melaporkan apakah "Akses notifikasi" untuk AURA menyala, supaya
-- orang tua tahu bila pemindaian chat sedang mati dan tidak mengira chat
-- anaknya terpantau. Jalankan sekali di Supabase SQL Editor.
-- =============================================================================

alter table public.profiles add column if not exists chat_scan_enabled boolean;
alter table public.profiles add column if not exists chat_scan_checked_at timestamptz;

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
    -- Orang tua hanya boleh menyalakan/menjeda perlindungan anak. Status
    -- pemindaian chat hanya dilaporkan ponsel anak sendiri, supaya tidak
    -- bisa dipalsukan.
    if new.protection_active is distinct from old.protection_active
       and new.name is not distinct from old.name
       and new.family_id is not distinct from old.family_id
       and new.age is not distinct from old.age
       and new.device_label is not distinct from old.device_label
       and new.monitoring_consent_at is not distinct from old.monitoring_consent_at
       and new.chat_scan_enabled is not distinct from old.chat_scan_enabled
       and new.chat_scan_checked_at is not distinct from old.chat_scan_checked_at
    then
      return new;
    end if;

    raise exception 'Hanya pemilik profil yang dapat mengubah data ini.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;
