# Ledger

A Flutter app for tracking money paid to and received from people, in ₹ only. It is built from the Claude Design handoff "Ledger Final v3".

## Features

- **Sign in.** This is a local gate: any valid email and a password of 4+ characters work. Log out asks for confirmation first.
- **Overview.** A "Net this month" card with received and paid totals and an up/down/flat trend, a list of people with their running balances, and recent transactions. A new install shows an empty state instead.
- **Records.** Transactions grouped by day, with a net figure per day. You can filter by All, Received or Paid, or by one person (tap a person on Overview). Empty and no-match states are included.
- **Add and edit.** A full-height spring sheet that pushes the app back as it opens. Fields are Paid/Received, amount, person (with quick-pick chips), date and note. Editing adds a delete option, which asks for confirmation and gives you an Undo toast.
- **Settings.** Follow-up period (a sheet with two heights), dark appearance, four colour themes (Terracotta, Midnight, Forest, Graphite), notification and Face ID switches, and Export (shown but not yet working).
- **Spring sheets.** You can drag, flick or grab a sheet mid-animation. Scrolling inside a sheet hands off to dragging the sheet at the top edge. Android back and Esc close the top sheet. Reduce Motion gives a firmer spring.

Everything is stored on the device with `shared_preferences`. There is no backend.

## Run

```sh
flutter pub get
flutter run                               # starts empty
flutter run --dart-define=LEDGER_DEMO=true  # starts with the design's sample data
flutter test
```

## Layout

| Path | What |
| --- | --- |
| `lib/theme.dart` | Palettes and colour tokens (a port of the design's `buildTheme`, including CSS `color-mix` and `oklch`), plus the Archivo text helper |
| `lib/models.dart` | `Txn`, ₹ formatting with Indian grouping, date labels, sample data |
| `lib/store.dart` | `LedgerStore`: records and preferences, saved to the device |
| `lib/shell.dart` | Nav bar, tab bar, toast and the three sheets |
| `lib/screens/` | Login, Overview, Records, Settings, and the sheet contents |
| `lib/widgets/spring_sheet.dart` | Spring-driven sheet controller and drag/scroll hand-off |
| `lib/widgets/net_card.dart` | Dot-grid money card |

The font is Archivo (SIL OFL, `assets/fonts/OFL.txt`).
