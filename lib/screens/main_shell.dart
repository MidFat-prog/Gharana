import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sms_service.dart';
import '../services/sms_parser.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';
import 'spending_screen.dart';
import 'family_screen.dart';
import 'add_transaction_screen.dart';
import 'sms_transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  int _smsPendingCount = 0;
  final SmsService _smsService = SmsService();

  @override
  void initState() {
    super.initState();
    _initSms();
  }

  Future<void> _initSms() async {
    final hasPermission = await _smsService.hasPermission();
    if (!hasPermission) return;

    // Scan inbox on app open
    final results = await _smsService.scanInbox();
    if (mounted && results.isNotEmpty) {
      setState(() => _smsPendingCount = results.length);
      _showSmsBanner(results.length);
    }

    // Listen for new incoming SMS while app is open
    _smsService.onNewTransactions = (List<ParsedSms> txs) {
      if (mounted) {
        setState(() => _smsPendingCount += txs.length);
        _showSmsBanner(_smsPendingCount);
      }
    };
    _smsService.startListening();
  }

  void _showSmsBanner(int count) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('$count new transaction${count == 1 ? '' : 's'} detected from SMS'),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Review',
          textColor: Colors.white,
          onPressed: _openSmsScreen,
        ),
      ),
    );
  }

  void _openSmsScreen() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const SmsTransactionsScreen(),
    ));
    // Clear badge after reviewing
    if (mounted) setState(() => _smsPendingCount = 0);
  }

  @override
  void dispose() {
    _smsService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const TransactionsScreen(),
      const SpendingScreen(),
      const FamilyScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(),
          ));
          setState(() {});
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 64,
        elevation: 8,
        color: AppColors.surface,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded,         label: 'Home',    active: _tab == 0, onTap: () => setState(() => _tab = 0)),
            _NavItem(icon: Icons.receipt_long_rounded, label: 'History', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.bar_chart_rounded,    label: 'Spending', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
            // SMS badge on Family tab replaced with dedicated SMS icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                _NavItem(icon: Icons.sms_rounded, label: 'SMS', active: false, onTap: _openSmsScreen),
                if (_smsPendingCount > 0)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_smsPendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            _NavItem(icon: Icons.people_rounded, label: 'Family', active: _tab == 3, onTap: () => setState(() => _tab = 3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? AppColors.primary : AppColors.textLight, size: 22),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? AppColors.primary : AppColors.textLight,
        )),
      ]),
    ),
  );
}
