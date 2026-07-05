import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading       = true;
  bool _masterOn      = true;
  bool _tier80On      = true;
  bool _tier90On      = true;
  bool _tierOverOn    = true;
  bool _osPermission  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final master = await NotificationService.isMasterEnabled();
    final t80     = await NotificationService.isTierEnabled('80');
    final t90     = await NotificationService.isTierEnabled('90');
    final tOver   = await NotificationService.isTierEnabled('over');
    final osPerm  = await Permission.notification.isGranted;
    if (!mounted) return;
    setState(() {
      _masterOn     = master;
      _tier80On     = t80;
      _tier90On     = t90;
      _tierOverOn   = tOver;
      _osPermission = osPerm;
      _loading      = false;
    });
  }

  Future<void> _refreshOsPermission() async {
    final osPerm = await Permission.notification.isGranted;
    if (mounted) setState(() => _osPermission = osPerm);
  }

  @override
  Widget build(BuildContext context) {
    final state = StateProvider.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [

                if (!_osPermission) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.notifications_off_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text(
                          'Notifications are blocked at the system level. Alerts below won\'t show until you allow them.',
                          style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final granted = await Permission.notification.request();
                            if (!granted.isGranted) await openAppSettings();
                            await _refreshOsPermission();
                          },
                          child: const Text('Allow Notifications'),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                const SectionHeader(title: 'Budget Alerts'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(children: [
                    SwitchListTile(
                      title: const Text('Enable Budget Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Master switch for all notifications below', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      value: _masterOn,
                      activeColor: AppColors.primary,
                      onChanged: (v) async {
                        await NotificationService.setMasterEnabled(v);
                        setState(() => _masterOn = v);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    SwitchListTile(
                      title: const Text('80% Warning', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Notify when a budget reaches 80%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      value: _tier80On,
                      activeColor: AppColors.primary,
                      onChanged: !_masterOn ? null : (v) async {
                        await NotificationService.setTierEnabled('80', v);
                        setState(() => _tier80On = v);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    SwitchListTile(
                      title: const Text('90% Warning', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Notify when a budget reaches 90%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      value: _tier90On,
                      activeColor: AppColors.primary,
                      onChanged: !_masterOn ? null : (v) async {
                        await NotificationService.setTierEnabled('90', v);
                        setState(() => _tier90On = v);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    SwitchListTile(
                      title: const Text('Over-Budget Alert', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Notify when a budget is exceeded', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      value: _tierOverOn,
                      activeColor: AppColors.primary,
                      onChanged: !_masterOn ? null : (v) async {
                        await NotificationService.setTierEnabled('over', v);
                        setState(() => _tierOverOn = v);
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationService.sendTest();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Test notification sent — check your notification tray.'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Send Test Notification'),
                  ),
                ),

                const SectionHeader(title: 'Categories'),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(children: [
                    ...AppState.categories.map((cat) => ListTile(
                      dense: true,
                      leading: CategoryIconWidget(category: cat, size: 34),
                      title: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Text('Default', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    )),
                    if (state.customCategoryNames.isNotEmpty)
                      const Divider(height: 1, color: AppColors.divider),
                    ...state.customCategoryNames.map((cat) => ListTile(
                      dense: true,
                      leading: CategoryIconWidget(category: cat, size: 34),
                      title: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () => _confirmDeleteCategory(context, state, cat),
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showAddCategoryDialog(context, state),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Category'),
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, AppState state, String cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Delete "$cat"? Existing transactions/budgets in this category will keep showing it, but you won\'t be able to pick it for new ones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { state.removeCustomCategory(cat); Navigator.pop(context); },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
