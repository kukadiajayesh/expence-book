# Ledger

A Flutter app for tracking money paid to and received from people, in ₹ only. It is built from the Claude Design handoff "Ledger Final v3".

## Features

- **Connect to Odoo.** Enter the server address, database and an API key. The app checks them before it lets you in. "Use without Odoo" keeps everything on the device. Log out asks for confirmation first, and warns if changes have not been sent yet.
- **Overview.** A "Net this month" card with received and paid totals and an up/down/flat trend, a list of people with their running balances, and recent transactions. A new install shows an empty state instead.
- **Records.** Transactions grouped by day, with a net figure per day. You can filter by All, Received or Paid, or by one person (tap a person on Overview). Empty and no-match states are included.
- **Add and edit.** A full-height spring sheet that pushes the app back as it opens. Fields are Paid/Received, amount, person (with quick-pick chips), date and note. Editing adds a delete option, which asks for confirmation and gives you an Undo toast.
- **Settings.** Follow-up period (a sheet with two heights), dark appearance, four colour themes (Terracotta, Midnight, Forest, Graphite), notification and Face ID switches, and Export (shown but not yet working).
- **Spring sheets.** You can drag, flick or grab a sheet mid-animation. Scrolling inside a sheet hands off to dragging the sheet at the top edge. Android back and Esc close the top sheet. Reduce Motion gives a firmer spring.

## Odoo

The app talks to **Odoo 19** through its JSON-2 external API (`POST /json/2/<model>/<method>`, bearer API key). Each transaction is an `account.payment`: *received* is an inbound payment and *paid* is an outbound one, the person is a `res.partner` (found by name or created), and the note is the payment `memo`. Payments are created in draft, so the app can still edit and delete them.

Records are cached on the device with `shared_preferences` and the API key is kept in the platform keystore (`flutter_secure_storage`). Changes are queued and sent about 5 seconds later, so Undo still works. If the phone is offline they wait in the queue, survive a restart, and go out on the next sync. The app syncs on launch, when it returns to the foreground and from **Settings → Odoo sync**. After each sync the list is refreshed from Odoo; changes still waiting on the device win over the server's copy. A change Odoo rejects stays in the queue and is counted as failed.

Create a key in Odoo under *Preferences → Account Security → New API Key*. Debug and profile builds allow plain `http://` so you can test against a local server; release builds need `https://`.

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
| `lib/store.dart` | `LedgerStore`: records and preferences, the Odoo connection and the sync loop |
| `lib/data/odoo_client.dart` | JSON-2 HTTP client and error types |
| `lib/data/payment_api.dart` | `account.payment` / `res.partner` mapping behind `PaymentGateway` |
| `lib/data/sync_queue.dart` | Pending changes, merged so each record sends at most one request |
| `lib/shell.dart` | Nav bar, tab bar, toast and the three sheets |
| `lib/screens/` | Login, Overview, Records, Settings, and the sheet contents |
| `lib/widgets/spring_sheet.dart` | Spring-driven sheet controller and drag/scroll hand-off |
| `lib/widgets/net_card.dart` | Dot-grid money card |

The font is Archivo (SIL OFL, `assets/fonts/OFL.txt`).
