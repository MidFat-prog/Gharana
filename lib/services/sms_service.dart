import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_parser.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  static const _processedKey   = 'gh_processed_sms';
  static const _installTimeKey  = 'gh_install_time';
  static const _scanCursorKey   = 'gh_scan_cursor'; // timestamp of newest SMS we've fully scanned

  Function(List<ParsedSms>)? onNewTransactions;

  // ── Permission ─────────────────────────────────────────────────────────────
  Future<bool> requestPermission() async =>
      (await Permission.sms.request()).isGranted;

  Future<bool> hasPermission() async => await Permission.sms.isGranted;

  // ── Install timestamp ──────────────────────────────────────────────────────
  // Called once from main.dart on every cold start.
  // Saves current time ONLY if never saved — permanently marks "first open".
  static Future<void> initInstallTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_installTimeKey)) {
      await prefs.setString(_installTimeKey, DateTime.now().toIso8601String());
    }
  }

  Future<DateTime> _getInstallTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_installTimeKey);
    return raw != null ? DateTime.parse(raw) : DateTime.now();
  }

  // ── Scan cursor ────────────────────────────────────────────────────────────
  // After each full scan we save the timestamp of the NEWEST SMS we processed.
  // Next scan starts from here — but we always go back 2 minutes behind the
  // cursor to handle same-minute bursts and clock skew.
  Future<DateTime> _getScanCursor() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_scanCursorKey);
    if (raw != null) return DateTime.parse(raw);
    // First time: fall back to install time
    return _getInstallTime();
  }

  Future<void> _advanceCursor(DateTime to) async {
    final prefs = await SharedPreferences.getInstance();
    // Only move cursor forward, never backward
    final current = await _getScanCursor();
    if (to.isAfter(current)) {
      await prefs.setString(_scanCursorKey, to.toIso8601String());
    }
  }

  // ── Processed IDs ─────────────────────────────────────────────────────────
  // Source of truth for dedup. Timestamp alone is never enough — multiple SMS
  // can share the same second or minute. We ALWAYS check ID too.
  Future<Set<String>> _getProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_processedKey)?.toSet() ?? {};
  }

  Future<void> markProcessed(List<String> ids) async {
    if (ids.isEmpty) return;
    final prefs     = await SharedPreferences.getInstance();
    final processed = await _getProcessedIds();
    processed.addAll(ids);
    final list = processed.toList();
    if (list.length > 10000) list.removeRange(0, list.length - 10000);
    await prefs.setStringList(_processedKey, list);
  }

  // ── Full scan ──────────────────────────────────────────────────────────────
  // Fetches all SMS since (cursor - 2 min) so we never miss a burst.
  // After scan, advances cursor to the newest SMS timestamp found.
  //
  // Why cursor - 2 min?
  //   If 3 SMS arrive at 14:00:00, 14:00:01, 14:00:02 and we scan after the
  //   first one and set cursor = 14:00:00, the next scan starting at 14:00:00
  //   would miss the other two IF we used strict isAfter(cursor).
  //   Going back 2 minutes guarantees all of them are in the window.
  //   Processed IDs prevent double-counting.
  Future<List<ParsedSms>> scanInbox() async {
    if (!await hasPermission()) return [];

    try {
      final installTime = await _getInstallTime();
      final cursor      = await _getScanCursor();
      // Scan window starts 2 minutes before cursor (burst safety net)
      final windowStart = cursor.subtract(const Duration(minutes: 2));
      // But never go before install time
      final effectiveStart = windowStart.isAfter(installTime) ? windowStart : installTime;

      final processed = await _getProcessedIds();

      final query   = SmsQuery();
      final allMsgs = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 500,
      );

      final results   = <ParsedSms>[];
      DateTime? newestDate;

      for (final msg in allMsgs) {
        final id     = msg.id?.toString() ?? '';
        final sender = msg.sender ?? msg.address ?? '';
        final body   = msg.body ?? '';
        final date   = msg.date ?? DateTime.now();

        // Outside our window — skip
        if (date.isBefore(effectiveStart)) continue;

        // Already accepted or discarded — skip (but still track for cursor)
        if (id.isEmpty || processed.contains(id)) {
          // Still update newest date even for processed ones
          if (newestDate == null || date.isAfter(newestDate)) newestDate = date;
          continue;
        }

        final parsed = SmsParser.parse(
          sender: sender, body: body, date: date, smsId: id,
        );

        if (parsed != null) {
          results.add(parsed);
          if (newestDate == null || date.isAfter(newestDate)) newestDate = date;
        }
      }

      // Advance cursor to the newest SMS we touched (parsed or processed)
      // so the next scan starts from here, not from install time
      if (newestDate != null) await _advanceCursor(newestDate);

      results.sort((a, b) => b.date.compareTo(a.date));
      return results;
    } catch (e) {
      return [];
    }
  }

  // ── Live polling while screen is open ─────────────────────────────────────
  // Polls every 10 seconds.
  // Window = (lastPollAt - 60 seconds) to catch:
  //   - SMS that arrived between the last tick and this one
  //   - SMS whose timestamp is slightly behind our clock (carrier delay)
  //   - Bursts where multiple SMS arrive within the same poll window
  // Processed IDs prevent double-showing anything we already surfaced.
  bool _polling    = false;
  DateTime _lastPollAt = DateTime.now();

  void startListening() {
    _polling     = true;
    _lastPollAt  = DateTime.now();
    _pollLoop();
  }

  void stopListening() => _polling = false;

  Future<void> _pollLoop() async {
    while (_polling) {
      await Future.delayed(const Duration(seconds: 10));
      if (!_polling) break;
      try {
        final found = await _pollSince(_lastPollAt);
        // Advance lastPollAt BEFORE calling callback to avoid re-entry races
        _lastPollAt = DateTime.now();
        if (found.isNotEmpty) onNewTransactions?.call(found);
      } catch (_) {}
    }
  }

  Future<List<ParsedSms>> _pollSince(DateTime since) async {
    if (!await hasPermission()) return [];

    final installTime = await _getInstallTime();
    // Go back 60s from last poll to catch bursts and carrier-delayed SMS
    final window = since.subtract(const Duration(seconds: 60));
    // Never go before install time
    final cutoff = window.isAfter(installTime) ? window : installTime;

    final processed = await _getProcessedIds();

    final query   = SmsQuery();
    // Fetch 100 — overkill for 10s window but catches any unusual burst
    final allMsgs = await query.querySms(kinds: [SmsQueryKind.inbox], count: 100);
    final inWindow = allMsgs.where((m) =>
        m.date != null && m.date!.isAfter(cutoff)).toList();

    final results   = <ParsedSms>[];
    DateTime? newestDate;

    for (final msg in inWindow) {
      final id     = msg.id?.toString() ?? '';
      final sender = msg.sender ?? msg.address ?? '';
      final body   = msg.body ?? '';
      final date   = msg.date ?? DateTime.now();

      if (newestDate == null || date.isAfter(newestDate)) newestDate = date;

      if (id.isEmpty || processed.contains(id)) continue;

      final parsed = SmsParser.parse(
        sender: sender, body: body, date: date, smsId: id,
      );
      if (parsed != null) results.add(parsed);
    }

    // Advance scan cursor if poll found newer SMS
    if (newestDate != null) await _advanceCursor(newestDate);

    return results;
  }
}
