// Dibuat oleh tool/firebase_options_from_json.py dari
// android/app/google-services.json. Jalankan ulang skrip itu bila berkasnya
// diganti; jangan disunting langsung.
//
// Firebase di AURA hanya dipakai untuk notifikasi push Android (FCM). Basis
// data tetap Supabase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError('Notifikasi AURA baru disiapkan untuk Android.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQGbD-EcfEvvdz83NjD7xHt8EvbQ1fBvc',
    appId: '1:571673272095:android:61a8587976022601a71a2a',
    messagingSenderId: '571673272095',
    projectId: 'aura-933ef',
    storageBucket: 'aura-933ef.firebasestorage.app',
  );
}
