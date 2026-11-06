-- =============================================================================
-- Patch 05: perbaikan aturan baca foto profil
--
-- Di patch 04, aturan avatars_read memakai `name` di dalam subquery ke tabel
-- profiles. Tabel itu juga punya kolom `name` (nama orang), sehingga
-- PostgreSQL membandingkan folder foto dengan nama orang, bukan nama file.
-- Akibatnya semua foto ditolak, termasuk saat diunggah. Di sini kolomnya
-- ditulis lengkap: objects.name.
--
-- Jalankan sekali di Supabase SQL Editor. Aman dijalankan ulang.
-- =============================================================================

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
