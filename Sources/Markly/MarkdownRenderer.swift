import Foundation
import Markdown

enum MarkdownRenderer {
    static func html(from markdown: String) -> String {
        // swift-markdown doesn't know ==highlight==; convert it outside of code.
        let body = HTMLFormatter.format(Document(parsing: markdown))
        return body.replacingOccurrences(of: #"==(?=\S)(.+?)(?<=\S)=="#, with: "<mark>$1</mark>", options: .regularExpression)
    }

    static let css = """
    :root { color-scheme: light dark; --accent: #0a84ff; --fg: #1d1d1f; --muted: #6e6e73; --border: rgba(0,0,0,.12); --code: rgba(0,0,0,.045); --bg: #fff; }
    @media (prefers-color-scheme: dark) { :root { --fg: #f5f5f7; --muted: #a1a1a6; --border: rgba(255,255,255,.14); --code: rgba(255,255,255,.07); --bg: #1e1e1e; } }
    html { background: var(--bg); }
    body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: var(--fg); max-width: 760px; margin: 0 auto; padding: 36px 28px 80px; -webkit-font-smoothing: antialiased; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 .5em; }
    h1 { font-size: 1.9em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em; }
    h1:first-child, h2:first-child { margin-top: 0; }
    a { color: var(--accent); text-decoration: none; } a:hover { text-decoration: underline; }
    p, ul, ol, blockquote, pre, table { margin: 0 0 1em; }
    img { max-width: 100%; border-radius: 6px; }
    code { font: .9em ui-monospace, "SF Mono", Menlo, monospace; background: var(--code); padding: .15em .35em; border-radius: 5px; }
    pre { background: var(--code); padding: 14px 16px; border-radius: 10px; overflow-x: auto; }
    pre code, pre code.hljs { background: none; padding: 0; font-size: .88em; line-height: 1.5; }
    blockquote { margin-left: 0; padding: 0 1em; border-left: 3px solid var(--accent); color: var(--muted); }
    hr { border: 0; border-top: 1px solid var(--border); margin: 2em 0; }
    table { border-collapse: collapse; display: block; overflow-x: auto; }
    th, td { border: 1px solid var(--border); padding: 6px 12px; }
    th { background: var(--code); text-align: left; }
    li > p { margin: 0; }
    li:has(> input[type=checkbox]) { list-style: none; margin-left: -1.3em; }
    li:has(> input[type=checkbox]) > p { display: inline; }
    li:has(> input[checked]) { color: var(--muted); text-decoration: line-through; }
    input[type=checkbox] { accent-color: var(--accent); margin-right: .45em; }
    mark { background: rgba(255, 214, 10, .4); color: inherit; border-radius: 3px; padding: 0 .1em; }
    del { color: var(--muted); }
    .katex-display { overflow-x: auto; overflow-y: hidden; }
    @media print { body { max-width: none; padding: 0; } pre { white-space: pre-wrap; } }
    """

    static let scripts = """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
    <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
    <link rel="stylesheet" media="(prefers-color-scheme: light)" href="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.10.0/styles/github.min.css">
    <link rel="stylesheet" media="(prefers-color-scheme: dark)" href="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.10.0/styles/github-dark.min.css">
    <script src="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11.10.0/highlight.min.js"></script>
    <script>
    function __enhance() {
      try { renderMathInElement(document.body, { delimiters: [
        {left: "$$", right: "$$", display: true}, {left: "$", right: "$", display: false}
      ], ignoredTags: ["script","noscript","style","textarea","pre","code"], throwOnError: false }); } catch (e) {}
      try { document.querySelectorAll("pre code").forEach(el => hljs.highlightElement(el)); } catch (e) {}
    }
    function __update(html) { document.getElementById("content").innerHTML = html; __enhance(); }
    window.addEventListener("load", __enhance);
    \(swapScript)
    </script>
    """

    /// Content-Security-Policy for rendered pages. It is the enforcement point for the Privacy settings:
    /// with network scripts off, nothing but inline code runs; with remote images off, only local files load.
    static func contentSecurityPolicy(network: Bool, remoteImages: Bool) -> String {
        let cdn = network ? " https://cdn.jsdelivr.net" : ""
        let images = remoteImages ? " https: http:" : ""
        return "default-src 'none'; script-src 'unsafe-inline'\(cdn); style-src 'unsafe-inline'\(cdn); "
            + "font-src\(cdn) data:; img-src file: data:\(images); media-src file:\(images)"
    }

    /// Without network access: just the update hook, no math typesetting or code colouring.
    static let localScripts = """
    <script>
    function __enhance() {}
    function __update(html) { document.getElementById("content").innerHTML = html; }
    \(swapScript)
    </script>
    """

    /// Switches the page to another note without reloading, with the same motion as the editor: the old page
    /// fades and lifts 10 pt while the new one settles up from 10 pt below, 260 ms, same curve.
    static let swapScript = """
    function __swap(html, base, title, animate) {
      let b = document.querySelector("base");
      if (base) { if (!b) { b = document.createElement("base"); document.head.prepend(b); } b.href = base; }
      document.title = title;
      const old = document.getElementById("content");
      const next = old.cloneNode(false);
      next.innerHTML = html;
      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (!animate || reduce) {
        old.replaceWith(next);
        window.scrollTo(0, 0);
        __enhance();
        return;
      }
      // Freeze the old page exactly where it is, then lay the new one out underneath it.
      const r = old.getBoundingClientRect();
      old.removeAttribute("id");
      old.style.cssText = "position:fixed;margin:0;pointer-events:none;top:" + r.top + "px;left:" + r.left +
        "px;width:" + r.width + "px";
      old.parentNode.insertBefore(next, old);
      window.scrollTo(0, 0);
      __enhance();  // math and code are typeset before anything moves
      const timing = { duration: 260, easing: "cubic-bezier(0.2, 0.8, 0.2, 1)", fill: "both" };
      old.animate([{ opacity: 1, transform: "translateY(0)" }, { opacity: 0, transform: "translateY(-10px)" }], timing)
        .onfinish = () => old.remove();
      // WebKit pauses animations on hidden pages (e.g. a minimised window); never leave the old page behind.
      setTimeout(() => old.remove(), timing.duration + 60);
      next.animate([{ opacity: 0, transform: "translateY(10px)" }, { opacity: 1, transform: "translateY(0)" }], timing);
    }
    """

    /// A standalone document, used for the live preview and for export.
    static func page(title: String, body: String, baseURL: URL?, accentHex: String) -> String {
        let base = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
        let network = Pref.bool(Pref.previewNetwork, default: true)
        let csp = contentSecurityPolicy(network: network, remoteImages: Pref.bool(Pref.remoteImages, default: true))
        return """
        <!doctype html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="\(csp)">
        <title>\(escape(title))</title>\(base)
        <style>\(css) :root { --accent: \(accentHex); }</style>
        \(network ? scripts : localScripts)
        </head><body><article id="content">\(body)</article></body></html>
        """
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}
