import '../models.dart';
import 'odoo_client.dart';

/// What the app needs from the server. [PaymentApi] is the Odoo version;
/// tests use an in-memory one.
abstract class PaymentGateway {
  /// Throws [OdooException] unless the address, database and key all work.
  Future<void> check();

  /// Every payment, as transactions that carry their Odoo id.
  Future<List<Txn>> fetchAll();

  /// Creates [t] on the server (ignoring `t.id`) and returns the new Odoo id.
  Future<int> create(Txn t);

  Future<void> update(Txn t);

  Future<void> delete(int id);
}

/// Maps a [Txn] to an `account.payment` record:
///
/// | Txn      | account.payment                                     |
/// | -------- | --------------------------------------------------- |
/// | received | `payment_type = inbound`, `partner_type = customer` |
/// | paid     | `payment_type = outbound`, `partner_type = customer` |
/// | person   | `partner_id` (a `res.partner`, found or created by name) |
/// | amount   | `amount`                                            |
/// | date     | `date`                                              |
/// | note     | `memo`                                              |
///
/// Payments are left in draft, so they stay editable and deletable from the app.
class PaymentApi implements PaymentGateway {
  PaymentApi(this._odoo);

  final OdooClient _odoo;
  final _partnerIds = <String, int>{};

  static const _model = 'account.payment';
  static const _fields = ['payment_type', 'partner_id', 'amount', 'date', 'memo'];

  @override
  Future<void> check() async {
    await _odoo.call('res.partner', 'search_count', args: {'domain': <Object>[]});
    await _odoo.call(_model, 'search_count', args: {'domain': <Object>[]});
  }

  @override
  Future<List<Txn>> fetchAll() async {
    final rows = await _odoo.call(_model, 'search_read', args: {
      'domain': [
        ['partner_id', '!=', false],
        ['state', '!=', 'canceled'],
      ],
      'fields': _fields,
      'order': 'date desc, id desc',
    });
    if (rows is! List) throw const OdooException('Unexpected answer from Odoo when listing payments.');
    return [for (final r in rows) fromRecord(r as Map<String, dynamic>)];
  }

  @override
  Future<int> create(Txn t) async {
    final vals = await _values(t);
    final ids = await _odoo.call(_model, 'create', args: {
      'vals_list': [vals],
    });
    if (ids is! List || ids.isEmpty) throw const OdooException('Odoo did not return the new payment.');
    return ids.first as int;
  }

  @override
  Future<void> update(Txn t) async {
    await _odoo.call(_model, 'write', ids: [t.id], args: {'vals': await _values(t)});
  }

  @override
  Future<void> delete(int id) async {
    await _odoo.call(_model, 'unlink', ids: [id]);
  }

  Future<Map<String, Object?>> _values(Txn t) async => {
        'payment_type': t.isGot ? 'inbound' : 'outbound',
        'partner_type': 'customer',
        'partner_id': await _partnerId(t.person),
        'amount': t.amount,
        'date': isoDate(t.date),
        'memo': t.note,
      };

  /// Finds the partner with this name (case-insensitive), or creates one.
  Future<int> _partnerId(String name) async {
    final key = name.trim().toLowerCase();
    final known = _partnerIds[key];
    if (known != null) return known;
    final found = await _odoo.call('res.partner', 'search', args: {
      'domain': [
        ['name', '=ilike', name.trim()],
      ],
      'limit': 1,
    });
    int id;
    if (found is List && found.isNotEmpty) {
      id = found.first as int;
    } else {
      final created = await _odoo.call('res.partner', 'create', args: {
        'vals_list': [
          {'name': name.trim()},
        ],
      });
      if (created is! List || created.isEmpty) throw const OdooException('Odoo did not return the new contact.');
      id = created.first as int;
    }
    return _partnerIds[key] = id;
  }

  /// One `search_read` row → a transaction. Odoo sends `false` for empty fields.
  static Txn fromRecord(Map<String, dynamic> r) {
    final partner = r['partner_id'];
    final memo = r['memo'];
    return Txn(
      id: r['id'] as int,
      type: r['payment_type'] == 'inbound' ? 'got' : 'gave',
      amount: (r['amount'] as num).toDouble(),
      person: partner is List && partner.length > 1 ? partner[1] as String : 'Unknown',
      date: DateTime.parse(r['date'] as String),
      note: memo is String ? memo : '',
    );
  }
}
