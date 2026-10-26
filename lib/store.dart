import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/odoo_client.dart';
import 'data/payment_api.dart';
import 'data/sync_queue.dart';
import 'models.dart';

const followOptions = ['3 days', '1 week', '2 weeks', '1 month', 'Never'];

/// Where the Odoo API key lives. The real one is the platform keystore.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeystoreSecrets implements SecretStore {
  const KeystoreSecrets();

  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

typedef GatewayFactory = PaymentGateway Function(OdooConfig config);

PaymentGateway _odooGateway(OdooConfig c) => PaymentApi(OdooClient(c));

enum SyncStatus {
  /// Not connected to Odoo; everything stays on this device.
  local,
  idle,
  syncing,
  offline,

  /// Odoo refused the API key.
  authFailed,
}

/// App data and preferences. Records are cached on the device with
/// shared_preferences. When connected to Odoo, changes are queued and sent
/// in the background, and the list is refreshed from Odoo after each sync.
class LedgerStore extends ChangeNotifier {
  LedgerStore._(this._prefs, this._secrets, this._gatewayFor);

  final SharedPreferences _prefs;
  final SecretStore _secrets;
  final GatewayFactory _gatewayFor;

  /// How long a change waits before it is sent, so Undo can still take it back.
  static const syncDelay = Duration(seconds: 5);

  List<Txn> records = [];
  SyncQueue queue = SyncQueue();
  bool loggedIn = false;
  OdooConfig? config;
  bool dark = false;
  String palette = 'terracotta';
  String follow = '1 week';
  bool daily = true, unsettled = true, faceId = false;

  PaymentGateway? _gateway;
  Timer? _syncTimer;
  Future<void>? _running;
  bool _syncAgain = false;
  int _nextLocalId = -1;

  SyncStatus status = SyncStatus.local;
  DateTime? lastSync;
  String? syncError;

  bool get connected => config != null;
  int get pendingCount => queue.length;
  int get failedCount => queue.ops.where((o) => o.error != null).length;

  static Future<LedgerStore> load({bool demo = false, SecretStore secrets = const KeystoreSecrets(), GatewayFactory gatewayFor = _odooGateway}) async {
    final p = await SharedPreferences.getInstance();
    final s = LedgerStore._(p, secrets, gatewayFor);
    final raw = p.getString('records');
    if (raw != null) {
      s.records = (jsonDecode(raw) as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    } else if (demo) {
      s.records = sampleTxns(DateTime.now());
    }
    final pending = p.getString('pending');
    if (pending != null) {
      s.queue = SyncQueue((jsonDecode(pending) as List).map((e) => PendingOp.fromJson(e as Map<String, dynamic>)));
    }
    s.loggedIn = p.getBool('loggedIn') ?? false;
    s.dark = p.getBool('dark') ?? false;
    s.palette = p.getString('palette') ?? 'terracotta';
    s.follow = p.getString('follow') ?? '1 week';
    s.daily = p.getBool('daily') ?? true;
    s.unsettled = p.getBool('unsettled') ?? true;
    s.faceId = p.getBool('faceId') ?? false;
    s._nextLocalId = s.records.fold<int>(0, (a, r) => r.id < a ? r.id : a) - 1;

    final url = p.getString('serverUrl'), db = p.getString('db');
    if (url != null && db != null) {
      String? key;
      try {
        key = await secrets.read('apiKey');
      } catch (_) {
        key = null; // keystore unavailable: ask to connect again
      }
      if (key != null && s.loggedIn) {
        s.config = OdooConfig(baseUrl: url, db: db, apiKey: key);
        s._gateway = gatewayFor(s.config!);
        s.status = SyncStatus.idle;
      } else {
        s.loggedIn = false;
      }
    }
    return s;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _save() {
    _prefs.setString('records', jsonEncode(records.map((r) => r.toJson()).toList()));
    _prefs.setString('pending', jsonEncode(queue.ops.map((o) => o.toJson()).toList()));
  }

  /// Newest first; ties broken by newest id.
  List<Txn> get sorted => [...records]..sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.id - a.id;
    });

  /// All records as CSV text, newest first.
  String toCsv() {
    String q(String v) => v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    return [
      'Date,Type,Person,Amount,Note',
      for (final r in sorted) [isoDate(r.date), r.isGot ? 'Received' : 'Paid', q(r.person), r.amount.toStringAsFixed(2), q(r.note)].join(','),
    ].join('\n');
  }

  void upsert({int? id, required String type, required double amount, required String person, required DateTime date, required String note}) {
    final rec = Txn(id: id ?? _nextLocalId--, type: type, amount: amount, person: person, date: date, note: note);
    records = id == null ? [rec, ...records] : [for (final r in records) r.id == id ? rec : r];
    if (connected) queue.upsert(rec);
    _changed();
  }

  /// Deletes a record and returns a callback that restores it.
  VoidCallback delete(int id) {
    final removed = records.where((r) => r.id == id).toList();
    records = records.where((r) => r.id != id).toList();
    final token = connected ? queue.delete(id) : null;
    _changed();
    return () {
      if (token == null || queue.undoDelete(token)) {
        records = [...records, ...removed];
      } else {
        // Odoo already deleted it, so it comes back as a new record.
        for (final r in removed) {
          final again = Txn(id: _nextLocalId--, type: r.type, amount: r.amount, person: r.person, date: r.date, note: r.note);
          records = [...records, again];
          queue.upsert(again);
        }
      }
      _changed();
    };
  }

  void _changed() {
    _save();
    notifyListeners();
    if (connected) {
      _syncTimer?.cancel();
      _syncTimer = Timer(syncDelay, sync);
    }
  }

  // ---- Odoo connection ----

  /// Checks the URL, database and key against Odoo, then starts syncing.
  /// Anything already on this device is uploaded. Throws [OdooException].
  Future<void> connect({required String url, required String db, required String apiKey}) async {
    final c = OdooConfig(baseUrl: OdooConfig.normaliseUrl(url), db: db.trim(), apiKey: apiKey.trim());
    final gateway = _gatewayFor(c);
    await gateway.check();

    await _secrets.write('apiKey', c.apiKey);
    await _prefs.setString('serverUrl', c.baseUrl);
    await _prefs.setString('db', c.db);
    config = c;
    _gateway = gateway;
    // Records made before connecting are new to Odoo.
    final local = records;
    records = [];
    queue = SyncQueue();
    for (final r in local.reversed) {
      final rec = Txn(id: _nextLocalId--, type: r.type, amount: r.amount, person: r.person, date: r.date, note: r.note);
      records = [rec, ...records];
      queue.upsert(rec);
    }
    loggedIn = true;
    status = SyncStatus.idle;
    syncError = null;
    _prefs.setBool('loggedIn', true);
    _save();
    notifyListeners();
    unawaited(sync());
  }

  /// Use the app without Odoo; data stays on this device.
  void useLocally() {
    loggedIn = true;
    _prefs.setBool('loggedIn', true);
    notifyListeners();
  }

  Future<void> logout() async {
    _syncTimer?.cancel();
    loggedIn = false;
    _prefs.setBool('loggedIn', false);
    if (connected) {
      // The cache belongs to that Odoo account.
      config = null;
      _gateway = null;
      records = [];
      queue = SyncQueue();
      status = SyncStatus.local;
      lastSync = null;
      syncError = null;
      _prefs.remove('serverUrl');
      _prefs.remove('db');
      _save();
      try {
        await _secrets.delete('apiKey');
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---- Sync ----

  /// Sends queued changes, then refreshes the list from Odoo. Safe to call
  /// at any time: a call during a sync waits for it (and asks for one more
  /// pass), and nothing happens when not connected.
  Future<void> sync() {
    if (_gateway == null) return Future.value();
    final running = _running;
    if (running != null) {
      _syncAgain = true; // changes arrived mid-sync; go round once more
      return running;
    }
    _syncTimer?.cancel();
    return _running = _syncLoop().whenComplete(() => _running = null);
  }

  Future<void> _syncLoop() async {
    do {
      _syncAgain = false;
      await _syncOnce(_gateway!);
    } while (_syncAgain && _gateway != null && status != SyncStatus.offline && status != SyncStatus.authFailed);
  }

  Future<void> _syncOnce(PaymentGateway g) async {
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      await _flush(g);
      await _pull(g);
      status = SyncStatus.idle;
      lastSync = DateTime.now();
      syncError = failedCount == 0 ? null : 'Some changes could not be saved in Odoo.';
    } on OdooException catch (e) {
      status = e.isAuth
          ? SyncStatus.authFailed
          : e.network
              ? SyncStatus.offline
              : SyncStatus.idle;
      syncError = e.message;
    } finally {
      _save();
      notifyListeners();
    }
  }

  Future<void> _flush(PaymentGateway g) async {
    for (final op in List.of(queue.ops)) {
      if (!identical(_gateway, g)) return; // logged out meanwhile
      if (!queue.ops.contains(op)) continue; // removed while we were away
      try {
        switch (op.kind) {
          case OpKind.create:
            op.inFlight = true;
            final newId = await g.create(op.txn!);
            if (!identical(_gateway, g)) return;
            records = [for (final r in records) r.id == op.id ? Txn(id: newId, type: r.type, amount: r.amount, person: r.person, date: r.date, note: r.note) : r];
            queue.remapId(op.id, newId);
            queue.remove(op);
          case OpKind.update:
            op.inFlight = true;
            await g.update(op.txn!);
            queue.remove(op);
          case OpKind.delete:
            if (op.id < 0) {
              // Its create never succeeded, so Odoo has nothing to delete.
              queue.ops.removeWhere((o) => o.id == op.id);
            } else {
              op.inFlight = true;
              await g.delete(op.id);
              queue.remove(op);
            }
        }
        _save();
      } on OdooException catch (e) {
        if (e.network || e.isAuth) rethrow;
        op.error = e.message; // keep it; the user sees a count and can retry
      } finally {
        op.inFlight = false;
      }
    }
  }

  Future<void> _pull(PaymentGateway g) async {
    final remote = await g.fetchAll();
    if (!identical(_gateway, g)) return;
    // Computed after the request, so edits made meanwhile are kept.
    final deleting = queue.idsWith(OpKind.delete).toSet();
    final editing = queue.idsWith(OpKind.update).toSet();
    final mine = {for (final r in records) r.id: r};
    records = [
      for (final r in remote)
        if (!deleting.contains(r.id)) editing.contains(r.id) ? (mine[r.id] ?? r) : r,
      for (final r in records)
        if (r.id < 0) r, // added here, not in Odoo yet
    ];
  }

  // ---- Preferences ----

  void setDark(bool v) {
    dark = v;
    _prefs.setBool('dark', v);
    notifyListeners();
  }

  void setPalette(String v) {
    palette = v;
    _prefs.setString('palette', v);
    notifyListeners();
  }

  void setFollow(String v) {
    follow = v;
    _prefs.setString('follow', v);
    notifyListeners();
  }

  void setSwitch(String key, bool v) {
    switch (key) {
      case 'daily':
        daily = v;
      case 'unsettled':
        unsettled = v;
      case 'faceId':
        faceId = v;
    }
    _prefs.setBool(key, v);
    notifyListeners();
  }
}
