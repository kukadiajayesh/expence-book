import 'package:flutter/material.dart';

import 'shell.dart';
import 'store.dart';
import 'theme.dart';

/// Build with `--dart-define=LEDGER_DEMO=true` to start with sample data.
const demo = bool.fromEnvironment('LEDGER_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LedgerStore.load(demo: demo);
  runApp(LedgerApp(store: store));
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key, required this.store});

  final LedgerStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final colors = LedgerColors(paletteFor(store.palette), store.dark);
        return LedgerTheme(
          colors: colors,
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
    );
  }
}
