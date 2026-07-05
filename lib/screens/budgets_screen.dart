import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state       = StateProvider.of(context);
    final budgets     = state.budgets;
    final totalLimit  = budgets.fold(0.0, (s, b) => s + b.limit);
    final totalSpent  = budgets.fold(0.0, (s, b) => s + state.spentForBudget(b));
    final overallPct  = totalLimit > 0 ? totalSpent / totalLimit : 0.0;
    final isAdmin     = state.currentUser?.role == MemberRole.admin || state.currentUser?.role == MemberRole.manager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Budget',
              onPressed: () => _showBudgetForm(context, state, null),
            ),
        ],
      ),
      body: budgets.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const EmptyState(message: 'No budgets set.\nTap + to add your first budget.', icon: Icons.pie_chart_outline),
              const SizedBox(height: 16),
              if (isAdmin) ElevatedButton.icon(
                onPressed: () => _showBudgetForm(context, state, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Budget'),
              ),
            ]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [

                // ── Overall summary ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2040), Color(0xFF1A3A6B)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Monthly Budget', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      _CircleProgress(percent: overallPct),
                    ]),
                    const SizedBox(height: 8),
                    Text(state.formatAmount(totalSpent),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                    Text('of ${state.formatAmount(totalLimit)} budgeted',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: overallPct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallPct >= 1.0 ? AppColors.error : overallPct >= 0.8 ? AppColors.warning : const Color(0xFF8FB896)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalSpent > totalLimit
                          ? 'Over budget by ${state.formatAmount(totalSpent - totalLimit)}'
                          : '${state.formatAmount(totalLimit - totalSpent)} remaining this month',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ]),
                ),

                // ── Near-limit alert ──
                Builder(builder: (ctx) {
                  final near = budgets.where((b) => state.spentForBudget(b) / b.limit >= 0.8 && state.spentForBudget(b) < b.limit).toList();
                  if (near.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.notifications_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          '${near.length} budget${near.length > 1 ? 's' : ''} near limit: ${near.map((b) => b.category).join(', ')}',
                          style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                        )),
                      ]),
                    ),
                  );
                }),

                // ── Overspend banner ──
                Builder(builder: (ctx) {
                  final over = budgets.where((b) => state.spentForBudget(b) >= b.limit).toList();
                  if (over.isEmpty) return const SizedBox.shrink();
                  final totalOver = over.fold(0.0, (s, b) => s + (state.spentForBudget(b) - b.limit));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.30)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.error_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '${over.length} budget${over.length > 1 ? 's' : ''} exceeded!',
                            style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w700),
                          )),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '−${state.formatAmount(totalOver)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ...over.map((b) {
                          final excess = state.spentForBudget(b) - b.limit;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(children: [
                              const SizedBox(width: 28),
                              CategoryIconWidget(category: b.category, size: 20),
                              const SizedBox(width: 6),
                              Expanded(child: Text(b.category,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                              Text('over by ${state.formatAmount(excess)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                            ]),
                          );
                        }),
                      ]),
                    ),
                  );
                }),

                const SectionHeader(title: 'Category Budgets'),
                ...budgets.map((b) => _BudgetCard(
                  budget: b, state: state,
                  canEdit: isAdmin,
                  onEdit:   () => _showBudgetForm(context, state, b),
                  onDelete: () => _confirmDelete(context, state, b),
                )),
              ],
            ),
    );
  }

  void _showBudgetForm(BuildContext context, AppState state, AppBudget? existing) {
    final catCtrl   = existing != null ? null : null;
    String selectedCat = existing?.category ?? 'Ration';
    final limitCtrl = TextEditingController(text: existing?.limit.toStringAsFixed(0) ?? '');
    final isEdit    = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Edit Budget' : 'Add Budget',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          if (!isEdit) ...[
            const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ...state.allCategories
                .where((c) => c != 'Salary' && c != 'Freelance')
                .map((cat) {
                final active = selectedCat == cat;
                final c = CatHelper.color(cat);
                return GestureDetector(
                  onTap: () => setLocal(() => selectedCat = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? c.withOpacity(0.12) : AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? c : AppColors.divider),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(CatHelper.icon(cat), size: 12, color: active ? c : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: active ? c : AppColors.textSecondary)),
                    ]),
                  ),
                );
              }),
              GestureDetector(
                onTap: () async {
                  final added = await showAddCategoryDialog(ctx, state);
                  if (added != null) setLocal(() => selectedCat = added);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: limitCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Monthly Limit (Rs)',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final limitStr = limitCtrl.text.trim();
                if (limitStr.isEmpty || double.tryParse(limitStr) == null) return;
                final limit = double.parse(limitStr);
                if (limit <= 0) return;
                if (isEdit) {
                  state.updateBudget(existing!.copyWith(limit: limit));
                } else {
                  state.addBudget(AppBudget(
                    id: 'b${DateTime.now().millisecondsSinceEpoch}',
                    category: selectedCat, limit: limit,
                  ));
                }
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Budget'),
            ),
          ),
        ]),
      )),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, AppBudget b) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Budget', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete budget for "${b.category}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { state.deleteBudget(b.id); Navigator.pop(context); },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final AppBudget budget; final AppState state;
  final bool canEdit; final VoidCallback onEdit; final VoidCallback onDelete;
  const _BudgetCard({required this.budget, required this.state, required this.canEdit,
      required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final spent = state.spentForBudget(budget);
    final pct   = budget.limit > 0 ? spent / budget.limit : 0.0;
    final color = pct >= 1.0 ? AppColors.error : pct >= 0.8 ? AppColors.warning : AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pct >= 0.8 ? color.withOpacity(0.25) : AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CategoryIconWidget(category: budget.category, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(budget.category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            Text('${state.formatAmount(spent)} / ${state.formatAmount(budget.limit)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          if (pct >= 1.0)
            _Badge(label: 'Over!', color: AppColors.error)
          else if (pct >= 0.8)
            _Badge(label: '${(pct*100).toStringAsFixed(0)}%', color: AppColors.warning),
          if (canEdit) PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textLight),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',
                  child: Row(children: [Icon(Icons.edit_rounded, size: 15, color: AppColors.textSecondary), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete',
                  child: Row(children: [Icon(Icons.delete_rounded, size: 15, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pct >= 1.0
              ? 'Over by ${state.formatAmount(spent - budget.limit)}'
              : '${state.formatAmount(budget.limit - spent)} remaining',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _CircleProgress extends StatelessWidget {
  final double percent;
  const _CircleProgress({required this.percent});
  @override
  Widget build(BuildContext context) => SizedBox(width: 52, height: 52,
    child: Stack(alignment: Alignment.center, children: [
      CircularProgressIndicator(
        value: percent.clamp(0.0, 1.0), strokeWidth: 5,
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation<Color>(
          percent >= 1.0 ? AppColors.error : percent >= 0.8 ? AppColors.warning : const Color(0xFF8FB896)),
      ),
      Text('${(percent * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}
