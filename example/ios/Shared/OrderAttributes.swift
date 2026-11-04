import ActivityKit
import Foundation

/// The Live Activity started from Dart with
/// `bridge.feature('liveActivity').invoke('start', ...)`.
///
/// Compiled into the Runner (which starts and updates it) and Widgets (which
/// draws it on the Lock Screen and in the Dynamic Island) targets.
@available(iOS 16.1, *)
struct OrderAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// An index into `OrderAttributes.steps`.
    var step: Int
    /// When the order should arrive.
    var eta: Date
    /// A status line computed in Dart.
    var message: String
  }

  /// What was ordered, for example "Flutter pizza".
  var item: String
  /// An emoji shown in the Dynamic Island.
  var emoji: String

  static let steps: [(title: String, symbol: String)] = [
    ("Ordered", "bag.fill"),
    ("Preparing", "flame.fill"),
    ("On the way", "bicycle"),
    ("Delivered", "checkmark.seal.fill"),
  ]

  static var lastStep: Int { steps.count - 1 }
}
