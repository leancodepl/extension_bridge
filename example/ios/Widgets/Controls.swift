import AppIntents
import ExtensionBridgeKit
import SwiftUI
import WidgetKit

/// A Control Center button that runs Dart in the background.
struct IncrementControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Demo.ControlKind.increment, provider: CounterValue()) {
      counter in
      ControlWidgetButton(action: IncrementCounterIntent(amount: 1)) {
        Label("Counter: \(counter)", systemImage: "plus.circle.fill")
      }
    }
    .displayName("Counter +1")
    .description("Runs Dart in a background isolate to increment the counter.")
  }

  struct CounterValue: ControlValueProvider {
    var previewValue: Int { 42 }

    func currentValue() async throws -> Int {
      let value = Demo.storage.integer(forKey: Demo.Key.counter) ?? 0
      Demo.trace("CounterValue.currentValue() → \(value)")
      return value
    }
  }
}

/// A Control Center toggle backed by shared storage. The Flutter app changes
/// its theme as soon as it is flipped.
struct PartyModeControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Demo.ControlKind.partyMode, provider: PartyModeValue()) {
      isOn in
      ControlWidgetToggle("Party mode", isOn: isOn, action: SetPartyModeIntent()) { isOn in
        Label(isOn ? "On" : "Off", systemImage: isOn ? "party.popper.fill" : "party.popper")
      }
      .tint(.pink)
    }
    .displayName("Party mode")
    .description("Writes bridge.storage; Flutter re-themes live.")
  }

  struct PartyModeValue: ControlValueProvider {
    var previewValue: Bool { true }

    func currentValue() async throws -> Bool {
      let value = Demo.storage.bool(forKey: Demo.Key.partyMode) ?? false
      Demo.trace("PartyModeValue.currentValue() → \(value)")
      return value
    }
  }
}

/// A Control Center button that opens the app with an extension link.
struct OpenDemoControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Demo.ControlKind.open) {
      ControlWidgetButton(
        action: OpenURLIntent(
          ExtensionBridgeLinks.url(URL(string: "extensionbridge://controls")!, source: "control"))
      ) {
        Label("Open demo", systemImage: "arrow.up.forward.app.fill")
      }
    }
    .displayName("Open Extension Bridge")
    .description("Opens the app; Dart receives an ExtensionLink.")
  }
}
