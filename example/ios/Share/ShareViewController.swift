import ExtensionBridgeKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One shared item, read in Dart with `bridge.storage.getJson('share.inbox')`.
struct InboxItem: Codable, Identifiable {
  enum Kind: String, Codable {
    case text, url, image
  }

  var id = UUID().uuidString
  var kind: Kind
  /// The text, the URL or – for images – the name of the file in
  /// `bridge.files`.
  var value: String
  /// Milliseconds since the epoch, like `DateTime.millisecondsSinceEpoch`.
  var sharedAt = Int(Date().timeIntervalSince1970 * 1000)
}

/// The share extension: saves whatever is shared into the App Group, where the
/// Flutter app picks it up.
final class ShareViewController: UIViewController {
  private let model = ShareModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    let host = UIHostingController(
      rootView: ShareView(model: model) { [weak self] in
        self?.extensionContext?.completeRequest(returningItems: nil)
      })
    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    host.didMove(toParent: self)

    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    Task { await model.save(items.flatMap { $0.attachments ?? [] }) }
  }
}

@MainActor
final class ShareModel: ObservableObject {
  @Published var saved: [InboxItem] = []
  @Published var images: [String: UIImage] = [:]
  @Published var isSaving = true
  @Published var error: String?

  private let storage = ExtensionBridgeStorage(appGroup: Demo.appGroup)
  private let files = ExtensionBridgeFiles(appGroup: Demo.appGroup)

  func save(_ providers: [NSItemProvider]) async {
    defer { isSaving = false }
    do {
      var items: [InboxItem] = []
      for provider in providers {
        if let item = try await load(provider) {
          items.append(item)
        }
      }
      // ⬇️ The bridge: Codable in Swift, `getJson` in Dart.
      let inbox = (try? storage.decode([InboxItem].self, forKey: Demo.Key.inbox)) ?? []
      try storage.encode(items + inbox, forKey: Demo.Key.inbox)
      Demo.notifyChanged()
      saved = items
    } catch {
      self.error = error.localizedDescription
    }
  }

  private func load(_ provider: NSItemProvider) async throws -> InboxItem? {
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      let data = try await provider.data(for: .image)
      guard let image = UIImage(data: data)?.downscaled(toFit: 1600),
        let jpeg = image.jpegData(compressionQuality: 0.85)
      else { return nil }
      let name = "share/\(UUID().uuidString).jpg"
      // ⬇️ The bridge: Dart reads it with `bridge.files.read(name)`.
      try files.write(jpeg, to: name)
      images[name] = image
      return InboxItem(kind: .image, value: name)
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
      let url = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
    {
      return InboxItem(kind: .url, value: url.absoluteString)
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
      let text = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
        as? String
    {
      return InboxItem(kind: .text, value: text)
    }
    return nil
  }
}

struct ShareView: View {
  @ObservedObject var model: ShareModel
  let done: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack(spacing: 14) {
            Image(systemName: model.error == nil ? "tray.and.arrow.down.fill" : "xmark.octagon")
              .font(.largeTitle)
              .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 4) {
              Text(title).font(.headline)
              Text("Saved with ExtensionBridgeKit. Open Extension Bridge to see it in Dart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 6)
        }
        if !model.saved.isEmpty {
          Section("Shared") {
            ForEach(model.saved) { item in
              row(item)
            }
          }
        }
      }
      .overlay {
        if model.isSaving { ProgressView() }
      }
      .navigationTitle("Extension Bridge")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: done).disabled(model.isSaving)
        }
      }
    }
  }

  private var title: String {
    if let error = model.error { return error }
    if model.isSaving { return "Saving…" }
    return model.saved.count == 1 ? "Sent 1 item to Flutter" : "Sent \(model.saved.count) items to Flutter"
  }

  @ViewBuilder
  private func row(_ item: InboxItem) -> some View {
    switch item.kind {
    case .image:
      if let image = model.images[item.value] {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(height: 160)
          .clipShape(.rect(cornerRadius: 12))
      }
    case .url:
      Label(item.value, systemImage: "link").lineLimit(2)
    case .text:
      Label(item.value, systemImage: "text.quote").lineLimit(4)
    }
  }
}

extension NSItemProvider {
  fileprivate func data(for type: UTType) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      _ = loadDataRepresentation(for: type) { data, error in
        if let data {
          continuation.resume(returning: data)
        } else {
          continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
        }
      }
    }
  }
}

extension UIImage {
  fileprivate func downscaled(toFit maxSide: CGFloat) -> UIImage {
    let scale = min(1, maxSide / max(size.width, size.height))
    guard scale < 1 else { return self }
    let target = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
