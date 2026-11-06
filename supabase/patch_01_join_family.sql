-- =============================================================================
-- Perbaikan: perangkat anak tidak bisa menautkan diri dengan kode keluarga.
--
-- Masalahnya: kebijakan `families_read` hanya mengizinkan membaca keluarga
-- yang sudah menjadi milik pengguna. Anak yang belum punya keluarga karena itu
-- tidak pernah menemukan barisnya, sehingga kode yang benar pun ditolak.
--
-- Melonggarkan kebijakan `select` bukan jawaban: itu akan membuat siapa pun
-- bisa membaca kode penautan seluruh keluarga lain. Karena itu penautan
-- dipindahkan ke fungsi `security definer` di bawah ini, yang memeriksa kode
-- di dalam basis data dan hanya mengembalikan hasil akhirnya.
--
-- Cara memakai: Supabase Dashboard > SQL Editor > New query, tempel, Run.
-- Aman dijalankan ulang.
-- =============================================================================

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
