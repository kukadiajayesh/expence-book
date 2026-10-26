import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/main.dart';
import 'package:ledger/models.dart';
import 'package:ledger/screens/settings.dart' show SettingsScreen;
import 'package:ledger/store.dart';
import 'package:ledger/theme.dart';
import 'package:ledger/widgets/common.dart' show LedgerSwitch;
import 'package:shared_preferences/shared_preferences.dart';

Future<LedgerStore> pumpApp(WidgetTester t, {Map<String, Object> prefs = const {}, bool demo = false}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = await LedgerStore.load(demo: demo);
  await t.pumpWidget(LedgerApp(store: store));
  await t.pumpAndSettle();
  return store;
}

void main() {
  group('formatting', () {
    test('Indian digit grouping', () {
      expect(fmt(0), '₹0');
      expect(fmt(450), '₹450');
      expect(fmt(4200), '₹4,200');
      expect(fmt(100000), '₹1,00,000');
      expect(fmt(12345678), '₹1,23,45,678');
      expect(fmt(1250.5), '₹1,250.50');
      expect(fmt(-320), '₹320');
    });

    test('signed amounts use a true minus sign', () {
      expect(signedFmt(1880), '+₹1,880');
      expect(signedFmt(-450), '−₹450');
    });

    test('initials and day labels', () {
      expect(initials('Ravi Kumar'), 'RK');
      expect(initials('meera'), 'M');
      final today = DateTime(2026, 10, 23);
      expect(dayLabel(DateTime(2026, 10, 23), today), 'Today');
      expect(dayLabel(DateTime(2026, 10, 22), today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 10, 19), today), 'Mon, Oct 19');
    });
  });

  group('colour', () {
    test('mix matches CSS color-mix in srgb', () {
      final m = mix(const Color(0xFFFF0000), 25, const Color(0xFFFFFFFF));
      expect((m.r * 255).round(), 255);
      expect((m.g * 255).round(), 191);
      final t = mix(const Color(0xFF4A3333), 30, const Color(0x00000000));
      expect(t.a, closeTo(.3, 1e-9));
      expect(t.r, const Color(0xFF4A3333).r);
    });

    test('oklch white and black', () {
      expect(oklch(1, 0, 0).toARGB32(), 0xFFFFFFFF);
      expect(oklch(0, 0, 0).toARGB32(), 0xFF000000);
    });
  });

  group('store', () {
    test('upsert, delete and undo persist', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await LedgerStore.load();
      s.upsert(type: 'gave', amount: 320, person: 'Ankit Verma', date: DateTime(2026, 10, 23), note: 'Lunch');
      expect(s.records, hasLength(1));
      final again = await LedgerStore.load();
      expect(again.records.single.person, 'Ankit Verma');
      final undo = s.delete(s.records.single.id);
      expect(s.records, isEmpty);
      undo();
      expect(s.records, hasLength(1));
    });
  });

  testWidgets('sign in, add a transaction, see it on Overview', (t) async {
    await pumpApp(t);
    expect(find.text('Connect to Odoo'), findsOneWidget);
    await t.tap(find.text('Use without Odoo'));
    await t.pumpAndSettle();
    expect(find.text('Start your ledger'), findsOneWidget);

    await t.tap(find.text('Add first transaction'));
    await t.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);

    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(find.text('Add who this was with.'), findsOneWidget);

    await t.tap(find.text('Received').last);
    await t.pump();
    expect(find.text('Received from'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, '0'), '1500');
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Meera Iyer');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(find.text('Transaction added'), findsOneWidget);
    expect(find.text('Meera Iyer'), findsNWidgets(2)); // People + Recent
    expect(find.text('+₹1,500'), findsNWidgets(2));
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('edit, delete with confirmation, then undo', (t) async {
    await pumpApp(t, prefs: {'loggedIn': true}, demo: true);
    await t.tap(find.text('Records').last);
    await t.pumpAndSettle();
    expect(find.text('12 transactions'), findsOneWidget);

    await t.tap(find.text('Lunch'));
    await t.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    await t.ensureVisible(find.text('Delete transaction'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete transaction'));
    await t.pumpAndSettle();
    expect(find.text('Delete this transaction?'), findsOneWidget);
    expect(find.text('Paid to Ankit Verma · ₹320 will be removed.'), findsOneWidget);

    await t.tap(find.text('Delete transaction').last);
    await t.pumpAndSettle();
    expect(find.text('11 transactions'), findsOneWidget);
    expect(find.text('Transaction deleted'), findsOneWidget);

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.text('12 transactions'), findsOneWidget);
  });

  testWidgets('person filter from Overview, then clear it', (t) async {
    await pumpApp(t, prefs: {'loggedIn': true}, demo: true);
    await t.tap(find.text('Ravi Kumar').first);
    await t.pumpAndSettle();
    expect(find.text('4 transactions'), findsOneWidget);
    await t.tap(find.text('Paid').first);
    await t.pumpAndSettle();
    expect(find.text('1 transaction'), findsOneWidget);
    await t.tap(find.text('Ravi Kumar').first); // the filter chip
    await t.pumpAndSettle();
    expect(find.text('6 transactions'), findsOneWidget); // all paid
  });

  testWidgets('dark appearance, colour theme and log out', (t) async {
    final store = await pumpApp(t, prefs: {'loggedIn': true});
    await t.tap(find.text('Settings').last);
    await t.pumpAndSettle();

    await t.tap(find.byType(LedgerSwitch).first); // Dark appearance
    await t.pumpAndSettle();
    expect(store.dark, isTrue);

    final list = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Forest'), 200, scrollable: list);
    await t.tap(find.text('Forest'));
    await t.pumpAndSettle();
    expect(store.palette, 'forest');

    await t.scrollUntilVisible(find.text('Log out'), 200, scrollable: list);
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    expect(find.text('Log out of Ledger?'), findsOneWidget);
    await t.tap(find.text('Log out').last);
    await t.pumpAndSettle();
    expect(find.text('Connect to Odoo'), findsOneWidget);
    expect(store.loggedIn, isFalse);
  });
}
