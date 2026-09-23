import AppKit

extension Notification.Name {
    static let marklyImageLoaded = Notification.Name("marklyImageLoaded")
}

/// Holds an inline image preview and the size it should be drawn at.
final class ImageBox: NSObject {
    let image: NSImage
    let size: NSSize
    init(image: NSImage, size: NSSize) {
        self.image = image
        self.size = size
    }
}

/// Loads images referenced by documents (local paths or http/https) and caches them.
/// Returns nil while loading and posts `.marklyImageLoaded` when an image arrives.
@MainActor
final class ImageStore {
    static let shared = ImageStore()
    private var cache: [URL: NSImage] = [:]
    private var inFlight: Set<URL> = []
    private var failed: Set<URL> = []

    func resolve(_ source: String, relativeTo base: URL?) -> URL? {
        let src = source.trimmingCharacters(in: .whitespaces)
        guard !src.isEmpty else { return nil }
        if let url = URL(string: src), let scheme = url.scheme?.lowercased() {
            if scheme == "file" { return url }
            if scheme == "http" || scheme == "https" {
                return Pref.bool(Pref.remoteImages, default: true) ? url : nil
            }
            return nil
        }
        let path = src.removingPercentEncoding ?? src
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        if path.hasPrefix("~") { return URL(fileURLWithPath: (path as NSString).expandingTildeInPath) }
        guard let base else { return nil }
        return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
    }

    func image(for source: String, relativeTo base: URL?) -> NSImage? {
        guard let url = resolve(source, relativeTo: base) else { return nil }
        if let image = cache[url] { return image }
        guard !inFlight.contains(url), !failed.contains(url) else { return nil }
        inFlight.insert(url)
        Task.detached(priority: .utility) {
            let data: Data?
            if url.isFileURL {
                data = try? Data(contentsOf: url)
            } else {
                data = try? await URLSession.shared.data(from: url).0
            }
            await MainActor.run {
                self.inFlight.remove(url)
                if let data, let image = NSImage(data: data), image.size.width > 0 {
                    self.cache[url] = image
                    NotificationCenter.default.post(name: .marklyImageLoaded, object: nil)
                } else {
                    self.failed.insert(url)
                }
            }
        }
        return nil
    }
}
