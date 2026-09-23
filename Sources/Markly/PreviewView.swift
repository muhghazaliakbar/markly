import AppKit
import SwiftUI
import WebKit

extension NSColor {
    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#0a84ff" }
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

/// Renders the document as HTML. The page shell loads once per file; edits are pushed in with JavaScript
/// so the scroll position survives typing.
struct PreviewView: NSViewRepresentable {
    var markdown: String
    var fileURL: URL?
    var accent: NSColor

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.schedule(web: web, markdown: markdown, fileURL: fileURL, accent: accent.hexString)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadedKey: String?
        private var ready = false
        private var pending: String?
        private var lastMarkdown: String?
        private var work: DispatchWorkItem?

        func schedule(web: WKWebView, markdown: String, fileURL: URL?, accent: String) {
            let key = (fileURL?.path ?? "") + accent
            if key != loadedKey {
                loadedKey = key
                ready = false
                lastMarkdown = markdown
                let html = MarkdownRenderer.page(title: fileURL?.lastPathComponent ?? "Preview",
                                                 body: MarkdownRenderer.html(from: markdown),
                                                 baseURL: fileURL?.deletingLastPathComponent(), accentHex: accent)
                // Write to a temp file so relative image paths next to the document can load.
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("markly-preview.html")
                try? html.write(to: tmp, atomically: true, encoding: .utf8)
                web.loadFileURL(tmp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
                return
            }
            guard markdown != lastMarkdown else { return }
            lastMarkdown = markdown
            work?.cancel()
            let item = DispatchWorkItem { [weak self, weak web] in
                guard let self, let web else { return }
                let body = MarkdownRenderer.html(from: markdown)
                if self.ready { self.push(body, to: web) } else { self.pending = body }
            }
            work = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        private func push(_ body: String, to web: WKWebView) {
            guard let data = try? JSONEncoder().encode(body), let json = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("__update(\(json))")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if let p = pending { pending = nil; push(p, to: webView) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

/// Export to HTML or PDF, and printing, via an offscreen web view.
@MainActor
final class Exporter: NSObject, WKNavigationDelegate {
    static var active: Exporter?

    private let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000))
    private var completion: ((WKWebView) -> Void)?

    static func html(for markdown: String, url: URL?, accent: NSColor) -> String {
        MarkdownRenderer.page(title: url?.deletingPathExtension().lastPathComponent ?? "Document",
                              body: MarkdownRenderer.html(from: markdown),
                              baseURL: url?.deletingLastPathComponent(), accentHex: accent.hexString)
    }

    static func exportHTML(markdown: String, url: URL?, accent: NSColor) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (url?.deletingPathExtension().lastPathComponent ?? "Document") + ".html"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        // Exported files shouldn't depend on a <base> pointing at the author's disk.
        let html = MarkdownRenderer.page(title: url?.deletingPathExtension().lastPathComponent ?? "Document",
                                         body: MarkdownRenderer.html(from: markdown), baseURL: nil, accentHex: accent.hexString)
        try? html.write(to: dest, atomically: true, encoding: .utf8)
    }

    static func exportPDF(markdown: String, url: URL?, accent: NSColor) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (url?.deletingPathExtension().lastPathComponent ?? "Document") + ".pdf"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        run(markdown: markdown, url: url, accent: accent) { web in
            let info = NSPrintInfo.shared.copy() as! NSPrintInfo
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = dest
            printWith(web, info: info, showPanels: false)
        }
    }

    static func print(markdown: String, url: URL?, accent: NSColor) {
        run(markdown: markdown, url: url, accent: accent) { web in
            printWith(web, info: NSPrintInfo.shared.copy() as! NSPrintInfo, showPanels: true)
        }
    }

    private static func printWith(_ web: WKWebView, info: NSPrintInfo, showPanels: Bool) {
        info.topMargin = 48; info.bottomMargin = 48; info.leftMargin = 48; info.rightMargin = 48
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        let op = web.printOperation(with: info)
        op.showsPrintPanel = showPanels
        op.showsProgressPanel = showPanels
        op.view?.frame = web.bounds
        if let window = NSApp.keyWindow {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { if active?.web === web { active = nil } }
    }

    private static func run(markdown: String, url: URL?, accent: NSColor, then: @escaping (WKWebView) -> Void) {
        let exporter = Exporter()
        active = exporter
        exporter.completion = then
        exporter.web.navigationDelegate = exporter
        let html = MarkdownRenderer.page(title: url?.deletingPathExtension().lastPathComponent ?? "Document",
                                         body: MarkdownRenderer.html(from: markdown),
                                         baseURL: url?.deletingLastPathComponent(), accentHex: accent.hexString)
            // Always print in light mode.
            .replacingOccurrences(of: "color-scheme: light dark;", with: "color-scheme: light;")
            .replacingOccurrences(of: "@media (prefers-color-scheme: dark)", with: "@media not all")
            .replacingOccurrences(of: "media=\"(prefers-color-scheme: dark)\"", with: "media=\"not all\"")
            .replacingOccurrences(of: "media=\"(prefers-color-scheme: light)\"", with: "")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("markly-export.html")
        try? html.write(to: tmp, atomically: true, encoding: .utf8)
        exporter.web.appearance = NSAppearance(named: .aqua)
        exporter.web.loadFileURL(tmp, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            // Give KaTeX and highlight.js a moment to run.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                completion?(web)
                completion = nil
            }
        }
    }
}
