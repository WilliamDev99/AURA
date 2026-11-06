-- =============================================================================
-- Patch 04: foto profil, dan penjagaan profil yang lebih ketat
--
-- 1. Kolom avatar_path: letak foto profil di Storage.
-- 2. Bucket "avatars" yang PRIVAT: foto hanya bisa dilihat anggota keluarga
--    sendiri, lewat tautan sementara. Setiap pengguna hanya bisa mengunggah
--    atau menghapus foto di foldernya sendiri ({id pengguna}/...).
-- 3. Penjagaan profil: orang lain (orang tua) hanya boleh mengubah
--    protection_active milik anak. Sebelumnya, kolom yang tidak ada di
--    daftar pemeriksaan (mis. phone) ikut bisa diubah bersamaan; sekarang
--    seluruh kolom lain dibandingkan sekaligus.
--
-- Jalankan sekali di Supabase SQL Editor. Aman dijalankan ulang.
-- =============================================================================

alter table public.profiles add column if not exists avatar_path text;

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
    -- Orang tua hanya boleh menyalakan/menjeda perlindungan anak. Semua
    -- kolom lain harus tetap sama, termasuk kolom yang ditambahkan kelak.
    if (to_jsonb(new) - 'protection_active')
       = (to_jsonb(old) - 'protection_active')
    then
      return new;
    end if;

    raise exception 'Hanya pemilik profil yang dapat mengubah data ini.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

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
