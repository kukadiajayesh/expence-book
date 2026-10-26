import 'package:flutter/material.dart';

import 'shell.dart';
import 'store.dart';
import 'system_palette.dart';
import 'theme.dart';

/// Build with `--dart-define=LEDGER_DEMO=true` to start with sample data.
const demo = bool.fromEnvironment('LEDGER_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LedgerStore.load(demo: demo);
  final system = await fetchSystemPalette(timeout: const Duration(seconds: 1));
  runApp(LedgerApp(store: store, systemPalette: system));
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key, required this.store, this.systemPalette});

  final LedgerStore store;

  /// The wallpaper palette found at start-up, if the device has one.
  final Palette? systemPalette;

  @override
  Widget build(BuildContext context) {
    return SystemPalette(
      initial: systemPalette,
      builder: (context, system) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final palette = store.palette == systemPaletteKey && system != null ? system : paletteFor(store.palette);
        final colors = LedgerColors(palette, store.dark);
        return LedgerTheme(
          colors: colors,
          systemPalette: system,
          child: MaterialApp(
            title: 'Ledger',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Archivo',
              brightness: colors.dark ? Brightness.dark : Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: colors.accent, brightness: colors.dark ? Brightness.dark : Brightness.light, primary: colors.accent),
              scaffoldBackgroundColor: colors.bg,
              textSelectionTheme: TextSelectionThemeData(cursorColor: colors.accent, selectionColor: colors.accent.withValues(alpha: .3), selectionHandleColor: colors.accent),
            ),
            home: Shell(store: store),
          ),
        );
      },
    ),
    );
  }
}
