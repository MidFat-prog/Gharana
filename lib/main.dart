import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/household_setup_screen.dart';
import 'services/sms_service.dart';
import 'services/notification_service.dart';

// ─── YOUR SUPABASE CREDENTIALS ───────────────────────────────────────────────
// Replace these two values with your actual Supabase project URL and anon key.
// Find them in: Supabase Dashboard → Project Settings → API
const _supabaseUrl    = 'https://kbavayzcwamqfshkedvy.supabase.co';
const _supabaseAnonKey = 'sb_publishable_OYc5sY-oJTbS_OXDAOB__Q_RsTLoWOz';
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:     _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  // Record first-ever open time — used as the SMS scan floor.
  // This runs on every cold start but only writes once (first time).
  await SmsService.initInstallTime();
  await NotificationService.init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:        Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const GharanaApp());
}

class GharanaApp extends StatelessWidget {
  const GharanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    return StateProvider(
      state: state,
      child: MaterialApp(
        title: 'Gharana',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: _SplashRouter(appState: state),
      ),
    );
  }
}

/// Checks for an existing Supabase session on startup and routes accordingly.
class _SplashRouter extends StatefulWidget {
  final AppState appState;
  const _SplashRouter({required this.appState});
  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame to finish before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        _go(const LoginScreen());
        return;
      }

      // Session exists → check if member record exists
      final rows = await Supabase.instance.client
          .from('members')
          .select()
          .eq('id', user.id)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (rows.isEmpty) {
        final meta = user.userMetadata ?? {};
        _go(HouseholdSetupScreen(
          userId: user.id,
          name:   meta['name']  as String? ?? '',
          phone:  meta['phone'] as String? ?? '',
        ));
      } else {
        await widget.appState.restoreSession(user.id);
        if (!mounted) return;
        _go(const MainShell());
      }
    } catch (e) {
      // Any error (network, DB, timeout) → just go to login
      if (mounted) _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
