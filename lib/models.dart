/// A person-to-person transaction: money you paid someone ('gave') or
/// received from them ('got').
class Txn {
  const Txn({required this.id, required this.type, required this.amount, required this.person, required this.date, this.note = ''});

  final int id;
  final String type; // 'got' | 'gave'
  final double amount;
  final String person;
  final DateTime date; // local date, midnight
  final String note;

  bool get isGot => type == 'got';
  double get signed => isGot ? amount : -amount;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'amount': amount, 'person': person, 'date': isoDate(date), 'note': note};

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as int,
        type: j['type'] as String,
        amount: (j['amount'] as num).toDouble(),
        person: j['person'] as String,
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
      );
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Oct 2026"
String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "Oct 23, 2026"
String dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Today", "Yesterday" or "Thu, Oct 22".
String dayLabel(DateTime d, DateTime today) {
  final diff = dateOnly(today).difference(dateOnly(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// Rupees with Indian digit grouping: ₹1,00,000 or ₹1,250.50.
String fmt(double n) {
  final a = n.abs();
  final cents = (a * 100).round();
  final whole = cents ~/ 100, frac = cents % 100;
  final s = whole.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final head = s.substring(0, s.length - 3), tail = s.substring(s.length - 3);
    final parts = <String>[];
    for (var i = head.length; i > 0; i -= 2) {
      parts.insert(0, head.substring(i - 2 < 0 ? 0 : i - 2, i));
    }
    grouped = '${parts.join(',')},$tail';
  }
  return '₹$grouped${frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}'}';
}

/// "+₹1,200" / "−₹450"
String signedFmt(double n) => '${n < 0 ? '−' : '+'}${fmt(n)}';

String initials(String name) => name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

/// Sample data from the design, shifted so the latest entry is today.
/// Used only when the app is built with `--dart-define=LEDGER_DEMO=true`.
List<Txn> sampleTxns(DateTime today) {
  const anchor = '2026-10-23';
  const rows = [
    (1, 'got', 5000.0, 'Ravi Kumar', '2026-10-01', 'Rent share'),
    (2, 'gave', 4000.0, 'Suresh Patil', '2026-10-02', 'October salary'),
    (3, 'gave', 1200.0, 'Ankit Verma', '2026-10-05', 'Movie tickets'),
    (4, 'got', 800.0, 'Priya Sharma', '2026-10-08', 'Dinner split'),
    (5, 'gave', 3000.0, 'Ravi Kumar', '2026-10-12', 'Short-term loan'),
    (6, 'got', 1500.0, 'Meera Iyer', '2026-10-14', 'Concert tickets'),
    (7, 'gave', 450.0, 'Meera Iyer', '2026-10-17', 'Cab fare'),
    (8, 'got', 1200.0, 'Ankit Verma', '2026-10-19', 'Paid back'),
    (9, 'gave', 650.0, 'Priya Sharma', '2026-10-22', 'Groceries'),
    (10, 'got', 3000.0, 'Ravi Kumar', '2026-10-22', 'Loan returned'),
    (11, 'gave', 320.0, 'Ankit Verma', '2026-10-23', 'Lunch'),
    (12, 'got', 5000.0, 'Ravi Kumar', '2026-09-01', 'Rent share'),
  ];
  final a = DateTime.parse(anchor), t = dateOnly(today);
  return [
    for (final r in rows)
      Txn(id: r.$1, type: r.$2, amount: r.$3, person: r.$4, note: r.$6, date: t.subtract(Duration(days: a.difference(DateTime.parse(r.$5)).inDays))),
  ];
}
