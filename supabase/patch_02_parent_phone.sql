-- =============================================================================
-- Nomor HP orang tua untuk telepon otomatis saat anak menekan tombol darurat.
--
-- Tidak perlu kebijakan RLS baru:
--   - profiles_read sudah mengizinkan anggota keluarga saling membaca profil,
--     jadi perangkat anak bisa mengambil nomor orang tuanya;
--   - guard_profile_update sudah mengizinkan pemilik mengubah barisnya sendiri,
--     dan menolak orang lain mengubah selain status perlindungan.
--
-- Cara memakai: Supabase Dashboard > SQL Editor > New query, tempel, Run.
-- Aman dijalankan ulang.
-- =============================================================================

alter table public.profiles add column if not exists phone text;

alter table public.profiles drop constraint if exists profiles_phone_format;
alter table public.profiles add constraint profiles_phone_format
  check (phone is null or phone ~ '^\+628[0-9]{8,12}$');
