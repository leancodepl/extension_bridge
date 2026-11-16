# extension_bridge example

A demo of everything `extension_bridge` connects, plus the integration tests CI
runs on every platform. Each demo page explains how to try it, has a live
panel, and shows the Dart and Swift code behind it (with the full sources a
tap away).

| Demo | iOS pieces |
| --- | --- |
| Home screen widgets | `ios/Widgets/CounterWidget.swift` – interactive counter, Lock Screen and StandBy |
| Flutter-painted widget | `ios/Widgets/ArtWidget.swift` – shows PNGs Flutter rendered into `bridge.files` |
| SwiftUI chart widget | `ios/Widgets/ChartWidget.swift` – Swift Charts drawing JSON Flutter wrote with `setJson` |
| Live Activities | `ios/Widgets/OrderLiveActivity.swift`, `ios/Shared/OrderAttributes.swift` |
| Share extension | `ios/Share/ShareViewController.swift` |
| App Intents & Siri | `ios/Runner/AppIntents.swift`, `ios/Shared/Intents.swift` |
| Control Center | `ios/Widgets/Controls.swift` |
| Deep links, storage inspector | `lib/demo/pages/` |

The native features the demo calls from Dart (`widgets`, `liveActivity`,
`demo`) are in `ios/Runner/DemoFeatures.swift`; the background callback is in
`lib/main.dart`. The extensions are iOS only for now; the rest of the app runs
everywhere.

* `lib/main.dart` – the bridge, the background callback and Dart logic shared
  by the app and the background isolate.
* `lib/demo/` – the demo UI.
* `android/app/src/main/kotlin/.../ExampleFeature.kt`, `ios/Runner/AppDelegate.swift`
  and `macos/Runner/MainFlutterWindow.swift` – the native `example` feature.
* `android/app/src/main/kotlin/.../CounterWidgetProvider.kt` – the Android home
  screen widget.
* `integration_test/extension_bridge_test.dart` – the tests CI runs on every
  platform.

## Running on an iPhone

The Runner, `Widgets` and `Share` targets share the App Group
`group.co.leancode.extensionBridgeExample`. Set your team in Xcode for
all three targets (or change the bundle identifiers and the group) and run:

```sh
flutter run --release
```

The extensions link `ExtensionBridgeKit` from
`ios/Flutter/ephemeral/Packages/.packages/extension_bridge`, which
`flutter build` creates; run a Flutter build once before building from Xcode.

```sh
flutter test integration_test -d <device>
```
