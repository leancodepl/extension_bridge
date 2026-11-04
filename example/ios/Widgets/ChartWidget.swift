import Charts
import ExtensionBridgeKit
import SwiftUI
import WidgetKit

/// A chart drawn natively with SwiftUI and Swift Charts from data Flutter
/// saved with `bridge.storage.setJson('chart', {...})`.
struct ChartWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Demo.WidgetKind.chart, provider: ChartProvider()) { entry in
      ChartWidgetView(entry: entry)
    }
    .configurationDisplayName("SwiftUI chart")
    .description("Swift Charts drawing JSON that Flutter wrote.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
  }
}

/// The JSON Flutter writes, decoded with `ExtensionBridgeStorage.decode`.
struct ChartData: Codable {
  struct Point: Codable, Identifiable {
    var label: String
    var value: Double
    var id: String { label }
  }

  var title: String
  var unit: String
  /// `#RRGGBB`.
  var accent: String
  /// `bar`, `line` or `area`.
  var style: String
  var points: [Point]
  /// Milliseconds since the epoch.
  var updatedAt: Double?

  var total: Double { points.reduce(0) { $0 + $1.value } }
  var best: Point? { points.max { $0.value < $1.value } }
  var color: Color { Color(hex: accent) ?? .bridgeBlue }

  static let placeholder = ChartData(
    title: "Hot reloads", unit: "reloads", accent: "#E91E63", style: "bar",
    points: zip(["M", "T", "W", "T", "F", "S", "S"], [12, 30, 22, 41, 35, 8, 15]).map {
      Point(label: $0, value: Double($1))
    },
    updatedAt: nil)
}

struct ChartEntry: TimelineEntry {
  let date: Date
  let data: ChartData
  /// Whether the data is a placeholder because Flutter has not sent any yet.
  let isPlaceholder: Bool
}

struct ChartProvider: TimelineProvider {
  func placeholder(in context: Context) -> ChartEntry {
    ChartEntry(date: .now, data: .placeholder, isPlaceholder: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (ChartEntry) -> Void) {
    completion(read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ChartEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .never))
  }

  private func read() -> ChartEntry {
    // ⬇️ The bridge: a Codable struct from JSON written in Dart.
    let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
    let data = try? storage.decode(ChartData.self, forKey: Demo.Key.chart)
    return ChartEntry(date: .now, data: data ?? .placeholder, isPlaceholder: data == nil)
  }
}

struct ChartWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ChartEntry

  private var data: ChartData { entry.data }

  var body: some View {
    content
      .widgetURL(ExtensionBridgeLinks.url("extensionbridge://chart", source: "widget"))
      .containerBackground(for: .widget) {
        LinearGradient(
          colors: [data.color.opacity(0.28), Color(.systemBackground)],
          startPoint: .top, endPoint: .bottom)
      }
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Text(data.title).font(.caption.bold()).lineLimit(1)
        chart(axes: false).frame(maxHeight: .infinity)
      }
    case .systemSmall:
      VStack(alignment: .leading, spacing: 6) {
        header
        chart(axes: false)
      }
    case .systemLarge:
      VStack(alignment: .leading, spacing: 12) {
        header
        chart(axes: true)
        footer
      }
    default:
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 6) {
          header
          Spacer(minLength: 0)
          footer
        }
        .frame(width: 110, alignment: .leading)
        chart(axes: true)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(data.title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Text(data.total, format: .number.precision(.fractionLength(0)))
        .font(.system(.title, design: .rounded, weight: .heavy))
        .foregroundStyle(data.color)
        .contentTransition(.numericText())
      Text(data.unit).font(.caption2).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var footer: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let best = data.best {
        Label("Best: \(best.label) · \(Int(best.value))", systemImage: "trophy.fill")
          .foregroundStyle(data.color)
      }
      if entry.isPlaceholder {
        Text("Sample data – edit it in the app")
      } else if let updatedAt = data.updatedAt {
        Text("Sent by Flutter \(Date(timeIntervalSince1970: updatedAt / 1000), style: .relative) ago")
      }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .lineLimit(2)
  }

  /// Swift Charts, styled by what Flutter asked for.
  private func chart(axes: Bool) -> some View {
    Chart(data.points) { point in
      if data.style == "line" {
        LineMark(x: .value("Label", point.label), y: .value(data.unit, point.value))
          .interpolationMethod(.catmullRom)
          .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
          .foregroundStyle(data.color)
        PointMark(x: .value("Label", point.label), y: .value(data.unit, point.value))
          .foregroundStyle(data.color)
          .symbolSize(point.id == data.best?.id ? 80 : 24)
      } else if data.style == "area" {
        AreaMark(x: .value("Label", point.label), y: .value(data.unit, point.value))
          .interpolationMethod(.catmullRom)
          .foregroundStyle(
            LinearGradient(
              colors: [data.color.opacity(0.6), data.color.opacity(0.05)],
              startPoint: .top, endPoint: .bottom))
        LineMark(x: .value("Label", point.label), y: .value(data.unit, point.value))
          .interpolationMethod(.catmullRom)
          .foregroundStyle(data.color)
      } else {
        BarMark(x: .value("Label", point.label), y: .value(data.unit, point.value))
          .foregroundStyle(data.color.opacity(point.id == data.best?.id ? 1 : 0.55))
          .cornerRadius(4)
      }
    }
    .chartXAxis(axes ? .automatic : .hidden)
    .chartYAxis(axes && family == .systemLarge ? .automatic : .hidden)
  }
}

extension Color {
  /// Parses `#RRGGBB`, the format Flutter sends.
  init?(hex: String) {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}

#Preview(as: .systemMedium) {
  ChartWidget()
} timeline: {
  ChartEntry(date: .now, data: .placeholder, isPlaceholder: true)
}
