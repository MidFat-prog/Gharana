import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _type       = 'All';
  String _sortBy     = 'date';
  String _searchQuery = '';
  String _catFilter  = '';
  String _memberFilter = '';
  bool   _showSearch = false;
  final _searchCtrl  = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = StateProvider.of(context);
    final txns = state.filteredTransactions(
      type:           _type == 'All' ? null : _type.toLowerCase(),
      sortBy:         _sortBy,
      searchQuery:    _searchQuery,
      categoryFilter: _catFilter,
      memberFilter:   _memberFilter,
    );

    // group by date label
    final groups = <String, List<AppTransaction>>{};
    for (final tx in txns) {
      final label = _dateLabel(tx.date);
      groups.putIfAbsent(label, () => []).add(tx);
    }

    final totalIncome  = txns.where((t) => t.isIncome).fold(0.0,  (s, t) => s + t.amount);
    final totalExpense = txns.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search category, note, member...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) { _searchQuery = ''; _searchCtrl.clear(); }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.filter_list_rounded),
              if (_catFilter.isNotEmpty || _memberFilter.isNotEmpty)
                Positioned(right: -2, top: -2,
                  child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))),
            ]),
            onPressed: () => _showFilterSheet(context, state),
          ),
        ],
      ),
      body: Column(children: [
        // ── Type pills ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: ['All', 'Income', 'Expense'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PillChip(label: t, active: _type == t, onTap: () => setState(() => _type = t)),
          )).toList()),
        ),

        // ── Summary row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [
            Expanded(child: _SummaryBox(
              icon: Icons.arrow_downward_rounded,
              label: 'Income',
              value: state.formatAmount(totalIncome),
              color: AppColors.income,
            )),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(
              icon: Icons.arrow_upward_rounded,
              label: 'Expense',
              value: state.formatAmount(totalExpense),
              color: AppColors.expense,
            )),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(
              icon: Icons.receipt_long_rounded,
              label: 'Count',
              value: '${txns.length}',
              color: AppColors.accent,
            )),
          ]),
        ),

        // ── Active filters display ──
        if (_catFilter.isNotEmpty || _memberFilter.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              const Text('Filters: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (_catFilter.isNotEmpty)
                _FilterChip(label: _catFilter, onRemove: () => setState(() => _catFilter = '')),
              if (_memberFilter.isNotEmpty)
                _FilterChip(
                  label: state.memberById(_memberFilter)?.name.split(' ')[0] ?? _memberFilter,
                  onRemove: () => setState(() => _memberFilter = ''),
                ),
            ]),
          ),

        // ── List ──
        Expanded(
          child: txns.isEmpty
              ? const EmptyState(message: 'No transactions found.', icon: Icons.receipt_long_rounded)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: groups.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: entry.value.map((tx) => TransactionTile(
                            tx: tx, state: state,
                            onDelete: () {
                              state.deleteTransaction(tx.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Transaction deleted'),
                                  backgroundColor: AppColors.textPrimary,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: AppColors.accentLight,
                                    onPressed: () {}, // would restore in real app
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                          )).toList(),
                        ),
                      ),
                    ],
                  )).toList(),
                ),
        ),
      ]),
    );
  }

  String _dateLabel(DateTime d) {
    final now  = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 24 && now.day == d.day) return 'Today';
    if (diff.inDays == 1 || (diff.inHours < 48 && now.day != d.day)) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SortOption(label: 'Date (newest first)', icon: Icons.calendar_today_rounded,
              active: _sortBy == 'date',
              onTap: () { setState(() => _sortBy = 'date'); Navigator.pop(context); }),
          _SortOption(label: 'Amount (highest first)', icon: Icons.attach_money_rounded,
              active: _sortBy == 'amount',
              onTap: () { setState(() => _sortBy = 'amount'); Navigator.pop(context); }),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () { setState(() { _catFilter = ''; _memberFilter = ''; }); Navigator.pop(context); },
                child: const Text('Clear All', style: TextStyle(color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: state.allCategories.map((cat) {
              final active = _catFilter == cat;
              return GestureDetector(
                onTap: () { setLocal(() {}); setState(() => _catFilter = active ? '' : cat); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? CatHelper.color(cat).withOpacity(0.15) : AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? CatHelper.color(cat) : AppColors.divider),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CatHelper.icon(cat), size: 13, color: active ? CatHelper.color(cat) : AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? CatHelper.color(cat) : AppColors.textSecondary)),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            const Text('Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: state.members.map((m) {
              final active = _memberFilter == m.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setLocal(() {}); setState(() => _memberFilter = active ? '' : m.id); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? m.color.withOpacity(0.12) : AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? m.color : AppColors.divider),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AvatarWidget(initials: m.initials, color: m.color, size: 20),
                      const SizedBox(width: 6),
                      Text(m.name.split(' ')[0], style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? m.color : AppColors.textSecondary)),
                    ]),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply'),
              ),
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _SummaryBox({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _SortOption extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _SortOption({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: active ? AppColors.primary : AppColors.textSecondary),
    title: Text(label, style: TextStyle(
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? AppColors.primary : AppColors.textPrimary)),
    trailing: active ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
    onTap: onTap,
  );
}

class _FilterChip extends StatelessWidget {
  final String label; final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary)),
    ]),
  );
}

// expose for widgets.dart
const accentLight = Color(0xFF8FB896);
