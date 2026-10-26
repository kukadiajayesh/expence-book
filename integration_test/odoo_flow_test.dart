// Runs the real app on a device or simulator against a stand-in Odoo server.
//
//   python3 fake_odoo.py &            # JSON-2 stub on :8069 (key "demo-key", db "ledgerdb")
//   flutter test integration_test -d <device> --dart-define=ODOO_URL=http://127.0.0.1:8069
//
// On an Android phone pass your computer's LAN address instead of 127.0.0.1.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger/main.dart';
import 'package:ledger/store.dart';
import 'package:ledger/system_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

const url = String.fromEnvironment('ODOO_URL', defaultValue: 'http://127.0.0.1:8069');

Future<Map<String, dynamic>> serverState() async {
  final c = HttpClient();
  try {
    final res = await (await c.getUrl(Uri.parse(url))).close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  } finally {
    c.close();
  }
}

Future<void> until(WidgetTester t, bool Function() ok, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 4 && !ok(); i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
  expect(ok(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, sync, keep the key in the keychain, log out', (t) async {
    // Start from a clean install.
    await (await SharedPreferences.getInstance()).clear();
    await const KeystoreSecrets().delete('apiKey');

    var store = await LedgerStore.load();
    expect(store.connected, isFalse);
    await t.pumpWidget(LedgerApp(store: store, systemPalette: await fetchSystemPalette()));
    await t.pumpAndSettle();
    expect(find.text('Connect to Odoo'), findsOneWidget);

    Future<void> fill(String key) async {
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), url);
      await t.enterText(fields.at(1), 'ledgerdb');
      await t.enterText(fields.at(2), key);
      await t.pump();
      await t.tap(find.text('Connect'));
      await t.pump();
    }

    // A wrong key is refused with Odoo's message.
    await fill('wrong');
    await until(t, () => find.text('Invalid apikey').evaluate().isNotEmpty);
    expect(store.connected, isFalse);

    // The right key connects and lands on Overview.
    await fill('demo-key');
    await until(t, () => store.connected && store.status == SyncStatus.idle);
    await t.pumpAndSettle();
    expect(find.text('Overview'), findsWidgets);
    expect(store.records, isNotEmpty); // the stub's seeded payments came down

    // Adding a record reaches Odoo.
    store.upsert(type: 'got', amount: 4321, person: 'Keychain Test', date: DateTime.now(), note: 'ios');
    await store.sync();
    final payments = (await serverState())['payments'] as Map<String, dynamic>;
    expect(payments.values.any((p) => (p as Map)['amount'] == 4321.0), isTrue);
    expect(store.pendingCount, 0);

    // The API key survived in the iOS keychain: a fresh load is still connected.
    final again = await LedgerStore.load();
    expect(again.connected, isTrue);
    expect(again.config!.apiKey, 'demo-key');

    // iOS has no wallpaper palette, so only the four fixed themes are offered.
    expect(await fetchSystemPalette(), isNull);

    // Logging out removes the key.
    await store.logout();
    await t.pumpAndSettle();
    expect(find.text('Connect to Odoo'), findsOneWidget);
    expect((await LedgerStore.load()).connected, isFalse);
    expect(await const KeystoreSecrets().read('apiKey'), isNull);
  });
}
