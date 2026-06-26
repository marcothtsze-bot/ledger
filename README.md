# Ledger

A personal finance / net-worth tracker for iOS (and Android + web), built in
Flutter from the `design_handoff_ledger_app` prototype. Dark, HKD-first, with a
keypad-driven transaction flow, accounts, activity search, insights, recurring &
installment tracking — all backed by **on-device storage** (no account, no
network, nothing leaves the phone).

> Standalone project. Not connected to any other system or data.

## Run it

```bash
# iOS (needs a Mac + Xcode)
flutter run -d ios

# Android
flutter run -d android

# Quick preview on this machine (no phone/simulator needed)
flutter run -d chrome          # or: flutter run -d web-server
```

On a wide screen the app centres a 393×812 phone mock so the design reads as
intended; on a real device it fills the screen.

## Verify

```bash
flutter analyze        # static analysis — clean
flutter test           # 40 tests: unit (logic) + widget (smoke) + sqlite
flutter build web      # full release compile
```

## Architecture

A thin Flutter/Riverpod shell over a **pure-Dart core**, so all the money and
business logic is framework-free and unit-tested.

```
lib/
├── core/            money + number formatting (pure Dart)
├── models/          immutable Account / Category / Txn / Recurring + enums
├── data/            LedgerRepository (interface)
│                    ├─ SqliteLedgerRepository   ← on-device persistence
│                    ├─ InMemoryLedgerRepository  ← tests / web preview / fallback
│                    └─ repository_factory*       ← picks impl per platform (web-safe)
├── state/           LedgerState (immutable, all logic) + Riverpod LedgerNotifier
├── theme/           design tokens (colour, type, radii, shadow, motion)
├── charts/          CustomPainter sparkline / area / donut (no chart lib)
├── view/            display-ready view models
├── widgets/         reusable UI (tiles, cards, keypad, tab bar, toast, …)
├── screens/         Home · Accounts · Activity · Insights
├── sheets/          Add Transaction (+ pickers) · Add Account
├── overlays/        Account Detail · Recurring
└── app.dart         shell: screen + tab bar + overlays/sheets/toast (z-ordered)
```

**Why colours are hex strings on the models:** it keeps the domain layer free of
any Flutter import, so `LedgerState` and the reducers are 100% unit-testable; the
UI resolves hex → `Color` via `theme/hex_color.dart`.

## Persistence

The on-device store is SQLite (`sqflite` on mobile, the FFI engine on
desktop/tests). State is small, so each change writes a fresh snapshot inside one
transaction. The repository is behind an interface, so swapping in cloud sync
later is a drop-in. The web preview build runs on seeded in-memory data (the app
targets iOS first).

## Notes / future polish

- **Fonts**: Hanken Grotesk (UI) + IBM Plex Mono (money) load via `google_fonts`
  at runtime today; bundling them as assets would remove the first-launch fetch.
- **Sheets/overlays** animate on entry; exit is instant (scrim fade covers it).
- A few header figures ("▲ 2.1% · +HK$9,840 since May", the cash-flow bars, the
  spending donut sample) are illustrative per the design — wire them to real
  history when a charting data source exists.
- `'Today · Jun 21'` day labels come from the prototype; swap for real dates.
