import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'main_shell.dart';
import 'register_screen.dart';
import 'household_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade     = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide    = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter phone and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final state  = StateProvider.of(context);
    final result = await state.login(phone, pass);
    if (!mounted) return;

    if (result == 'ok') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
    } else if (result == 'no_household') {
      // Auth exists but no household record yet — get userId from Supabase session
      final currentUser = Supabase.instance.client.auth.currentUser;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => HouseholdSetupScreen(
          userId: currentUser?.id ?? '',
          name:   currentUser?.userMetadata?['name'] as String? ?? '',
          phone:  phone,
        ),
      ));
    } else {
      setState(() { _loading = false; _error = state.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: const Text('گھ', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 20),
                const Text('گھرانہ', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Text('Family budget, together.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 40),

                // Form
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Sign In', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Use your registered phone number', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 22),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '03001234567',
                        prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textLight, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Sign In'),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),
                // Register link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Don't have an account?", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Register', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
