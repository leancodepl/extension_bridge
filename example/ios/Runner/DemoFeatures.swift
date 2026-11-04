import ActivityKit
import Foundation
import UIKit
import WidgetKit
import extension_bridge

/// `bridge.feature('widgets')`: reloads WidgetKit timelines and controls.
final class WidgetsFeature: ExtensionBridgeFeature {
  let name = "widgets"

  func handle(_ call: ExtensionBridgeCall) async throws -> Any? {
    switch call.method {
    case "reload":
      if let kind: String = call.argument("kind") {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      } else {
        WidgetCenter.shared.reloadAllTimelines()
      }
      if #available(iOS 18.0, *) {
        ControlCenter.shared.reloadAllControls()
      }
      return nil
    case "installed":
      let configurations = try await withCheckedThrowingContinuation { continuation in
        WidgetCenter.shared.getCurrentConfigurations { continuation.resume(with: $0) }
      }
      return configurations.map { ["kind": $0.kind, "family": "\($0.family)"] }
    default:
      throw ExtensionBridgeError.notImplemented(call)
    }
  }
}

/// `bridge.feature('liveActivity')`: starts, updates and ends the order Live
/// Activity. The Live Activity UI lives in the Widgets extension.
@available(iOS 16.2, *)
final class LiveActivityFeature: ExtensionBridgeFeature {
  let name = "liveActivity"

  func handle(_ call: ExtensionBridgeCall) async throws -> Any? {
    switch call.method {
    case "isEnabled":
      return ActivityAuthorizationInfo().areActivitiesEnabled
    case "start":
      let attributes = OrderAttributes(
        item: try call.requireArgument("item"), emoji: try call.requireArgument("emoji"))
      let activity = try Activity.request(
        attributes: attributes, content: try content(of: call), pushType: nil)
      Demo.notifyChanged()
      return activity.id
    case "update":
      let activity = try find(try call.requireArgument("id"))
      let alert: String? = call.argument("alert")
      await activity.update(
        try content(of: call),
        alertConfiguration: alert.map {
          AlertConfiguration(
            title: "\(activity.attributes.emoji) \(activity.attributes.item)", body: "\($0)",
            sound: .default)
        })
      Demo.notifyChanged()
      return nil
    case "end":
      let id: String? = call.argument("id")
      for activity in Activity<OrderAttributes>.activities where id == nil || activity.id == id {
        await activity.end(nil, dismissalPolicy: .after(.now + 4))
      }
      Demo.notifyChanged()
      return nil
    case "list":
      return Activity<OrderAttributes>.activities.map { activity in
        [
          "id": activity.id,
          "item": activity.attributes.item,
          "emoji": activity.attributes.emoji,
          "step": activity.content.state.step,
          "eta": Int(activity.content.state.eta.timeIntervalSince1970 * 1000),
          "message": activity.content.state.message,
          "state": "\(activity.activityState)",
        ] as [String: Any]
      }
    default:
      throw ExtensionBridgeError.notImplemented(call)
    }
  }

  private func find(_ id: String) throws -> Activity<OrderAttributes> {
    guard let activity = Activity<OrderAttributes>.activities.first(where: { $0.id == id }) else {
      throw ExtensionBridgeError(code: "not-found", message: "No Live Activity with id \(id).")
    }
    return activity
  }

  private func content(of call: ExtensionBridgeCall) throws
    -> ActivityContent<OrderAttributes.ContentState>
  {
    let eta: Int = try call.requireArgument("eta")
    let state = OrderAttributes.ContentState(
      step: try call.requireArgument("step"),
      eta: Date(timeIntervalSince1970: Double(eta) / 1000),
      message: try call.requireArgument("message"))
    return ActivityContent(state: state, staleDate: nil)
  }
}

/// `bridge.feature('demo')`: streams a `changes` event whenever an extension
/// posts `Demo.changedNotification`, so Flutter refreshes while it is open.
final class DemoFeature: ExtensionBridgeFeature {
  let name = "demo"

  func handle(_ call: ExtensionBridgeCall) async throws -> Any? {
    switch call.method {
    case "notifyChanged":
      Demo.notifyChanged()
      return nil
    case "trace":
      Demo.trace("Dart: \(try call.requireArgument("event") as String)")
      return nil
    case "open":
      let url: String = try call.requireArgument("url")
      guard let url = URL(string: url) else {
        throw ExtensionBridgeError(code: ExtensionBridgeError.invalidArgumentsCode)
      }
      return await UIApplication.shared.open(url)
    default:
      throw ExtensionBridgeError.notImplemented(call)
    }
  }

  func listen(to stream: String, arguments: Any?, sink: ExtensionBridgeEventSink) throws
    -> ExtensionBridgeSubscription
  {
    guard stream == "changes" else {
      throw ExtensionBridgeError(code: ExtensionBridgeError.notImplementedCode)
    }
    let observer = DarwinNotificationObserver(name: Demo.changedNotification) {
      sink.send(Int(Date().timeIntervalSince1970 * 1000))
    }
    return ExtensionBridgeSubscription { observer.cancel() }
  }
}

/// Observes a Darwin notification, which crosses process boundaries.
private final class DarwinNotificationObserver {
  private let name: String
  private let handler: () -> Void

  init(name: String, handler: @escaping () -> Void) {
    self.name = name
    self.handler = handler
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passRetained(self).toOpaque(),
      { _, observer, _, _, _ in
        guard let observer else { return }
        let instance = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer)
          .takeUnretainedValue()
        DispatchQueue.main.async { instance.handler() }
      },
      name as CFString, nil, .deliverImmediately)
  }

  func cancel() {
    let pointer = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(), pointer, CFNotificationName(name as CFString),
      nil)
    Unmanaged<DarwinNotificationObserver>.fromOpaque(pointer).release()
  }
}
