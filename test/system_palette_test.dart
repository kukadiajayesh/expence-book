// ignore_for_file: deprecated_member_use
import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/main.dart';
import 'package:ledger/store.dart';
import 'package:ledger/system_palette.dart';
import 'package:ledger/theme.dart';
import 'package:material_color_utilities/material_color_utilities.dart' show CorePalette;
import 'package:shared_preferences/shared_preferences.dart';

/// Pretends to be Android 12+ with a wallpaper whose key colour is [seed], or
/// an older phone when [seed] is null.
/// What the phone reports for a wallpaper, after the trip through the channel.
CorePalette phone(int seed) => CorePalette.fromList(CorePalette.of(seed).asList());

void setWallpaper(WidgetTester? t, int? seed) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    DynamicColorPlugin.channel,
    (call) async => call.method == 'getCorePalette' && seed != null ? Int32List.fromList(CorePalette.of(seed).asList()) : null,
  );
}

Future<LedgerStore> pump(WidgetTester t, {String palette = 'terracotta'}) async {
  SharedPreferences.setMockInitialValues({'loggedIn': true, 'palette': palette});
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = await LedgerStore.load();
  final system = await t.runAsync(fetchSystemPalette);
  await t.pumpWidget(LedgerApp(store: store, systemPalette: system));
  await t.pumpAndSettle();
  return store;
}

Color accentNow(WidgetTester t) => LedgerTheme.of(t.element(find.byType(Scaffold).evaluate().isNotEmpty ? find.byType(Scaffold).first : find.byType(Material).first)).accent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => setWallpaper(null, null));

  test('the palette follows the wallpaper tones', () async {
    setWallpaper(null, 0xFF2E7D32);
    final p = (await fetchSystemPalette())!;
    final core = phone(0xFF2E7D32);
    expect(p.key, systemPaletteKey);
    expect(p.accent.toARGB32(), core.primary.get(40));
    expect(p.accentD.toARGB32(), core.primary.get(80));
    expect(p.bg.toARGB32(), core.neutral.get(98));
    expect(p.bgD.toARGB32(), core.neutral.get(6));
  });

  test('older phones have no wallpaper palette', () async {
    setWallpaper(null, null);
    expect(await fetchSystemPalette(), isNull);
  });

  testWidgets('without wallpaper colours the picker has the four fixed themes', (t) async {
    final store = await pump(t, palette: 'system'); // saved choice that this phone cannot honour
    await t.tap(find.text('Settings').last);
    await t.pumpAndSettle();
    expect(find.text('Wallpaper'), findsNothing);
    expect(find.text('Terracotta'), findsWidgets); // falls back, not a crash
    expect(store.palette, 'system');
  });

  testWidgets('choosing Wallpaper recolours the app, and a new wallpaper follows on resume', (t) async {
    setWallpaper(t, 0xFF2E7D32); // green wallpaper
    final store = await pump(t);
    await t.tap(find.text('Settings').last);
    await t.pumpAndSettle();

    final fixed = accentNow(t);
    await t.scrollUntilVisible(find.text('Wallpaper'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Wallpaper'));
    await t.pumpAndSettle();
    expect(store.palette, systemPaletteKey);
    final green = phone(0xFF2E7D32).primary.get(40);
    expect(accentNow(t).toARGB32(), green);
    expect(accentNow(t), isNot(fixed));

    setWallpaper(t, 0xFFC2185B); // user picks a pink wallpaper, comes back to the app
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      t.binding.handleAppLifecycleStateChanged(state);
    }
    await t.pumpAndSettle();
    expect(accentNow(t).toARGB32(), phone(0xFFC2185B).primary.get(40));

    // Dark appearance uses the dark tone of the same wallpaper.
    store.setDark(true);
    await t.pumpAndSettle();
    expect(accentNow(t).toARGB32(), phone(0xFFC2185B).primary.get(80));
  });
}
