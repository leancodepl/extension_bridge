import AppIntents
import Foundation
import extension_bridge

/// Reads the counter natively, straight from shared storage.
@available(iOS 16.0, *)
struct GetCounterIntent: AppIntent {
  static let title: LocalizedStringResource = "Get Counter"
  static let description = IntentDescription("Reads the counter Flutter saved in bridge.storage.")

  func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
    let counter = Demo.storage.integer(forKey: Demo.Key.counter) ?? 0
    return .result(value: counter, dialog: "The counter is \(counter).")
  }
}

/// Asks Dart a question in a background isolate and speaks the answer.
@available(iOS 16.0, *)
struct AskFlutterIntent: AppIntent {
  static let title: LocalizedStringResource = "Ask Flutter"
  static let description = IntentDescription(
    "Runs Dart without opening the app and returns what it computed.")

  @Parameter(title: "Question", default: "How are you?")
  var question: String

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let answer =
      try await ExtensionBridgeBackground.dispatch("ask", arguments: ["question": question])
      as? String ?? "Dart had nothing to say."
    return .result(value: answer, dialog: "\(answer)")
  }
}

/// Opens the app on the counter page with an extension link.
@available(iOS 16.0, *)
struct OpenCounterIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Counter"
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    ExtensionBridgePlugin.deliverLink(URL(string: "extensionbridge://counter")!, source: "app_intent")
    return .result()
  }
}

/// Siri phrases, Spotlight and Shortcuts actions, available without any setup.
@available(iOS 17.0, *)
struct DemoShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: IncrementCounterIntent(),
      phrases: [
        "Increment the counter in \(.applicationName)",
        "Add one in \(.applicationName)",
      ],
      shortTitle: "Increment",
      systemImageName: "plus.circle")
    AppShortcut(
      intent: GetCounterIntent(),
      phrases: [
        "What is the counter in \(.applicationName)",
        "Get the counter in \(.applicationName)",
      ],
      shortTitle: "Get counter",
      systemImageName: "number")
    AppShortcut(
      intent: AskFlutterIntent(),
      phrases: [
        "Ask Flutter in \(.applicationName)",
        "Ask \(.applicationName)",
      ],
      shortTitle: "Ask Flutter",
      systemImageName: "bubble.left.and.text.bubble.right")
    AppShortcut(
      intent: OpenCounterIntent(),
      phrases: ["Open the counter in \(.applicationName)"],
      shortTitle: "Open counter",
      systemImageName: "arrow.up.forward.app")
  }

  static let shortcutTileColor: ShortcutTileColor = .navy
}
