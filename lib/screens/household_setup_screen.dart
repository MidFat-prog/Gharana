import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'main_shell.dart';

class HouseholdSetupScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String phone;

  const HouseholdSetupScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.phone,
  });

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  // 0 = choose, 1 = create, 2 = join
  int _step = 0;

  // Create form
  final _houseNameCtrl = TextEditingController();
  final _cityCtrl      = TextEditingController();

  // Join form
  final _codeCtrl      = TextEditingController();
  MemberRole _joinRole = MemberRole.spender;

  bool _loading = false;
  String? _error;

  // userId is always passed in from register screen or splash router
  String get _userId => widget.userId;

  String get _name  => widget.name.isNotEmpty  ? widget.name  : '';
  String get _phone => widget.phone.isNotEmpty ? widget.phone : '';

  @override
  void dispose() {
    _houseNameCtrl.dispose(); _cityCtrl.dispose(); _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (_houseNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a household name.'); return;
    }
    setState(() { _loading = true; _error = null; });
    final state = StateProvider.of(context);
    final ok    = await state.createHousehold(
      _userId, _name, _phone,
      _houseNameCtrl.text.trim(),
      _cityCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
    } else {
      setState(() { _loading = false; _error = state.error; });
    }
  }

  Future<void> _joinHousehold() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-character invite code.'); return;
    }
    setState(() { _loading = true; _error = null; });
    final state = StateProvider.of(context);
    final ok    = await state.joinHousehold(
      _userId, _name, _phone,
      _codeCtrl.text.trim(),
      _joinRole,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
    } else {
      setState(() { _loading = false; _error = state.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _step == 0 ? null : AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() { _step = 0; _error = null; }),
        ),
        title: Text(_step == 1 ? 'Create Household' : 'Join Household'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildChoose() : _step == 1 ? _buildCreate() : _buildJoin(),
        ),
      ),
    );
  }

  // ── Step 0: Choose create or join ─────────────────────────────────────────
  Widget _buildChoose() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: const Text('گھ', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 20),
      const Text('One More Step!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      const Text('Do you want to create a new household or join an existing one?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 36),

      // Create card
      GestureDetector(
        onTap: () => setState(() => _step = 1),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.home_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Create Household', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              Text('Start fresh. You will be the Admin and can invite others.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ]),
        ),
      ),

      const SizedBox(height: 14),

      // Join card
      GestureDetector(
        onTap: () => setState(() => _step = 2),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.group_add_rounded, color: AppColors.accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Join Household', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              Text('Enter the invite code your Admin shared with you.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ]),
        ),
      ),
    ]);
  }

  // ── Step 1: Create household ───────────────────────────────────────────────
  Widget _buildCreate() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      const Text('You will be the Admin of this household and can share an invite code with family members.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 24),

      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _houseNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Household Name',
              hintText: 'e.g. Hussain Family',
              prefixIcon: Icon(Icons.home_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City (optional)',
              hintText: 'e.g. Lahore',
              prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _createHousehold,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create & Continue'),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Step 2: Join household ─────────────────────────────────────────────────
  Widget _buildJoin() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      const Text('Ask your household Admin for the 6-character invite code.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 24),

      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                letterSpacing: 6, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Invite Code',
              hintText: 'ABC123',
              hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: 6, color: AppColors.textLight),
              prefixIcon: Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),

          // Role selector
          const Text('Your Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...[ MemberRole.manager, MemberRole.spender ].map((role) {
            final label = role == MemberRole.manager ? 'Manager' : 'Spender';
            final desc  = role == MemberRole.manager
                ? 'Can log expenses, view all budgets, set limits'
                : 'Can log own expenses, see household summary';
            final icon  = role == MemberRole.manager ? Icons.manage_accounts_rounded : Icons.person_rounded;
            final active = _joinRole == role;
            return GestureDetector(
              onTap: () => setState(() => _joinRole = role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withOpacity(0.07) : AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? AppColors.primary : AppColors.divider),
                ),
                child: Row(children: [
                  Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    )),
                    Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  if (active) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                ]),
              ),
            );
          }),

          if (_error != null) ...[
            const SizedBox(height: 4),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _joinHousehold,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Join Household'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
    ]),
  );
}
