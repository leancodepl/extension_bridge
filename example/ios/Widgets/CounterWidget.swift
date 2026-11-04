import AppIntents
import ExtensionBridgeKit
import SwiftUI
import WidgetKit

/// A counter shared with Flutter, on the Home Screen, Lock Screen and in
/// StandBy. Its buttons run Dart in the background.
struct CounterWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Demo.WidgetKind.counter, provider: CounterProvider()) { entry in
      CounterWidgetView(entry: entry)
    }
    .configurationDisplayName("Shared counter")
    .description("Reads bridge.storage and runs Dart when you tap + or −.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

struct CounterEntry: TimelineEntry {
  let date: Date
  let counter: Int
  let updatedBy: String?
  let updatedAt: Date?
  let partyMode: Bool

  static let preview = CounterEntry(
    date: .now, counter: 42, updatedBy: "Dart in a background isolate", updatedAt: .now,
    partyMode: false)
}

struct CounterProvider: TimelineProvider {
  func placeholder(in context: Context) -> CounterEntry { .preview }

  func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
    completion(context.isPreview ? .preview : read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
    // The app and the intents reload the widget whenever the counter changes.
    completion(Timeline(entries: [read()], policy: .never))
  }

  /// Reads what Dart wrote with `bridge.storage.set(...)`.
  private func read() -> CounterEntry {
    let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
    return CounterEntry(
      date: .now,
      counter: storage.integer(forKey: Demo.Key.counter) ?? 0,
      updatedBy: storage.string(forKey: Demo.Key.counterUpdatedBy),
      updatedAt: storage.double(forKey: Demo.Key.counterUpdatedAt).map {
        Date(timeIntervalSince1970: $0 / 1000)
      },
      partyMode: storage.bool(forKey: Demo.Key.partyMode) ?? false)
  }
}

struct CounterWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: CounterEntry

  var body: some View {
    content
      .widgetURL(ExtensionBridgeLinks.url("extensionbridge://counter", source: "widget"))
      .containerBackground(for: .widget) { background }
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Image(systemName: "bolt.horizontal.fill").font(.caption2)
          Text("\(entry.counter)").font(.title3.bold()).minimumScaleFactor(0.5)
        }
      }
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("Counter", systemImage: "bolt.horizontal.fill").font(.headline)
        Text("\(entry.counter)").font(.title2.bold()).contentTransition(.numericText())
        Text(entry.updatedBy ?? "extension_bridge").font(.caption2).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    case .accessoryInline:
      Label("Counter \(entry.counter)", systemImage: "bolt.horizontal.fill")
    case .systemMedium:
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          header
          Spacer(minLength: 0)
          counter
          updatedBy
        }
        Spacer(minLength: 0)
        VStack(spacing: 10) {
          button(amount: 1, symbol: "plus")
          button(amount: -1, symbol: "minus")
        }
      }
    default:
      VStack(alignment: .leading, spacing: 4) {
        header
        Spacer(minLength: 0)
        counter
        HStack {
          button(amount: -1, symbol: "minus")
          Spacer(minLength: 0)
          button(amount: 1, symbol: "plus")
        }
      }
    }
  }

  private var header: some View {
    Label(entry.partyMode ? "Party!" : "Shared counter", systemImage: "bolt.horizontal.fill")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white.opacity(0.8))
  }

  private var counter: some View {
    Text("\(entry.counter)")
      .font(.system(size: 52, weight: .heavy, design: .rounded))
      .foregroundStyle(.white)
      .minimumScaleFactor(0.4)
      .lineLimit(1)
      .contentTransition(.numericText())
  }

  @ViewBuilder
  private var updatedBy: some View {
    if let by = entry.updatedBy {
      VStack(alignment: .leading, spacing: 0) {
        Text("Updated by \(by)")
        if let at = entry.updatedAt {
          Text(at, style: .relative) + Text(" ago")
        }
      }
      .font(.caption2)
      .foregroundStyle(.white.opacity(0.75))
      .lineLimit(2)
    }
  }

  /// An interactive (iOS 17) button: the intent runs Dart in the app process.
  private func button(amount: Int, symbol: String) -> some View {
    Button(intent: IncrementCounterIntent(amount: amount)) {
      Image(systemName: symbol)
        .font(.headline.weight(.bold))
        .frame(width: 44, height: 36)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(.white.opacity(0.22), in: .capsule)
  }

  private var background: some View {
    LinearGradient(
      colors: entry.partyMode ? [.bridgePink, .bridgeOrange] : [.bridgeIndigo, .bridgeBlue],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

#Preview(as: .systemSmall) {
  CounterWidget()
} timeline: {
  CounterEntry.preview
}
