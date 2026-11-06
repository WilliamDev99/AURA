import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/change_email_page.dart';
import '../../features/auth/secure_account_page.dart';
import '../../features/auth/sign_in_page.dart';
import '../../features/child/child_consent_page.dart';
import '../../features/child/child_pairing_page.dart';
import '../../features/child/child_shell.dart';
import '../../features/child/guardian_chat_page.dart';
import '../../features/child/report_chat_page.dart';
import '../../features/onboarding/loading_page.dart';
import '../../features/onboarding/welcome_page.dart';
import '../../features/parent/alert_detail_page.dart';
import '../../features/parent/legal_action_page.dart';
import '../../features/parent/pairing_page.dart';
import '../../features/parent/parent_shell.dart';
import '../../features/shared/settings_page.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

abstract final class Routes {
  static const welcome = '/';
  static const loading = '/memuat';
  static const signIn = '/masuk';
  static const child = '/anak';
  static const childChat = '/anak/obrolan';
  static const childReport = '/anak/laporkan';
  static const childConsent = '/anak/persetujuan';
  static const childRelink = '/anak/tautkan';
  static const parent = '/orangtua';
  static const pairing = '/orangtua/tautkan';
  static const secureAccount = '/orangtua/amankan-akun';
  static const changeEmail = '/orangtua/ubah-email';
  static const legal = '/orangtua/langkah-hukum';
  static const settings = '/pengaturan';

  static String alertDetail(String id) => '/orangtua/peringatan/$id';
}

GoRouter createRouter(AppState state) {
  return GoRouter(
    initialLocation: Routes.welcome,
    refreshListenable: state,
    redirect: (context, routerState) {
      final signedIn = state.isSignedIn;
      final location = routerState.matchedLocation;

      // Selama sesi lama dipulihkan, tahan di layar memuat. Kalau tidak,
      // layar pilihan peran sempat muncul dan bisa terketuk anak.
      if (state.isRestoring) {
        return location == Routes.loading ? null : Routes.loading;
      }
      if (location == Routes.loading) {
        if (!signedIn) return Routes.welcome;
        return state.isChild ? Routes.child : Routes.parent;
      }
      final onAuthFlow =
          location == Routes.welcome || location == Routes.signIn;

      if (!signedIn) return onAuthFlow ? null : Routes.welcome;

      if (onAuthFlow) {
        return state.isChild ? Routes.child : Routes.parent;
      }

      // Jangan biarkan perangkat anak membuka layar orang tua, dan sebaliknya.
      if (state.isChild && location.startsWith(Routes.parent)) {
        return Routes.child;
      }
      if (!state.isChild && location.startsWith(Routes.child)) {
        return Routes.parent;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.loading,
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) =>
            SignInPage(asChild: state.uri.queryParameters['peran'] == 'anak'),
      ),
      GoRoute(
        path: Routes.child,
        builder: (context, state) => const ChildShell(),
        routes: [
          GoRoute(
            path: 'obrolan',
            builder: (context, state) => const GuardianChatPage(),
          ),
          GoRoute(
            path: 'laporkan',
            builder: (context, state) => const ReportChatPage(),
          ),
          GoRoute(
            path: 'persetujuan',
            builder: (context, state) => const ChildConsentPage(),
          ),
          GoRoute(
            path: 'tautkan',
            builder: (context, state) => const ChildPairingPage(relink: true),
          ),
        ],
      ),
      GoRoute(
        path: Routes.parent,
        builder: (context, state) => const ParentShell(),
        routes: [
          GoRoute(
            path: 'tautkan',
            builder: (context, state) => const PairingPage(),
          ),
          GoRoute(
            path: 'amankan-akun',
            builder: (context, state) => const SecureAccountPage(),
          ),
          GoRoute(
            path: 'ubah-email',
            builder: (context, state) => const ChangeEmailPage(),
          ),
          GoRoute(
            path: 'langkah-hukum',
            builder: (context, state) => LegalActionPage(
              alertId: state.uri.queryParameters['peringatan'],
            ),
          ),
          GoRoute(
            path: 'peringatan/:id',
            builder: (context, state) =>
                AlertDetailPage(alertId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(tr('Halaman tidak ditemukan: {uri}', {'uri': state.uri})),
      ),
    ),
  );
}
