// lib/services/sms_parser.dart
// Parses Pakistani bank & mobile wallet SMS into transaction data

class ParsedSms {
  final double amount;
  final bool isIncome;
  final String category;
  final String source;   // bank/wallet name
  final String rawBody;
  final DateTime date;
  final String smsId;    // unique ID for deduplication

  ParsedSms({
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.source,
    required this.rawBody,
    required this.date,
    required this.smsId,
  });

  String get note => '${isIncome ? "Received from" : "Paid via"} $source';
}

class SmsParser {
  // ── Known Pakistani bank/wallet sender IDs ────────────────────────────────
  static const _knownSenders = {
    // JazzCash
    'JAZZCASH', 'JazzCash', 'JAZZ',
    // EasyPaisa
    'EASYPAISA', 'EasyPaisa', 'Easypaisa', 'TELENOR',
    // HBL
    'HBL', 'HBLMOB', 'HBL-MOBILE',
    // Meezan
    'MEEZAN', 'MEEZANBANK', 'MIB',
    // UBL
    'UBL', 'UBLDIGITAL',
    // MCB
    'MCB', 'MCBBANK',
    // ABL
    'ABL', 'ABLBANK',
    // Faysal
    'FAYSAL', 'FAYSALBANK',
    // Allied
    'ALLIED', 'ALLIEDBANK',
    // Bank Alfalah
    'ALFALAH', 'BANKALFALAH',
    // Sadapay / Nayapay
    'SADAPAY', 'NAYAPAY',
    // Raast
    'RAAST', 'SBP',
  };

  // ── Amount regex patterns ─────────────────────────────────────────────────
  static final _amountPatterns = [
    // Rs. 1,234.56 or Rs 1234 or PKR 1,234
    RegExp(r'(?:Rs\.?|PKR|Rupees?)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    // 1,234.56 PKR
    RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|PKR|Rupees?)', caseSensitive: false),
    // Amount: 1234
    RegExp(r'[Aa]mount[:\s]+(?:Rs\.?|PKR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
  ];

  // ── Debit keywords ────────────────────────────────────────────────────────
  static final _debitKeywords = RegExp(
    r'\b(debited|deducted|paid|payment|sent|transferred|withdrawn|purchase|spent|'
    r'charged|bill|fee|top.?up|loaded|outgoing)\b',
    caseSensitive: false,
  );

  // ── Credit keywords ───────────────────────────────────────────────────────
  static final _creditKeywords = RegExp(
    r'\b(credited|received|added|incoming|deposit|refund|cashback|salary|'
    r'transferred to your|money received)\b',
    caseSensitive: false,
  );

  // ── Category guesser ──────────────────────────────────────────────────────
  static String _guessCategory(String body, bool isIncome) {
    final b = body.toLowerCase();
    if (isIncome) {
      if (b.contains('salary') || b.contains('payroll')) return 'Salary';
      if (b.contains('freelance') || b.contains('payment received')) return 'Freelance';
      return 'Other';
    }
    if (b.contains('bill') || b.contains('bijli') || b.contains('electric') ||
        b.contains('wapda') || b.contains('k-electric')) return 'Bijli Bill';
    if (b.contains('gas') || b.contains('sui')) return 'Gas Bill';
    if (b.contains('internet') || b.contains('broadband') || b.contains('wifi')) return 'Internet';
    if (b.contains('school') || b.contains('fee') || b.contains('tuition')) return 'School Fee';
    if (b.contains('medicine') || b.contains('pharmacy') || b.contains('medical') ||
        b.contains('hospital') || b.contains('clinic')) return 'Medicine';
    if (b.contains('petrol') || b.contains('fuel') || b.contains('pso') ||
        b.contains('shell') || b.contains('caltex')) return 'Petrol';
    if (b.contains('rickshaw') || b.contains('uber') || b.contains('careem') ||
        b.contains('bykea') || b.contains('transport')) return 'Rickshaw';
    if (b.contains('groceri') || b.contains('ration') || b.contains('imtiaz') ||
        b.contains('carrefour') || b.contains('metro') || b.contains('store')) return 'Ration';
    if (b.contains('restaurant') || b.contains('food') || b.contains('eat') ||
        b.contains('cafe') || b.contains('biryani') || b.contains('pizza')) return 'Eating Out';
    if (b.contains('clothes') || b.contains('garment') || b.contains('suit') ||
        b.contains('shirt') || b.contains('khaadi') || b.contains('gul ahmed')) return 'Clothes';
    if (b.contains('rent') || b.contains('kiraya')) return 'Rent';
    if (b.contains('mobile') || b.contains('recharge') || b.contains('jazz') ||
        b.contains('zong') || b.contains('ufone') || b.contains('telenor')) return 'Mobile Credit';
    return 'Other';
  }

  // ── Source name extractor ─────────────────────────────────────────────────
  static String _extractSource(String sender, String body) {
    final s = sender.toUpperCase();
    if (s.contains('JAZZ')) return 'JazzCash';
    if (s.contains('EASY') || s.contains('TELENOR')) return 'EasyPaisa';
    if (s.contains('HBL')) return 'HBL';
    if (s.contains('MEEZAN') || s.contains('MIB')) return 'Meezan Bank';
    if (s.contains('UBL')) return 'UBL';
    if (s.contains('MCB')) return 'MCB';
    if (s.contains('ABL')) return 'ABL';
    if (s.contains('FAYSAL')) return 'Faysal Bank';
    if (s.contains('ALLIED')) return 'Allied Bank';
    if (s.contains('ALFALAH')) return 'Bank Alfalah';
    if (s.contains('SADAPAY')) return 'SadaPay';
    if (s.contains('NAYAPAY')) return 'NayaPay';
    if (s.contains('RAAST') || s.contains('SBP')) return 'Raast';
    // Try to guess from body
    final b = body.toLowerCase();
    if (b.contains('jazzcash')) return 'JazzCash';
    if (b.contains('easypaisa')) return 'EasyPaisa';
    if (b.contains('hbl')) return 'HBL';
    if (b.contains('meezan')) return 'Meezan Bank';
    return sender;
  }

  // ── Main parse method ─────────────────────────────────────────────────────
  static ParsedSms? parse({
    required String sender,
    required String body,
    required DateTime date,
    required String smsId,
  }) {
    // Only process known financial senders
    final senderUp = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final isKnown  = _knownSenders.any((k) => senderUp.contains(k.toUpperCase()));

    // Also try body keywords if sender is unknown
    final hasFinancialBody = body.toLowerCase().contains('rs') ||
        body.toLowerCase().contains('pkr') ||
        body.toLowerCase().contains('account') ||
        body.toLowerCase().contains('balance');

    if (!isKnown && !hasFinancialBody) return null;

    // Extract amount
    double? amount;
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '');
        amount = double.tryParse(raw);
        if (amount != null && amount > 0) break;
      }
    }
    if (amount == null || amount <= 0) return null;

    // Determine income/expense
    final hasDebit  = _debitKeywords.hasMatch(body);
    final hasCredit = _creditKeywords.hasMatch(body);

    // If neither or both match, skip ambiguous messages
    if (!hasDebit && !hasCredit) return null;
    final isIncome = hasCredit && !hasDebit;

    return ParsedSms(
      amount:   amount,
      isIncome: isIncome,
      category: _guessCategory(body, isIncome),
      source:   _extractSource(sender, body),
      rawBody:  body,
      date:     date,
      smsId:    smsId,
    );
  }
}
