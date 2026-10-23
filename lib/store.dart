import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const followOptions = ['3 days', '1 week', '2 weeks', '1 month', 'Never'];

/// App data and preferences, saved on the device with shared_preferences.
class LedgerStore extends ChangeNotifier {
  LedgerStore._(this._prefs);

  final SharedPreferences _prefs;

  List<Txn> records = [];
  bool loggedIn = false;
  String email = '';
  bool dark = false;
  String palette = 'terracotta';
  String follow = '1 week';
  bool daily = true, unsettled = true, faceId = false;
  int _nextId = 100;

  static Future<LedgerStore> load({bool demo = false}) async {
    final p = await SharedPreferences.getInstance();
    final s = LedgerStore._(p);
    final raw = p.getString('records');
    if (raw != null) {
      s.records = (jsonDecode(raw) as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    } else if (demo) {
      s.records = sampleTxns(DateTime.now());
    }
    s.loggedIn = p.getBool('loggedIn') ?? false;
    s.email = p.getString('email') ?? 'alex@ledger.app';
    s.dark = p.getBool('dark') ?? false;
    s.palette = p.getString('palette') ?? 'terracotta';
    s.follow = p.getString('follow') ?? '1 week';
    s.daily = p.getBool('daily') ?? true;
    s.unsettled = p.getBool('unsettled') ?? true;
    s.faceId = p.getBool('faceId') ?? false;
    s._nextId = s.records.fold<int>(100, (a, r) => r.id >= a ? r.id + 1 : a);
    return s;
  }

  void _saveRecords() => _prefs.setString('records', jsonEncode(records.map((r) => r.toJson()).toList()));

  /// Newest first; ties broken by newest id.
  List<Txn> get sorted => [...records]..sort((a, b) {
      final d = b.date.compareTo(a.date);
      return d != 0 ? d : b.id - a.id;
    });

  void upsert({int? id, required String type, required double amount, required String person, required DateTime date, required String note}) {
    final rec = Txn(id: id ?? _nextId++, type: type, amount: amount, person: person, date: date, note: note);
    records = id == null ? [rec, ...records] : [for (final r in records) r.id == id ? rec : r];
    _saveRecords();
    notifyListeners();
  }

  /// Deletes a record and returns a callback that restores it.
  VoidCallback delete(int id) {
    final old = records;
    records = records.where((r) => r.id != id).toList();
    _saveRecords();
    notifyListeners();
    return () {
      records = old;
      _saveRecords();
      notifyListeners();
    };
  }

  void login(String email) {
    this.email = email;
    loggedIn = true;
    _prefs.setString('email', email);
    _prefs.setBool('loggedIn', true);
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    _prefs.setBool('loggedIn', false);
    notifyListeners();
  }

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
