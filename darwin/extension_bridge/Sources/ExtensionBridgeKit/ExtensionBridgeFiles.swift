import Foundation

/// Files shared between the app and its extensions.
///
/// This is the native counterpart of `SharedFiles` in Dart: a file written in
/// Dart with `bridge.files.write('avatar.png', bytes)` is found here under the
/// same name.
///
/// ```swift
/// let files = ExtensionBridgeFiles(appGroup: "group.com.example.app")
/// if let data = files.read("avatar.png"), let image = UIImage(data: data) {
///   ...
/// }
/// ```
///
/// Files live in the `extension_bridge` directory of the app group container.
/// Without an app group the app's own Application Support directory is used,
/// which extensions cannot read.
public struct ExtensionBridgeFiles {
  /// The app group shared with the extensions, or `nil` for app private
  /// files.
  public let appGroup: String?

  /// Creates the files of `appGroup`.
  public init(appGroup: String? = nil) {
    self.appGroup = appGroup
  }

  /// The directory holding the shared files.
  ///
  /// `nil` when the app group container is not available, which usually
  /// means the App Groups capability is missing from the target.
  public var directory: URL? {
    let fileManager = FileManager.default
    if let appGroup {
      return fileManager
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
        .appendingPathComponent("extension_bridge", isDirectory: true)
    }
    guard
      let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else { return nil }
    return
      applicationSupport
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "extension_bridge", isDirectory: true)
      .appendingPathComponent("extension_bridge", isDirectory: true)
      .appendingPathComponent("default", isDirectory: true)
  }

  /// The URL of the file called `name`, which does not have to exist.
  ///
  /// `nil` when the directory is not available or, as in Dart, when `name`
  /// isn't a relative path without empty, `.` or `..` segments.
  public func url(for name: String) -> URL? {
    guard let path = Self.relativePath(name) else { return nil }
    return directory?.appendingPathComponent(path, isDirectory: false)
  }

  private static func relativePath(_ name: String) -> String? {
    let segments = name.split(omittingEmptySubsequences: false) { $0 == "/" || $0 == "\\" }
    guard !segments.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
      return nil
    }
    return segments.joined(separator: "/")
  }

  /// Reads the file called `name`.
  public func read(_ name: String) -> Data? {
    guard let url = url(for: name) else { return nil }
    return try? Data(contentsOf: url)
  }

  /// Whether the file called `name` exists.
  public func exists(_ name: String) -> Bool {
    guard let url = url(for: name) else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  /// Atomically writes `data` to the file called `name` and returns its URL.
  @discardableResult
  public func write(_ data: Data, to name: String) throws -> URL {
    guard Self.relativePath(name) != nil else { throw CocoaError(.fileWriteInvalidFileName) }
    guard let url = url(for: name) else { throw CocoaError(.fileNoSuchFile) }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    return url
  }

  /// Deletes the file called `name` and returns whether it existed.
  @discardableResult
  public func delete(_ name: String) throws -> Bool {
    guard let url = url(for: name), FileManager.default.fileExists(atPath: url.path) else {
      return false
    }
    try FileManager.default.removeItem(at: url)
    return true
  }
}
