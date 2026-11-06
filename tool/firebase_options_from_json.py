"""Membuat lib/firebase_options.dart dari android/app/google-services.json.

Pengganti `flutterfire configure` untuk AURA, yang hanya memakai Firebase
untuk notifikasi Android: tidak perlu Firebase CLI maupun login di terminal.

    python -I tool/firebase_options_from_json.py

Isi google-services.json bukan rahasia (kuncinya dibatasi ke aplikasi ini),
tetapi berkas service account *adalah* rahasia dan tidak pernah dibaca di sini.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'android' / 'app' / 'google-services.json'
TARGET = ROOT / 'lib' / 'firebase_options.dart'
PACKAGE = 'id.aura.aura'


def main() -> int:
    if not SOURCE.exists():
        print(f'Tidak ditemukan: {SOURCE}')
        print('Unduh dari Firebase Console > Project settings > Aplikasi Android.')
        return 1

    data = json.loads(SOURCE.read_text(encoding='utf-8'))
    project = data['project_info']
    client = next(
        (
            c
            for c in data['client']
            if c['client_info']['android_client_info']['package_name'] == PACKAGE
        ),
        None,
    )
    if client is None:
        names = [
            c['client_info']['android_client_info']['package_name']
            for c in data['client']
        ]
        print(f'Aplikasi Android "{PACKAGE}" tidak ada di berkas ini: {names}')
        print('Saat menambah aplikasi di Firebase, isi package name: id.aura.aura')
        return 1

    values = {
        'apiKey': client['api_key'][0]['current_key'],
        'appId': client['client_info']['mobilesdk_app_id'],
        'messagingSenderId': project['project_number'],
        'projectId': project['project_id'],
        'storageBucket': project.get('storage_bucket', ''),
    }
    fields = '\n'.join(f"    {k}: '{v}'," for k, v in values.items() if v)

    TARGET.write_text(
        f"""// Dibuat oleh tool/firebase_options_from_json.py dari
// android/app/google-services.json. Jalankan ulang skrip itu bila berkasnya
// diganti; jangan disunting langsung.
//
// Firebase di AURA hanya dipakai untuk notifikasi push Android (FCM). Basis
// data tetap Supabase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform {{
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {{
      return android;
    }}
    throw UnsupportedError(
      'Notifikasi AURA baru disiapkan untuk Android.',
    );
  }}

  static const FirebaseOptions android = FirebaseOptions(
{fields}
  );
}}
""",
        encoding='utf-8',
    )
    print(f'Selesai: {TARGET.relative_to(ROOT)} (project {values["projectId"]})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
