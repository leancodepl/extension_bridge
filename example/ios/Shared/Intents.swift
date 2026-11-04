import AppIntents
import Foundation
import WidgetKit

// Compiled into the Runner and Widgets targets. Widgets, Live Activities and
// controls need the intent types to build their buttons; because the intents
// conform to `LiveActivityIntent` and are also part of the app, iOS performs
// them in the app process, where Flutter is available. The Widgets target
// defines `WIDGET_EXTENSION` and never links Flutter.
#if !WIDGET_EXTENSION
  import extension_bridge
#endif

/// Adds to the shared counter by running Dart in a background isolate.
///
/// Used by the counter widget's buttons, the "Counter +1" control, Siri and
/// Shortcuts.
@available(iOS 17.0, *)
struct IncrementCounterIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Increment Counter"
  static let description = IntentDescription(
    "Runs Dart in the background to add to the counter shared with the widgets.")

  @Parameter(title: "Amount", default: 1)
  var amount: Int

  init() {}

  init(amount: Int) {
    self.amount = amount
  }

  func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
    Demo.trace("IncrementCounterIntent(amount: \(amount))")
    let amount = amount
    let counter = try await Demo.once("increment.\(amount)") {
      await Self.increment(by: amount)
    }
    return .result(value: counter, dialog: "The counter is now \(counter).")
  }

  private static func increment(by amount: Int) async -> Int {
    #if WIDGET_EXTENSION
      let counter = Demo.addToCounter(amount, updatedBy: "Swift in the widget extension")
    #else
      let counter: Int
      do {
        // ⬇️ The whole Flutter integration: run `onBackgroundEvent` in Dart.
        let result = try await ExtensionBridgeBackground.dispatch(
          "increment", arguments: ["amount": amount])
        counter = result as? Int ?? 0
      } catch {
        // No Dart callback yet (the app was never opened): stay useful.
        counter = Demo.addToCounter(amount, updatedBy: "Swift (Dart unavailable)")
      }
    #endif
    Demo.reloadEverything()
    return counter
  }
}

/// Moves the order Live Activity to its next step. Dart decides what the next
/// step looks like.
@available(iOS 17.0, *)
struct AdvanceOrderIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Advance Order"
  static let isDiscoverable = false

  @Parameter(title: "Activity ID")
  var activityID: String

  init() {}

  init(activityID: String) {
    self.activityID = activityID
  }

  func perform() async throws -> some IntentResult {
    Demo.trace("AdvanceOrderIntent")
    #if !WIDGET_EXTENSION
      let activityID = activityID
      try await Demo.once("advanceOrder.\(activityID)") {
        try await ExtensionBridgeBackground.dispatch("advanceOrder", arguments: ["id": activityID])
        Demo.notifyChanged()
      }
    #endif
    return .result()
  }
}

/// Turns party mode on or off. Performed natively wherever it runs: it only
/// writes shared storage, which the Flutter app observes.
@available(iOS 18.0, *)
struct SetPartyModeIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Party Mode"
  static let description = IntentDescription("Switches the Flutter app's party theme.")

  @Parameter(title: "Party mode")
  var value: Bool

  func perform() async throws -> some IntentResult {
    Demo.trace("SetPartyModeIntent(value: \(value))")
    let value = value
    try await Demo.once("partyMode.\(value)") {
      Demo.storage.set(value, forKey: Demo.Key.partyMode)
      // No `ControlCenter` reload: the system queries the toggle's value
      // itself once `perform()` returns, and a reload from inside the intent
      // can make a mirrored control (Apple Watch) fall back to its old state.
      Demo.notifyChanged()
    }
    return .result()
  }
}

extension Demo {
  /// Redraws widgets and controls and tells the app that state changed.
  static func reloadEverything() {
    WidgetCenter.shared.reloadAllTimelines()
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadAllControls()
    }
    notifyChanged()
  }
}
