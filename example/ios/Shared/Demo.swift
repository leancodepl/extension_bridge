import Foundation
import ExtensionBridgeKit

/// Everything the app and its extensions agree on.
///
/// Compiled into the Runner, Widgets and Share targets. The same keys and file
/// names are used from Dart in `lib/demo/shared.dart`.
enum Demo {
  /// The App Group in the App Groups capability of every target.
  static let appGroup = "group.com.nikodembernat.extensionBridgeExample"

  /// `bridge.storage` in Dart.
  static var storage: ExtensionBridgeStorage { ExtensionBridgeStorage(appGroup: appGroup) }

  /// `bridge.files` in Dart.
  static var files: ExtensionBridgeFiles { ExtensionBridgeFiles(appGroup: appGroup) }

  enum Key {
    static let counter = "counter"
    static let counterUpdatedBy = "counter.updatedBy"
    static let counterUpdatedAt = "counter.updatedAt"
    static let partyMode = "partyMode"
    static let artCaption = "art.caption"
    static let inbox = "share.inbox"
    static let chart = "chart"
    static let trace = "debug.trace"
  }

  private static let lock = NSLock()
  private static let runsLock = NSLock()
  private static var runs: [String: (started: Date, task: Task<any Sendable, Error>)] = [:]

  /// Records which process ran `event`, newest first, for debugging.
  static func trace(_ event: String) {
    lock.lock()
    defer { lock.unlock() }
    let defaults = storage.defaults
    let time = Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
    var entries = defaults.stringArray(forKey: Key.trace) ?? []
    entries.insert("\(time) [\(ProcessInfo.processInfo.processName)] \(event)", at: 0)
    defaults.set(Array(entries.prefix(40)), forKey: Key.trace)
  }

  /// Runs `body` once for all intents identified by `key` that start within
  /// `window` of each other, and returns its result to each of them.
  ///
  /// A tap on a control mirrored to Apple Watch makes iOS perform its intent
  /// twice at once. The echo waits for the first run instead of returning
  /// early, because the system reads the control's value as soon as an intent
  /// returns and the watch would show the value from before the tap.
  static func once<T: Sendable>(
    _ key: String, within window: TimeInterval = 0.25,
    _ body: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    runsLock.lock()
    let now = Date()
    let task: Task<any Sendable, Error>
    let isEcho: Bool
    if let run = runs[key], now.timeIntervalSince(run.started) < window {
      task = run.task
      isEcho = true
    } else {
      task = Task { try await body() }
      runs[key] = (now, task)
      isEcho = false
    }
    runsLock.unlock()
    if isEcho {
      trace("↳ \(key): echo waits for the first run")
    }
    return try await task.value as! T
  }

  enum File {
    static let artSquare = "art/square.png"
    static let artWide = "art/wide.png"
  }

  enum WidgetKind {
    static let counter = "CounterWidget"
    static let art = "ArtWidget"
    static let chart = "ChartWidget"
  }

  enum ControlKind {
    static let increment = "IncrementControl"
    static let partyMode = "PartyModeControl"
    static let open = "OpenDemoControl"
  }

  /// A Darwin notification posted whenever an extension changes shared state,
  /// so the running app can refresh immediately (see `DemoFeature`).
  static let changedNotification = "com.nikodembernat.extensionBridgeExample.changed"

  /// Tells the app (in any process) that shared state changed.
  static func notifyChanged() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(changedNotification as CFString), nil, nil, true)
  }

  /// Writes the counter natively, without Dart.
  @discardableResult
  static func addToCounter(_ amount: Int, updatedBy: String) -> Int {
    let counter = (storage.integer(forKey: Key.counter) ?? 0) + amount
    storage.set(counter, forKey: Key.counter)
    storage.set(updatedBy, forKey: Key.counterUpdatedBy)
    storage.set(Int(Date().timeIntervalSince1970 * 1000), forKey: Key.counterUpdatedAt)
    return counter
  }
}
