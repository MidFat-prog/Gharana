import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool   _isExpense  = true;
  String _category   = 'Ration';
  String _memberId   = '';
  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  DateTime _date     = DateTime.now();
  String? _amountError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = StateProvider.of(context);
      if (state.currentUser != null) setState(() => _memberId = state.currentUser!.id);
    });
  }

  @override
  void dispose() { _amountCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  void _submit() {
    final amtStr = _amountCtrl.text.trim();
    if (amtStr.isEmpty || double.tryParse(amtStr) == null) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    final amt = double.parse(amtStr);
    if (amt <= 0) { setState(() => _amountError = 'Amount must be greater than 0'); return; }
    if (_memberId.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a member'), backgroundColor: AppColors.error)); return; }

    final state = StateProvider.of(context);
    state.addTransaction(AppTransaction(
      id:       'tx${DateTime.now().millisecondsSinceEpoch}',
      amount:   amt,
      category: _isExpense ? _category : 'Salary',
      memberId: _memberId,
      date:     _date,
      isIncome: !_isExpense,
      note:     _noteCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state   = StateProvider.of(context);
    final members = state.members;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Type toggle ──
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _TypeBtn(label: 'Expense', icon: Icons.arrow_upward_rounded,
                  active: _isExpense,  color: AppColors.expense,
                  onTap: () => setState(() { _isExpense = true;  _category = 'Ration'; })),
              _TypeBtn(label: 'Income',  icon: Icons.arrow_downward_rounded,
                  active: !_isExpense, color: AppColors.income,
                  onTap: () => setState(() { _isExpense = false; _category = 'Salary'; })),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Amount ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _amountError != null ? AppColors.error : AppColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Amount', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('Rs ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                    color: _isExpense ? AppColors.expense : AppColors.income)),
                Expanded(child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _amountError = null),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                      color: _isExpense ? AppColors.expense : AppColors.income, fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: const TextStyle(fontSize: 34, color: AppColors.textLight, fontFamily: 'Poppins'),
                    border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none, filled: false,
                    isDense: true, contentPadding: EdgeInsets.zero,
                    errorText: _amountError,
                  ),
                )),
              ]),
              const SizedBox(height: 10),
              // Quick amounts
              Wrap(spacing: 8, children: ['500', '1000', '2000', '5000', '10000'].map((v) =>
                GestureDetector(
                  onTap: () => setState(() { _amountCtrl.text = v; _amountError = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Rs $v', style: const TextStyle(
                        fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ).toList()),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Category ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Category', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...state.allCategories
                  .where((c) => _isExpense ? c != 'Salary' && c != 'Freelance' : c == 'Salary' || c == 'Freelance' || c == 'Other')
                  .map((cat) {
                    final active = _category == cat;
                    final c = CatHelper.color(cat);
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? c.withOpacity(0.12) : AppColors.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? c : AppColors.divider),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(CatHelper.icon(cat), size: 13, color: active ? c : AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: active ? c : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }),
                if (_isExpense)
                  GestureDetector(
                    onTap: () async {
                      final added = await showAddCategoryDialog(context, state);
                      if (added != null && mounted) setState(() => _category = added);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ]),
                    ),
                  ),
              ]),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Member ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Member', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: members.map((m) {
                final active = _memberId == m.id;
                return Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _memberId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? m.color.withOpacity(0.1) : AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active ? m.color : AppColors.divider),
                      ),
                      child: Column(children: [
                        AvatarWidget(initials: m.initials, color: m.color, size: 34),
                        const SizedBox(height: 5),
                        Text(m.name.split(' ')[0], style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: active ? m.color : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                ));
              }).toList()),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Note ──
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Monthly grocery from Al-Fatah',
              prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
            ),
          ),

          const SizedBox(height: 14),

          // ── Date ──
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 12),
                Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const Spacer(),
                const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isExpense ? 'Add Expense' : 'Add Income',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final Color color; final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: active ? color : AppColors.textLight, size: 17),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(
          color: active ? color : AppColors.textLight,
          fontWeight: FontWeight.w700, fontSize: 14,
        )),
      ]),
    ),
  ));
}
