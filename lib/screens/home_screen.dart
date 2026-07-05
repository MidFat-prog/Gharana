import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateProvider.of(context);
    final user  = state.currentUser;
    final recent = state.filteredTransactions().take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
        child: CustomScrollView(
          slivers: [
            // ── App bar ──
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('As-salamu alaykum,',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
                Text(user?.name.split(' ')[0] ?? 'Guest',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.textPrimary),
                  tooltip: 'Export Monthly Report',
                  onPressed: () => _exportMonthlyPdf(context, state),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                  onPressed: () => _showNotifications(context, state),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _showProfileMenu(context, state),
                    child: user != null
                        ? AvatarWidget(initials: user.initials, color: user.color, size: 36)
                        : const Icon(Icons.person_rounded),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Balance card ──
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
                        const Text('Family Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('June 2025', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        state.formatAmount(state.balance),
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 18),
                      Container(height: 0.5, color: Colors.white24),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _BalanceStat(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Income',
                          value: state.formatAmount(state.totalIncome),
                          color: const Color(0xFF6EC89A),
                        )),
                        Container(width: 0.5, height: 32, color: Colors.white24),
                        Expanded(child: _BalanceStat(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Expenses',
                          value: state.formatAmount(state.totalExpense),
                          color: const Color(0xFFE2806A),
                        )),
                      ]),
                    ]),
                  ),

                  // ── Quick stats ──
                  const SizedBox(height: 16),
                  Row(children: [
                    StatTile(label: 'Budgets', value: '${state.budgets.length}',
                        icon: Icons.pie_chart_rounded, color: AppColors.primary, dark: true),
                    const SizedBox(width: 10),
                    StatTile(
                      label: 'Near Limit',
                      value: '${state.budgets.where((b) => state.spentForBudget(b) / b.limit >= 0.8).length}',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    StatTile(label: 'Members', value: '${state.members.length}',
                        icon: Icons.people_rounded, color: AppColors.accent),
                  ]),

                  // ── Alerts ──
                  ..._buildAlerts(state),

                  // ── Recent transactions ──
                  SectionHeader(
                    title: 'Recent',
                    action: 'See all',
                    onAction: () {
                      // Switch to transactions tab - handled by parent
                    },
                  ),
                  if (recent.isEmpty)
                    const EmptyState(message: 'No transactions yet.\nTap + to add one.', icon: Icons.receipt_long_rounded)
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: recent.map((tx) => TransactionTile(
                          tx: tx, state: state,
                          onDelete: () => state.deleteTransaction(tx.id),
                        )).toList(),
                      ),
                    ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAlerts(AppState state) {
    final alerts = <Widget>[];
    for (final b in state.budgets) {
      final spent = state.spentForBudget(b);
      final pct = spent / b.limit;
      if (pct >= 1.0) {
        alerts.add(_AlertBanner(
          icon: Icons.error_rounded,
          message: '${b.category} is over budget by ${state.formatAmount(spent - b.limit)}!',
          color: AppColors.error,
        ));
      } else if (pct >= 0.8) {
        alerts.add(_AlertBanner(
          icon: Icons.warning_amber_rounded,
          message: '${b.category} is at ${(pct * 100).toStringAsFixed(0)}% — ${state.formatAmount(b.limit - spent)} left',
          color: AppColors.warning,
        ));
      }
    }
    if (alerts.isEmpty) return [];
    return [
      const SectionHeader(title: 'Alerts'),
      ...alerts.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: a)),
    ];
  }

  void _showNotifications(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...state.budgets.where((b) => state.spentForBudget(b) / b.limit >= 0.8).map((b) {
            final pct = state.spentForBudget(b) / b.limit;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              ),
              title: Text('${b.category} at ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(state.formatAmount(b.limit - state.spentForBudget(b)) + ' remaining',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            );
          }),
          if (state.budgets.every((b) => state.spentForBudget(b) / b.limit < 0.8))
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('All budgets on track! 🎉', style: TextStyle(color: AppColors.textSecondary)),
            )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Manage Alert Settings'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _exportMonthlyPdf(BuildContext context, AppState state) async {
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
      content: Text('Generating report…'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final monthLabel = _monthName(now.month);
      final txs = state.filteredTransactions().toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Gharana', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text('Monthly Spending Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('$monthLabel ${now.year}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(state.household?.name ?? 'Household', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ]),
          ]),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _pdfBox('Total Income',   state.formatAmount(state.totalIncome),   PdfColors.green800),
            pw.SizedBox(width: 10),
            _pdfBox('Total Expenses', state.formatAmount(state.totalExpense),  PdfColors.red700),
            pw.SizedBox(width: 10),
            _pdfBox('Net Balance',    state.formatAmount(state.balance),        PdfColors.blue800),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Member Spending', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                _pdfCell('Member', bold: true), _pdfCell('Transactions', bold: true), _pdfCell('Spent', bold: true),
              ]),
              ...state.members.map((m) => pw.TableRow(children: [
                _pdfCell(m.name),
                _pdfCell('${txs.where((t) => t.memberId == m.id && !t.isIncome).length}'),
                _pdfCell(state.formatAmount(state.spentByMember(m.id))),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),
          if (state.budgets.isNotEmpty) ...[
            pw.Text('Budget Overview', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                  _pdfCell('Category', bold: true), _pdfCell('Limit', bold: true),
                  _pdfCell('Spent', bold: true), _pdfCell('Status', bold: true),
                ]),
                ...state.budgets.map((b) {
                  final spent = state.spentForBudget(b);
                  final pct   = b.limit > 0 ? spent / b.limit : 0.0;
                  final status = pct >= 1.0 ? 'Over!' : pct >= 0.8 ? 'Near limit' : 'On track';
                  final color  = pct >= 1.0 ? PdfColors.red700 : pct >= 0.8 ? PdfColors.orange700 : PdfColors.green700;
                  return pw.TableRow(children: [
                    _pdfCell(b.category), _pdfCell(state.formatAmount(b.limit)), _pdfCell(state.formatAmount(spent)),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Text(status, style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold))),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Text('Transactions (latest 50)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                _pdfCell('Date', bold: true), _pdfCell('Member', bold: true),
                _pdfCell('Category', bold: true), _pdfCell('Amount', bold: true), _pdfCell('Note', bold: true),
              ]),
              ...txs.take(50).map((tx) {
                final member = state.members.firstWhere((m) => m.id == tx.memberId,
                    orElse: () => state.members.first);
                return pw.TableRow(children: [
                  _pdfCell('${tx.date.day}/${tx.date.month}'),
                  _pdfCell(member.name.split(' ')[0]),
                  _pdfCell(tx.category),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text(
                      (tx.isIncome ? '+' : '-') + state.formatAmount(tx.amount),
                      style: pw.TextStyle(fontSize: 10,
                        color: tx.isIncome ? PdfColors.green700 : PdfColors.red700,
                        fontWeight: pw.FontWeight.bold),
                    )),
                  _pdfCell(tx.note.isEmpty ? '—' : tx.note),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated by Gharana · ${now.day}/${now.month}/${now.year}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ));

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/gharana_${monthLabel.toLowerCase()}_${now.year}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], subject: 'Gharana Report — $monthLabel ${now.year}');
    } catch (e) {
      snack.showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static pw.Widget _pdfBox(String label, String value, PdfColor color) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: color, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        ]),
      ));

  static pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );

  static String _monthName(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][m];

  void _showProfileMenu(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final user = state.currentUser;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (user != null) ...[
              AvatarWidget(initials: user.initials, color: user.color, size: 60),
              const SizedBox(height: 12),
              Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(user.roleLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(user.phone, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 20),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () async {
                await state.logout();
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
            ),
          ]),
        );
      },
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _BalanceStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
  ]);
}

class _AlertBanner extends StatelessWidget {
  final IconData icon; final String message; final Color color;
  const _AlertBanner({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
    ]),
  );
}
