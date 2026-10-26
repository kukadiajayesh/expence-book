# Ledger (Kotlin Multiplatform)

A native Android and iOS port of the Flutter app in the repo root, built with **Kotlin Multiplatform** and **Compose Multiplatform**. The UI, the data layer and the Odoo sync are shared Kotlin; each platform has a thin app shell.

It does the same job as the Flutter app: track money paid to and received from people, saved in **Odoo 19** through its JSON-2 API, with an offline cache and a queue for changes made while offline. See the root README for how the Odoo mapping works (`account.payment` ↔ transaction).

## Layout

| Path | What |
| --- | --- |
| `shared/` | All the app code, as a KMP library for Android and iOS |
| `shared/src/commonMain/.../model` | `Txn`, ₹ formatting with Indian grouping, date labels, sample data |
| `shared/src/commonMain/.../data` | `OdooClient` (Ktor), `PaymentApi` (`account.payment` mapping behind `PaymentGateway`), `SyncQueue` |
| `shared/src/commonMain/.../store` | `LedgerStore`: records, preferences, the Odoo connection and the sync loop |
| `shared/src/commonMain/.../ui` | Compose UI: theme and palettes, widgets, spring sheets, and the Overview, Records, Settings and Connect screens |
| `shared/src/commonMain/.../platform` | `expect` declarations for what differs per platform |
| `shared/src/androidMain`, `iosMain` | Android Keystore / iOS Keychain for the API key, clipboard, back button, wallpaper colours (Android 12+) |
| `androidApp/` | The Android app: `MainActivity` and the manifest |
| `iosApp/` | The iOS app: a SwiftUI shell that hosts the shared Compose UI |

## Build and run

Needs JDK 17+ (21 works), the Android SDK (compile SDK 37), and Xcode for iOS.

```sh
./gradlew :androidApp:assembleDebug        # Android APK -> androidApp/build/outputs/apk/debug
./gradlew :androidApp:installDebug         # install on a connected device
./gradlew :shared:testAndroidHostTest      # shared tests on the JVM
./gradlew :shared:iosSimulatorArm64Test    # the same tests on an iOS simulator
```

For iOS, open `iosApp/iosApp.xcodeproj` in Xcode and run the **Ledger** scheme on a simulator or device. A build phase runs `./gradlew :shared:embedAndSignAppleFrameworkForXcode` to compile the Kotlin framework first. From the command line:

```sh
xcodebuild -project iosApp/iosApp.xcodeproj -scheme Ledger -configuration Debug \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath iosApp/build CODE_SIGN_IDENTITY="-" build
```

The app must be code-signed, even for the simulator (ad-hoc signing with `CODE_SIGN_IDENTITY="-"` is enough), because the iOS Keychain refuses unsigned apps and the API key is stored there. Xcode's own automatic signing handles this. For a physical iPhone, set your signing team on the **Ledger** target.

### Sample data

- Android: `adb shell am start -n app.ledger.kmp/.MainActivity --ez demo true`, then tap **Use without Odoo**.
- iOS: launch with `LEDGER_DEMO=true`, for example `SIMCTL_CHILD_LEDGER_DEMO=true xcrun simctl launch booted app.ledger.kmp`.

Sample data only loads while nothing has been saved yet.

### Connect to Odoo without typing (for testing)

- Android: add `--es url http://192.168.1.5:8069 --es db mydb --es key MYKEY` to the `am start` command above.
- iOS: set `LEDGER_ODOO_URL`, `LEDGER_ODOO_DB` and `LEDGER_ODOO_KEY` (with `simctl`, prefix each with `SIMCTL_CHILD_`).

The app only connects this way when it isn't connected already.

## Notes

- Debug builds allow plain `http://` so you can test against a local Odoo; release builds need `https://`. On iOS, local-network addresses are allowed in `Info.plist`.
- **Wallpaper** colour theme (Material You) appears in Settings only on Android 12+.
- The API key is stored encrypted with an Android Keystore key, or in the iOS Keychain. If the key is missing (restored backup, new phone) the app asks you to connect again.
- Versions are in `gradle/libs.versions.toml`. Kotlin 2.4, Compose Multiplatform 1.12, AGP 9.1.
