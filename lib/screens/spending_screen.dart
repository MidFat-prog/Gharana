import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});
  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  String _view = 'category'; // 'category' | 'member'

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state   = StateProvider.of(context);
    final txs     = state.filteredTransactions().where((t) => !t.isIncome).toList();
    final total   = txs.fold(0.0, (s, t) => s + t.amount);

    // Aggregate by category
    final catMap = <String, double>{};
    for (final t in txs) catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    final catEntries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Aggregate by member
    final members = state.members;
    final memberSpends = members.map((m) => state.spentByMember(m.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Spending')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [

          // ── Summary card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2040), Color(0xFF1A3A6B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Spending',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${catEntries.length} categories',
                    style: const TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(state.formatAmount(total),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 32,
                      fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              const SizedBox(height: 4),
              Text('${txs.length} transactions',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),

          // ── Toggle ──────────────────────────────────────────────────────
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _Tab(label: 'By Category', active: _view == 'category',
                  onTap: () => setState(() { _view = 'category'; _ctrl.forward(from: 0); })),
              _Tab(label: 'By Member',   active: _view == 'member',
                  onTap: () => setState(() { _view = 'member';   _ctrl.forward(from: 0); })),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Histogram ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                if (_view == 'category') {
                  return catEntries.isEmpty
                      ? const _EmptyChart()
                      : _Histogram(
                          bars: catEntries
                              .take(8)
                              .map((e) => _Bar(
                                    label: _shortLabel(e.key),
                                    value: e.value,
                                    color: CatHelper.color(e.key),
                                    icon: CatHelper.icon(e.key),
                                  ))
                              .toList(),
                          progress: _anim.value,
                          state: state,
                        );
                } else {
                  return members.isEmpty
                      ? const _EmptyChart()
                      : _Histogram(
                          bars: members
                              .asMap()
                              .entries
                              .map((e) => _Bar(
                                    label: e.value.name.split(' ')[0],
                                    value: memberSpends[e.key],
                                    color: e.value.color,
                                    icon: Icons.person_rounded,
                                  ))
                              .toList()
                            ..sort((a, b) => b.value.compareTo(a.value)),
                          progress: _anim.value,
                          state: state,
                        );
                }
              },
            ),
          ),

          // ── Ranked list ─────────────────────────────────────────────────
          const SectionHeader(title: 'Breakdown'),
          if (catEntries.isEmpty)
            const EmptyState(
                message: 'No expenses yet.', icon: Icons.receipt_long_rounded)
          else
            ...catEntries.map((e) => _RankRow(
                  category: e.key,
                  amount: e.value,
                  total: total,
                  state: state,
                )),
        ],
      ),
    );
  }

  String _shortLabel(String cat) {
    const map = {
      'Bijli Bill': 'Bijli',
      'Gas Bill': 'Gas',
      'Mobile Credit': 'Mobile',
      'Eating Out': 'Eating',
      'School Fee': 'School',
    };
    return map[cat] ?? cat;
  }
}

// ── Toggle tab ────────────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textSecondary,
        )),
      ),
    ),
  );
}

// ── Bar model ─────────────────────────────────────────────────────────────────
class _Bar {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _Bar({required this.label, required this.value, required this.color, required this.icon});
}

// ── Vertical histogram ────────────────────────────────────────────────────────
class _Histogram extends StatelessWidget {
  final List<_Bar> bars;
  final double progress;
  final AppState state;
  const _Histogram({required this.bars, required this.progress, required this.state});

  @override
  Widget build(BuildContext context) {
    final maxVal = bars.isEmpty ? 1.0 : bars.map((b) => b.value).reduce(max);
    const chartH = 160.0;

    return Column(children: [
      // The bars
      SizedBox(
        height: chartH + 48, // bars + label area
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: bars.map((bar) {
            final ratio = maxVal > 0 ? (bar.value / maxVal) * progress : 0.0;
            final barH  = (chartH * ratio).clamp(4.0, chartH);
            final isTop = bar.value == maxVal;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Amount label above bar (only for top bar, else on hover)
                    if (isTop)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bar.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _compact(bar.value),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 22),

                    // The bar itself
                    Container(
                      width: double.infinity,
                      height: barH,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [bar.color.withOpacity(0.55), bar.color],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        boxShadow: isTop
                            ? [BoxShadow(color: bar.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, -2))]
                            : [],
                      ),
                    ),

                    // Icon + label below bar
                    const SizedBox(height: 6),
                    Icon(bar.icon, size: 14, color: bar.color),
                    const SizedBox(height: 2),
                    Text(
                      bar.label,
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),

      // Axis line
      const SizedBox(height: 4),
      Container(height: 1, color: AppColors.divider),
      const SizedBox(height: 12),

      // Legend row
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: bars.first.color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('Highest: ${state.formatAmount(bars.first.value)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: bars.last.color.withOpacity(0.5), borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('Lowest: ${state.formatAmount(bars.last.value)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Empty chart placeholder ────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 140,
    child: Center(child: Text('No data yet', style: TextStyle(color: AppColors.textLight))),
  );
}

// ── Ranked breakdown row ──────────────────────────────────────────────────────
class _RankRow extends StatelessWidget {
  final String category;
  final double amount;
  final double total;
  final AppState state;
  const _RankRow({required this.category, required this.amount, required this.total, required this.state});

  @override
  Widget build(BuildContext context) {
    final pct   = total > 0 ? amount / total : 0.0;
    final color = CatHelper.color(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        CategoryIconWidget(category: category, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(category, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            Text(state.formatAmount(amount),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(pct * 100).toStringAsFixed(1)}% of total spending',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }
}
