import ExtensionBridgeKit
import SwiftUI
import WidgetKit

/// Shows a PNG that Flutter painted and saved with `bridge.files.write(...)`.
struct ArtWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Demo.WidgetKind.art, provider: ArtProvider()) { entry in
      ArtWidgetView(entry: entry)
    }
    .configurationDisplayName("Flutter art")
    .description("An image painted by Flutter and shared through bridge.files.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    .contentMarginsDisabled()
  }
}

struct ArtEntry: TimelineEntry {
  let date: Date
  let square: UIImage?
  let wide: UIImage?
  let caption: String?
}

struct ArtProvider: TimelineProvider {
  func placeholder(in context: Context) -> ArtEntry {
    ArtEntry(date: .now, square: nil, wide: nil, caption: "Painted by Flutter")
  }

  func getSnapshot(in context: Context, completion: @escaping (ArtEntry) -> Void) {
    completion(read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ArtEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .never))
  }

  private func read() -> ArtEntry {
    let files = ExtensionBridgeFiles(appGroup: Demo.appGroup)
    return ArtEntry(
      date: .now,
      square: files.read(Demo.File.artSquare).flatMap(UIImage.init(data:)),
      wide: files.read(Demo.File.artWide).flatMap(UIImage.init(data:)),
      caption: Demo.storage.string(forKey: Demo.Key.artCaption))
  }
}

struct ArtWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ArtEntry

  var body: some View {
    Group {
      if let image = (family == .systemMedium ? entry.wide : entry.square) ?? entry.square {
        Color.clear.overlay {
          Image(uiImage: image).resizable().scaledToFill()
        }
        .clipped()
      } else {
        VStack(spacing: 8) {
          Image(systemName: "paintpalette.fill").font(.largeTitle)
          Text("Open the app and tap “Send to widget”")
            .font(.caption)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding()
      }
    }
    .widgetURL(ExtensionBridgeLinks.url("extensionbridge://art", source: "widget"))
    .containerBackground(for: .widget) {
      LinearGradient(
        colors: [.bridgeIndigo, .bridgePink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }
}
