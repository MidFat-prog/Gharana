import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../utils/category_helper.dart';
export '../utils/category_helper.dart';

// ─── Avatar ───────────────────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final String initials;
  final double size;
  final Color color;
  const AvatarWidget({super.key, required this.initials, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
    alignment: Alignment.center,
    child: Text(initials, style: TextStyle(
      color: color, fontWeight: FontWeight.w800,
      fontSize: size * 0.35, fontFamily: 'Poppins',
    )),
  );
}

// ─── Add Category Dialog ────────────────────────────────────────────────────
// Reusable picker for creating a custom category (name + icon + color).
// Returns the new category name on success, or null if cancelled.
Future<String?> showAddCategoryDialog(BuildContext context, AppState state) async {
  final nameCtrl = TextEditingController();
  int iconIdx  = 0;
  int colorIdx = 0;
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('New Category', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category name',
              errorText: error,
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(CatHelper.iconChoices.length, (i) {
            final active = i == iconIdx;
            return GestureDetector(
              onTap: () => setLocal(() => iconIdx = i),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: active ? CatHelper.colorChoices[colorIdx].withOpacity(0.15) : AppColors.surfaceWarm,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? CatHelper.colorChoices[colorIdx] : AppColors.divider,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Icon(CatHelper.iconChoices[i], size: 18,
                    color: active ? CatHelper.colorChoices[colorIdx] : AppColors.textSecondary),
              ),
            );
          })),
          const SizedBox(height: 18),
          const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(CatHelper.colorChoices.length, (i) {
            final active = i == colorIdx;
            return GestureDetector(
              onTap: () => setLocal(() => colorIdx = i),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: CatHelper.colorChoices[i],
                  shape: BoxShape.circle,
                  border: active ? Border.all(color: AppColors.textPrimary, width: 2.5) : null,
                ),
                child: active ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
            );
          })),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) { setLocal(() => error = 'Enter a name'); return; }
            if (state.allCategories.any((c) => c.toLowerCase() == name.toLowerCase())) {
              setLocal(() => error = 'That category already exists');
              return;
            }
            Navigator.pop(dialogCtx, true);
          },
          child: const Text('Add'),
        ),
      ],
    )),
  );

  if (confirmed == true) {
    final name = nameCtrl.text.trim();
    await state.addCustomCategory(name, iconIdx, colorIdx);
    return name;
  }
  return null;
}

// ─── Category Icon Widget ─────────────────────────────────────────────────────
class CategoryIconWidget extends StatelessWidget {
  final String category;
  final double size;
  const CategoryIconWidget({super.key, required this.category, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = CatHelper.color(category);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Icon(CatHelper.icon(category), color: c, size: size * 0.5),
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────
class TransactionTile extends StatelessWidget {
  final AppTransaction tx;
  final AppState state;
  final VoidCallback? onDelete;

  const TransactionTile({super.key, required this.tx, required this.state, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final member = state.memberById(tx.memberId);
    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(children: [
          CategoryIconWidget(category: tx.category),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
            Row(children: [
              if (member != null) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: member.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(member.name.split(' ')[0], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
              Text(state.timeAgo(tx.date), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              if (tx.note.isNotEmpty) ...[
                const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                Flexible(child: Text(tx.note, style: const TextStyle(fontSize: 11, color: AppColors.textLight), overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ])),
          Text(
            '${tx.isIncome ? '+' : '-'}${state.formatAmount(tx.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                color: tx.isIncome ? AppColors.income : AppColors.expense),
          ),
        ]),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      if (action != null)
        GestureDetector(onTap: onAction,
          child: Text(action!, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ─── Pill Chip ────────────────────────────────────────────────────────────────
class PillChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const PillChip({super.key, required this.label, required this.active, required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final c = activeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : AppColors.divider),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.textSecondary,
        )),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surfaceWarm, shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: AppColors.textLight),
        ),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─── Stat Tile ────────────────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;

  const StatTile({super.key, required this.label, required this.value,
      required this.icon, required this.color, this.dark = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? color : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: dark ? Colors.white70 : color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800,
          color: dark ? Colors.white : color, fontFamily: 'Poppins',
        )),
        Text(label, style: TextStyle(
          fontSize: 10, color: dark ? Colors.white60 : AppColors.textSecondary,
        )),
      ]),
    ),
  );
}
