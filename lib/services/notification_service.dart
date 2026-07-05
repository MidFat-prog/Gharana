import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all local push notifications for budget alerts.
/// Call [NotificationService.init] once at startup.
/// Call [NotificationService.checkBudgets] after any transaction is added.
class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Track which budgets we've already notified to avoid spam
  static const _notifiedKey = 'gh_notified_budgets';

  // ── Settings keys (read/written from the Settings screen) ──────────────────
  // Master switch — when off, no budget alerts are sent at all.
  static const _masterKey   = 'gh_notif_master_enabled';
  // Individual alert tiers — each can be toggled independently.
  static const _tier80Key   = 'gh_notif_tier_80';
  static const _tier90Key   = 'gh_notif_tier_90';
  static const _tierOverKey = 'gh_notif_tier_over';

  static Future<bool> isMasterEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_masterKey) ?? true;

  static Future<void> setMasterEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_masterKey, v);

  static Future<bool> isTierEnabled(String tier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = tier == '80' ? _tier80Key : tier == '90' ? _tier90Key : _tierOverKey;
    return prefs.getBool(key) ?? true;
  }

  static Future<void> setTierEnabled(String tier, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    final key = tier == '80' ? _tier80Key : tier == '90' ? _tier90Key : _tierOverKey;
    await prefs.setBool(key, v);
  }

  /// Whether the OS-level notification permission is currently granted.
  /// Returns null on platforms/plugin versions where this can't be checked.
  static Future<bool?> hasOsPermission() async {
    return await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
  }

  /// Re-prompts the OS permission dialog (Android 13+). Returns the result.
  static Future<bool?> requestOsPermission() async {
    return await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Fires a one-off notification so the user can confirm alerts are working,
  /// regardless of the master/tier toggles above (it's an explicit test).
  static Future<void> sendTest() async {
    await _send(
      id:    999999,
      title: '🔔 Test Notification',
      body:  'If you can see this, Gharana budget alerts are working correctly.',
      importance: Importance.high,
      priority:   Priority.high,
    );
  }

  // ── Init ────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Budget check ────────────────────────────────────────────────────────────
  // Call this after every transaction add / delete / budget update.
  // [budgets] = list of {id, category, limit, spent}
  static Future<void> checkBudgets(List<_BudgetInfo> budgets) async {
    final prefs    = await SharedPreferences.getInstance();
    final notified = (prefs.getStringList(_notifiedKey) ?? []).toSet();

    // Respect the user's notification settings (Settings screen).
    final masterOn = prefs.getBool(_masterKey) ?? true;
    if (!masterOn) return;
    final tier80On   = prefs.getBool(_tier80Key)   ?? true;
    final tier90On   = prefs.getBool(_tier90Key)   ?? true;
    final tierOverOn = prefs.getBool(_tierOverKey) ?? true;

    for (final b in budgets) {
      final pct = b.limit > 0 ? b.spent / b.limit : 0.0;

      // ── Over budget ─────────────────────────────────────────────────────
      final overKey = '${b.id}_over';
      if (pct >= 1.0 && !notified.contains(overKey)) {
        if (tierOverOn) {
          await _send(
            id:    b.id.hashCode & 0x7FFFFFFF,
            title: '🚨 Budget Exceeded — ${b.category}',
            body:  'You\'ve gone over your ${b.category} budget by '
                   'Rs ${(b.spent - b.limit).toStringAsFixed(0)}.',
            importance: Importance.high,
            priority:   Priority.high,
          );
        }
        notified
          ..add(overKey)
          // Clear the "near" key so if they reset it fires again
          ..remove('${b.id}_near80')
          ..remove('${b.id}_near90');
      }

      // ── 90% warning ─────────────────────────────────────────────────────
      else if (pct >= 0.9 && pct < 1.0 && !notified.contains('${b.id}_near90')) {
        if (tier90On) {
          await _send(
            id:    (b.id.hashCode & 0x7FFFFFFF) + 1,
            title: '⚠️ Almost Over — ${b.category}',
            body:  '${b.category} budget is at ${(pct * 100).toStringAsFixed(0)}%. '
                   'Only Rs ${(b.limit - b.spent).toStringAsFixed(0)} left.',
            importance: Importance.defaultImportance,
            priority:   Priority.defaultPriority,
          );
        }
        notified.add('${b.id}_near90');
      }

      // ── 80% warning ─────────────────────────────────────────────────────
      else if (pct >= 0.8 && pct < 0.9 && !notified.contains('${b.id}_near80')) {
        if (tier80On) {
          await _send(
            id:    (b.id.hashCode & 0x7FFFFFFF) + 2,
            title: '📊 Budget Alert — ${b.category}',
            body:  '${b.category} is at ${(pct * 100).toStringAsFixed(0)}% of limit. '
                   'Rs ${(b.limit - b.spent).toStringAsFixed(0)} remaining.',
            importance: Importance.low,
            priority:   Priority.low,
          );
        }
        notified.add('${b.id}_near80');
      }

      // ── Reset if dropped back below 80% (e.g. deleted a tx) ─────────────
      else if (pct < 0.8) {
        notified
          ..remove('${b.id}_near80')
          ..remove('${b.id}_near90')
          ..remove('${b.id}_over');
      }
    }

    await prefs.setStringList(_notifiedKey, notified.toList());
  }

  // ── Send helper ─────────────────────────────────────────────────────────────
  static Future<void> _send({
    required int id,
    required String title,
    required String body,
    required Importance importance,
    required Priority priority,
  }) async {
    await _plugin.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'gharana_budgets',
          'Budget Alerts',
          channelDescription: 'Notifications when spending approaches or exceeds budget limits',
          importance: importance,
          priority:   priority,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

/// Lightweight budget info passed to checkBudgets
class _BudgetInfo {
  final String id;
  final String category;
  final double limit;
  final double spent;
  const _BudgetInfo({required this.id, required this.category, required this.limit, required this.spent});
}

// Public helper so app_state can call this without importing the private class
Future<void> triggerBudgetNotifications(
    List<Map<String, dynamic>> budgets) async {
  final infos = budgets.map((b) => _BudgetInfo(
        id:       b['id'] as String,
        category: b['category'] as String,
        limit:    (b['limit'] as num).toDouble(),
        spent:    (b['spent'] as num).toDouble(),
      )).toList();
  await NotificationService.checkBudgets(infos);
}
