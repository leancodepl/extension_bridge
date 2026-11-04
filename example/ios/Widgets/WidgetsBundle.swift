import SwiftUI
import WidgetKit

/// Every WidgetKit surface of the demo: home and Lock Screen widgets, the Live
/// Activity and the Control Center controls.
@main
struct DemoWidgets: WidgetBundle {
  var body: some Widget {
    CounterWidget()
    ArtWidget()
    ChartWidget()
    OrderLiveActivity()
    IncrementControl()
    PartyModeControl()
    OpenDemoControl()
  }
}

/// The colors of the demo, matching the Flutter theme.
extension Color {
  static let bridgeIndigo = Color(red: 0.25, green: 0.32, blue: 0.71)
  static let bridgeBlue = Color(red: 0.01, green: 0.66, blue: 0.96)
  static let bridgePink = Color(red: 0.91, green: 0.12, blue: 0.39)
  static let bridgeOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
}
