import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledger/data/odoo_client.dart';
import 'package:ledger/data/payment_api.dart';
import 'package:ledger/data/sync_queue.dart';
import 'package:ledger/models.dart';
import 'package:ledger/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const cfg = OdooConfig(baseUrl: 'https://odoo.test', db: 'prod', apiKey: 'k123');

Txn txn(int id, {String type = 'gave', double amount = 100, String person = 'Ravi', String note = ''}) =>
    Txn(id: id, type: type, amount: amount, person: person, date: DateTime(2026, 10, 23), note: note);

/// An in-memory server for store tests.
class FakeGateway implements PaymentGateway {
  final server = <int, Txn>{};
  int next = 1000;
  bool offline = false;
  bool rejectCreate = false;
  int calls = 0;

  void _gate() {
    calls++;
    if (offline) throw const OdooException('no network', network: true);
  }

  @override
  Future<void> check() async => _gate();

  @override
  Future<List<Txn>> fetchAll() async {
    _gate();
    return server.values.toList();
  }

  @override
  Future<int> create(Txn t) async {
    _gate();
    if (rejectCreate) throw const OdooException('Invalid field', status: 400);
    final id = next++;
    server[id] = Txn(id: id, type: t.type, amount: t.amount, person: t.person, date: t.date, note: t.note);
    return id;
  }

  @override
  Future<void> update(Txn t) async {
    _gate();
    server[t.id] = t;
  }

  @override
  Future<void> delete(int id) async {
    _gate();
    server.remove(id);
  }
}

class MemorySecrets implements SecretStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
  @override
  Future<void> delete(String key) async => m.remove(key);
}

Future<(LedgerStore, FakeGateway)> connectedStore({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final g = FakeGateway();
  final s = await LedgerStore.load(secrets: MemorySecrets(), gatewayFor: (_) => g);
  await s.connect(url: 'odoo.test', db: 'prod', apiKey: 'k');
  return (s, g);
}

void main() {
  group('OdooClient', () {
    test('posts JSON-2 requests with bearer key and database', () async {
      late http.Request seen;
      final client = OdooClient(cfg, client: MockClient((req) async {
        seen = req;
        return http.Response('[7]', 200);
      }));
      final out = await client.call('account.payment', 'write', ids: [5], args: {'vals': {'amount': 3}});
      expect(out, [7]);
      expect(seen.url.toString(), 'https://odoo.test/json/2/account.payment/write');
      expect(seen.headers['Authorization'], 'bearer k123');
      expect(seen.headers['X-Odoo-Database'], 'prod');
      expect(jsonDecode(seen.body), {
        'ids': [5],
        'vals': {'amount': 3},
      });
    });

    test('maps HTTP errors and unreachable servers', () async {
      OdooClient with_(http.Response Function() r) => OdooClient(cfg, client: MockClient((_) async => r()));
      await expectLater(
        with_(() => http.Response('', 401)).call('res.partner', 'search_count'),
        throwsA(isA<OdooException>().having((e) => e.isAuth, 'isAuth', true)),
      );
      await expectLater(
        with_(() => http.Response(jsonEncode({'message': 'Invalid field amount'}), 422)).call('x', 'y'),
        throwsA(isA<OdooException>().having((e) => e.message, 'message', 'Invalid field amount')),
      );
      await expectLater(
        with_(() => http.Response('<html>', 200)).call('x', 'y'),
        throwsA(isA<OdooException>().having((e) => e.network, 'network', false)),
      );
      final down = OdooClient(cfg, client: MockClient((_) async => throw http.ClientException('nope')));
      await expectLater(down.call('x', 'y'), throwsA(isA<OdooException>().having((e) => e.network, 'network', true)));
    });

    test('normalises the server address', () {
      expect(OdooConfig.normaliseUrl('odoo.example.com/'), 'https://odoo.example.com');
      expect(OdooConfig.normaliseUrl(' http://10.0.0.2:8069// '), 'http://10.0.0.2:8069');
    });
  });

  group('PaymentApi', () {
    test('reads payments into transactions', () {
      final t = PaymentApi.fromRecord({'id': 9, 'payment_type': 'inbound', 'partner_id': [3, 'Meera Iyer'], 'amount': 1500.0, 'date': '2026-10-14', 'memo': false});
      expect(t.id, 9);
      expect(t.isGot, isTrue);
      expect(t.person, 'Meera Iyer');
      expect(t.note, '');
      expect(PaymentApi.fromRecord({'id': 1, 'payment_type': 'outbound', 'partner_id': [3, 'A'], 'amount': 5, 'date': '2026-10-14', 'memo': 'Cab'}).note, 'Cab');
    });

    test('creating finds or creates the partner once and sends the right values', () async {
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final api = PaymentApi(OdooClient(cfg, client: MockClient((req) async {
        calls.add(req.url.path);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return switch (req.url.path) {
          '/json/2/res.partner/search' => http.Response('[]', 200),
          '/json/2/res.partner/create' => http.Response('[42]', 200),
          '/json/2/account.payment/create' => http.Response('[900]', 200),
          _ => http.Response('{}', 404),
        };
      })));
      expect(await api.create(txn(-1, type: 'got', amount: 1250.5, person: 'Zoya', note: 'Lunch')), 900);
      await api.create(txn(-2, person: 'zoya'));
      expect(calls.where((c) => c == '/json/2/res.partner/create'), hasLength(1)); // cached, case-insensitive
      final vals = (bodies.firstWhere((b) => b.containsKey('vals_list') && (b['vals_list'] as List).first.containsKey('amount'))['vals_list'] as List).first as Map;
      expect(vals, {'payment_type': 'inbound', 'partner_type': 'customer', 'partner_id': 42, 'amount': 1250.5, 'date': '2026-10-23', 'memo': 'Lunch'});
    });
  });

  group('SyncQueue', () {
    test('edits to an unsent add stay one create', () {
      final q = SyncQueue()
        ..upsert(txn(-1))
        ..upsert(txn(-1, amount: 250));
      expect(q.length, 1);
      expect(q.ops.single.kind, OpKind.create);
      expect(q.ops.single.txn!.amount, 250);
    });

    test('deleting an unsent add forgets it, and undo brings it back', () {
      final q = SyncQueue()..upsert(txn(-1));
      final token = q.delete(-1);
      expect(q.isEmpty, isTrue);
      expect(q.undoDelete(token), isTrue);
      expect(q.ops.single.kind, OpKind.create);
    });

    test('an edited synced record sends one update, then a delete replaces it', () {
      final q = SyncQueue()
        ..upsert(txn(7))
        ..upsert(txn(7, amount: 1));
      expect(q.ops.map((o) => o.kind), [OpKind.update]);
      final token = q.delete(7);
      expect(q.ops.map((o) => o.kind), [OpKind.delete]);
      expect(q.undoDelete(token), isTrue);
      expect(q.ops.map((o) => o.kind), [OpKind.update]);
    });

    test('undo reports failure once the delete was sent', () {
      final q = SyncQueue();
      final token = q.delete(7);
      q.remove(q.ops.single); // sent
      expect(q.undoDelete(token), isFalse);
    });

    test('a request in flight is never edited', () {
      final q = SyncQueue()..upsert(txn(-1));
      q.ops.single.inFlight = true;
      q.upsert(txn(-1, amount: 9));
      expect(q.length, 2);
      q.remapId(-1, 55);
      expect(q.ops.map((o) => o.id), [55, 55]);
      expect(q.ops.last.txn!.id, 55);
    });

    test('survives a round trip through JSON', () {
      final q = SyncQueue()
        ..upsert(txn(-1, note: 'a'))
        ..delete(8);
      final back = SyncQueue(q.ops.map((o) => PendingOp.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>)));
      expect(back.ops.map((o) => (o.kind, o.id)), [(OpKind.create, -1), (OpKind.delete, 8)]);
    });
  });

  group('LedgerStore with Odoo', () {
    test('connecting uploads what was already on the device', () async {
      SharedPreferences.setMockInitialValues({});
      final g = FakeGateway();
      final s = await LedgerStore.load(demo: true, secrets: MemorySecrets(), gatewayFor: (_) => g);
      expect(s.records, hasLength(12));
      await s.connect(url: 'odoo.test', db: 'prod', apiKey: 'k');
      await s.sync();
      expect(g.server, hasLength(12));
      expect(s.records, hasLength(12));
      expect(s.records.every((r) => r.id >= 1000), isTrue);
      expect(s.pendingCount, 0);
      expect(s.status, SyncStatus.idle);
    });

    test('add, edit and delete reach the server', () async {
      final (s, g) = await connectedStore();
      s.upsert(type: 'gave', amount: 320, person: 'Ankit', date: DateTime(2026, 10, 23), note: 'Lunch');
      expect(s.pendingCount, 1);
      await s.sync();
      final id = s.records.single.id;
      expect(g.server[id]!.amount, 320);

      s.upsert(id: id, type: 'gave', amount: 350, person: 'Ankit', date: DateTime(2026, 10, 23), note: 'Lunch');
      await s.sync();
      expect(g.server[id]!.amount, 350);

      s.delete(id);
      await s.sync();
      expect(g.server, isEmpty);
      expect(s.records, isEmpty);
    });

    test('offline changes wait and go out once the network is back', () async {
      final (s, g) = await connectedStore();
      g.offline = true;
      s.upsert(type: 'got', amount: 500, person: 'Priya', date: DateTime(2026, 10, 22), note: '');
      await s.sync();
      expect(s.status, SyncStatus.offline);
      expect(s.pendingCount, 1);
      expect(s.records, hasLength(1)); // still visible

      g.offline = false;
      await s.sync();
      expect(s.status, SyncStatus.idle);
      expect(s.pendingCount, 0);
      expect(g.server.values.single.person, 'Priya');
    });

    test('the pending queue survives a restart', () async {
      final (s, g) = await connectedStore();
      g.offline = true;
      s.upsert(type: 'got', amount: 500, person: 'Priya', date: DateTime(2026, 10, 22), note: '');
      final again = await LedgerStore.load(secrets: MemorySecrets()..m['apiKey'] = 'k', gatewayFor: (_) => g);
      expect(again.connected, isTrue);
      expect(again.pendingCount, 1);
      g.offline = false;
      await again.sync();
      expect(g.server, hasLength(1));
    });

    test('undo before the delete is sent leaves the server untouched', () async {
      final (s, g) = await connectedStore();
      s.upsert(type: 'gave', amount: 1, person: 'A', date: DateTime(2026, 10, 23), note: '');
      await s.sync();
      final id = s.records.single.id;
      final undo = s.delete(id);
      undo();
      await s.sync();
      expect(g.server, hasLength(1));
      expect(s.records.single.id, id);
    });

    test('undo after the delete was sent re-creates the record', () async {
      final (s, g) = await connectedStore();
      s.upsert(type: 'gave', amount: 1, person: 'A', date: DateTime(2026, 10, 23), note: '');
      await s.sync();
      final undo = s.delete(s.records.single.id);
      await s.sync();
      expect(g.server, isEmpty);
      undo();
      await s.sync();
      expect(g.server, hasLength(1));
      expect(s.records, hasLength(1));
    });

    test('a change Odoo rejects stays queued and is counted, without blocking the rest', () async {
      final (s, g) = await connectedStore();
      g.rejectCreate = true;
      s.upsert(type: 'gave', amount: 1, person: 'A', date: DateTime(2026, 10, 23), note: '');
      await s.sync();
      expect(s.failedCount, 1);
      expect(s.status, SyncStatus.idle);
      expect(s.records, hasLength(1));
      g.rejectCreate = false;
      await s.sync();
      expect(s.failedCount, 0);
      expect(g.server, hasLength(1));
    });

    test('server changes appear, but local unsent edits win', () async {
      final (s, g) = await connectedStore();
      g.server[1] = txn(1, person: 'Remote', amount: 10);
      g.server[2] = txn(2, person: 'Edited', amount: 20);
      await s.sync();
      expect(s.records.map((r) => r.id).toSet(), {1, 2});
      g.offline = true;
      s.upsert(id: 2, type: 'gave', amount: 99, person: 'Edited', date: DateTime(2026, 10, 23), note: '');
      g.offline = false;
      g.server.remove(1); // deleted in Odoo
      await s.sync();
      expect(s.records.map((r) => r.id), [2]);
      expect(g.server[2]!.amount, 99);
    });

    test('a bad key is reported and keeps the data', () async {
      final (s, g) = await connectedStore();
      s.upsert(type: 'gave', amount: 1, person: 'A', date: DateTime(2026, 10, 23), note: '');
      g.offline = false;
      final bad = _AuthFailGateway();
      final again = await LedgerStore.load(secrets: MemorySecrets()..m['apiKey'] = 'k', gatewayFor: (_) => bad);
      await again.sync();
      expect(again.status, SyncStatus.authFailed);
      expect(again.pendingCount, 1);
      expect(again.records, hasLength(1));
    });

    test('logging out during a sync does not bring the data back', () async {
      final (s, g) = await connectedStore();
      g.server[1] = txn(1);
      final running = s.sync();
      await s.logout();
      await running;
      expect(s.records, isEmpty);
    });

    test('logging out of Odoo clears the cache and the key', () async {
      final secrets = MemorySecrets();
      SharedPreferences.setMockInitialValues({});
      final g = FakeGateway();
      final s = await LedgerStore.load(secrets: secrets, gatewayFor: (_) => g);
      await s.connect(url: 'odoo.test', db: 'prod', apiKey: 'k');
      s.upsert(type: 'gave', amount: 1, person: 'A', date: DateTime(2026, 10, 23), note: '');
      await s.logout();
      expect(s.loggedIn, isFalse);
      expect(s.connected, isFalse);
      expect(s.records, isEmpty);
      expect(secrets.m, isEmpty);
    });
  });
}

class _AuthFailGateway extends FakeGateway {
  @override
  Future<List<Txn>> fetchAll() async => throw const OdooException('The API key was rejected.', status: 401);
  @override
  Future<int> create(Txn t) async => throw const OdooException('The API key was rejected.', status: 401);
}
