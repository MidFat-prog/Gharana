import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import '../services/sms_parser.dart';
import '../services/sms_service.dart';

class SmsTransactionsScreen extends StatefulWidget {
  const SmsTransactionsScreen({super.key});

  @override
  State<SmsTransactionsScreen> createState() => _SmsTransactionsScreenState();
}

class _SmsTransactionsScreenState extends State<SmsTransactionsScreen> {
  final SmsService _smsService = SmsService();

  List<ParsedSms> _pending   = [];
  bool _loading              = true;
  bool _hasPermission        = false;
  final Set<String> _accepting = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _smsService.stopListening();
    super.dispose();
  }

  Future<void> _init() async {
    _hasPermission = await _smsService.hasPermission();
    if (!_hasPermission) {
      setState(() => _loading = false);
      return;
    }
    await _scan();
    _startLivePolling();
  }

  /// Full rescan — reads entire inbox, no date cap
  Future<void> _scan() async {
    setState(() => _loading = true);
    final results = await _smsService.scanInbox();
    if (mounted) setState(() { _pending = results; _loading = false; });
  }

  /// Live polling — inserts brand-new SMS at the top of the list immediately
  void _startLivePolling() {
    _smsService.onNewTransactions = (newItems) {
      if (!mounted) return;
      setState(() {
        // Prepend new items, dedup by smsId
        final existingIds = _pending.map((s) => s.smsId).toSet();
        final fresh = newItems.where((s) => !existingIds.contains(s.smsId)).toList();
        if (fresh.isNotEmpty) _pending.insertAll(0, fresh);
      });
    };
    _smsService.startListening();
  }

  Future<void> _requestPermission() async {
    final granted = await _smsService.requestPermission();
    if (granted) {
      setState(() => _hasPermission = true);
      await _scan();
      _startLivePolling();
    }
  }

  // ── Accept ────────────────────────────────────────────────────────────────
  Future<void> _accept(ParsedSms sms) async {
    setState(() => _accepting.add(sms.smsId));
    final state    = StateProvider.of(context);
    final memberId = state.currentUser?.id ?? '';

    try {
      await state.addTransaction(AppTransaction(
        id:       sms.smsId,
        amount:   sms.amount,
        category: sms.category,
        memberId: memberId,
        date:     sms.date,
        isIncome: sms.isIncome,
        note:     sms.note,
      ));

      // Mark as processed so it never resurfaces on rescan
      await _smsService.markProcessed([sms.smsId]);

      if (mounted) {
        setState(() {
          _accepting.remove(sms.smsId);
          _pending.removeWhere((s) => s.smsId == sms.smsId);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('${state.formatAmount(sms.amount)} saved'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _accepting.remove(sms.smsId));
    }
  }

  // ── Discard ───────────────────────────────────────────────────────────────
  Future<void> _discard(ParsedSms sms) async {
    await _smsService.markProcessed([sms.smsId]);
    if (mounted) setState(() => _pending.removeWhere((s) => s.smsId == sms.smsId));
  }

  // ── Edit & Accept ─────────────────────────────────────────────────────────
  Future<void> _editAndAccept(ParsedSms sms) async {
    String selectedCategory = sms.category;
    final state = StateProvider.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Edit Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              sms.rawBody.length > 80 ? '${sms.rawBody.substring(0, 80)}…' : sms.rawBody,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
            const SizedBox(height: 20),

            // Amount
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sms.isIncome ? AppColors.success.withOpacity(0.08) : AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(
                  sms.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: sms.isIncome ? AppColors.success : AppColors.error, size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Rs ${sms.amount.toStringAsFixed(0)} · ${sms.isIncome ? "Income" : "Expense"}',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: sms.isIncome ? AppColors.success : AppColors.error,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Category selector
            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ...state.allCategories.map((cat) {
                  final active = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(cat, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.textSecondary,
                      )),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () async {
                    final added = await showAddCategoryDialog(ctx, state);
                    if (added != null) setSheet(() => selectedCategory = added);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              )),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed == true) {
      final edited = ParsedSms(
        amount:   sms.amount,
        isIncome: sms.isIncome,
        category: selectedCategory,
        source:   sms.source,
        rawBody:  sms.rawBody,
        date:     sms.date,
        smsId:    sms.smsId,
      );
      await _accept(edited);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SMS Transactions'),
        actions: [
          if (!_loading && _hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rescan all SMS',
              onPressed: _scan,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _buildPermissionPrompt()
              : _pending.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildPermissionPrompt() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 48),
        ),
        const SizedBox(height: 20),
        const Text('SMS Permission Required',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          'Gharana needs access to read your SMS to automatically detect bank and wallet transactions.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your messages are processed on-device only and never sent anywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _requestPermission,
            icon: const Icon(Icons.security_rounded, size: 18),
            label: const Text('Allow SMS Access'),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.mark_email_read_rounded, size: 64, color: AppColors.textLight),
      const SizedBox(height: 16),
      const Text('No new transactions found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text(
        'All bank & wallet SMS have already been\nprocessed or none were detected.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: _scan,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Scan Again'),
      ),
    ]),
  );

  Widget _buildList() => Column(children: [
    // Header banner
    Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.sms_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          '${_pending.length} transaction${_pending.length == 1 ? '' : 's'} detected from all SMS. '
          'New messages appear automatically.',
          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
        )),
      ]),
    ),

    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _pending.length,
        itemBuilder: (_, i) => _buildCard(_pending[i]),
      ),
    ),
  ]);

  Widget _buildCard(ParsedSms sms) {
    final isAccepting = _accepting.contains(sms.smsId);
    final isIncome    = sms.isIncome;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isIncome ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isIncome ? AppColors.success : AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Rs ${sms.amount.toStringAsFixed(sms.amount % 1 == 0 ? 0 : 2)}',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isIncome ? AppColors.success : AppColors.error,
                ),
              ),
              Text(sms.source, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Text(_formatDate(sms.date), style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(sms.category, style: const TextStyle(
                fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              sms.rawBody.length > 50 ? '${sms.rawBody.substring(0, 50)}…' : sms.rawBody,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),

        const Divider(height: 1, color: AppColors.divider),

        Row(children: [
          // Edit & Accept
          Expanded(
            child: InkWell(
              onTap: isAccepting ? null : () => _editAndAccept(sms),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: isAccepting
                    ? const Center(child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('Edit & Accept', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ]),
              ),
            ),
          ),

          Container(width: 1, height: 44, color: AppColors.divider),
          Expanded(
            child: InkWell(
              onTap: isAccepting ? null : () => _accept(sms),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Accept', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                ]),
              ),
            ),
          ),

          Container(width: 1, height: 44, color: AppColors.divider),
          Expanded(
            child: InkWell(
              onTap: () => _discard(sms),
              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cancel_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 6),
                  Text('Discard', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final now  = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    == 1) return 'Yesterday';
    if (diff.inDays    < 30) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
