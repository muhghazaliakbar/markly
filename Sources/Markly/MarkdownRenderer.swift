import Foundation
import Markdown

enum MarkdownRenderer {
    /// Renders Markdown to HTML. Each top-level block's opening tag carries `data-line` / `data-end`
    /// (1-based source lines) so the preview can scroll to whatever the editor is showing.
    static func html(from markdown: String) -> String {
        let document = Document(parsing: markdown)
        let body = document.children.map { block -> String in
            let html = HTMLFormatter.format(block)
            guard let range = block.range else { return html }
            return annotate(html, start: range.lowerBound.line, end: range.upperBound.line)
        }.joined()
        // swift-markdown doesn't know ==highlight==; convert it outside of code.
        return body.replacingOccurrences(of: #"==(?=\S)(.+?)(?<=\S)=="#, with: "<mark>$1</mark>", options: .regularExpression)
    }

    private static let firstTag = try! NSRegularExpression(pattern: #"^\s*<([A-Za-z][A-Za-z0-9]*)"#)

    /// Adds the source line attributes to the block's first element (skips raw HTML comments and text).
    static func annotate(_ html: String, start: Int, end: Int) -> String {
        let ns = html as NSString
        guard let m = firstTag.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { return html }
        return ns.replacingCharacters(in: NSRange(location: NSMaxRange(m.range), length: 0),
                                      with: " data-line=\"\(start)\" data-end=\"\(end)\"")
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
    \(syncScript)
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
    \(syncScript)
    </script>
    """

    /// Keeps the preview on the part of the note the editor is showing.
    ///
    /// `pos` is a fractional 1-based source line (12.4 = 40% of the way through line 12, which matters for
    /// long wrapped paragraphs); `ratio` is where that spot sits in the editor's viewport. The page doesn't jump
    /// there: a requestAnimationFrame follower eases toward the target every display frame with a
    /// frame-rate–independent exponential curve, so continuous scrolling tracks smoothly and jumps glide.
    /// Scrolling the preview by hand hands control back to the reader until the editor moves again.
    static let syncScript = """
    let __syncTarget = null, __syncFrame = 0, __syncLast = 0, __syncGlide = false;
    function __syncDest(pos, ratio) {
      const blocks = document.querySelectorAll("#content > [data-line]");
      if (!blocks.length) return 0;
      let cur = null, next = null;
      for (const el of blocks) {
        if (+el.dataset.line <= pos) cur = el; else { next = el; break; }
      }
      let y = 0;
      if (cur) {
        const start = +cur.dataset.line, end = Math.max(start, +cur.dataset.end) + 1;  // block covers [start, end)
        const top = cur.getBoundingClientRect().top + window.scrollY, h = cur.offsetHeight;
        if (pos >= end && next) {
          const nextTop = next.getBoundingClientRect().top + window.scrollY;
          y = top + h + (nextTop - top - h) * Math.min(1, (pos - end) / Math.max(1, +next.dataset.line - end));
        } else {
          y = top + h * Math.min(1, (pos - start) / (end - start));
        }
      }
      // At (or above) the start of the first block, show the very top of the page, padding included.
      const firstTop = blocks[0].getBoundingClientRect().top + window.scrollY;
      if (y <= firstTop + 0.5) return 0;
      const max = document.documentElement.scrollHeight - window.innerHeight;
      return Math.min(Math.max(0, y - ratio * window.innerHeight), Math.max(0, max));
    }
    function __syncStep(now) {
      const dt = Math.min(50, now - __syncLast);
      __syncLast = now;
      const current = window.scrollY, diff = __syncTarget - current;
      if (Math.abs(diff) < 0.5) {
        window.scrollTo(0, __syncTarget);
        __syncFrame = 0;
        return;
      }
      const tau = __syncGlide ? 110 : 55;  // ms: gentle glide for jumps, tight follow while scrolling
      window.scrollTo(0, current + diff * (1 - Math.exp(-dt / tau)));
      __syncFrame = requestAnimationFrame(__syncStep);
    }
    function __syncLine(pos, ratio, glide, immediate) {
      __syncTarget = __syncDest(pos, ratio);
      __syncGlide = glide;
      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (immediate || reduce || document.hidden) {
        if (__syncFrame) { cancelAnimationFrame(__syncFrame); __syncFrame = 0; }
        window.scrollTo(0, __syncTarget);
        return;
      }
      if (!__syncFrame) {
        __syncLast = performance.now();
        __syncFrame = requestAnimationFrame(__syncStep);
      }
    }
    // The reader scrolling the preview themselves wins over the follower…
    let __readerAt = -1e9, __reportFrame = 0;
    for (const type of ["wheel", "keydown", "pointerdown", "touchstart"]) {
      window.addEventListener(type, () => {
        __readerAt = performance.now();
        if (__syncFrame) { cancelAnimationFrame(__syncFrame); __syncFrame = 0; }
      }, { passive: true });
    }
    // …and the editor follows them. Only scrolling that comes from the reader (wheel and trackpad, including
    // momentum, keys, clicks) is reported; the follower's own scrolling is not, so the two never feed back.
    window.addEventListener("scroll", () => {
      if (performance.now() - __readerAt > 600 || __reportFrame) return;
      __reportFrame = requestAnimationFrame(() => {
        __reportFrame = 0;
        const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.markly;
        if (!handler) return;
        const max = document.documentElement.scrollHeight - window.innerHeight;
        handler.postMessage({ pos: __sourceAt(window.scrollY), atTop: window.scrollY <= 0.5, atEnd: window.scrollY >= max - 0.5 });
      });
    }, { passive: true });
    /// The fractional source line at page offset `y` — the inverse of __syncDest.
    function __sourceAt(y) {
      const blocks = document.querySelectorAll("#content > [data-line]");
      if (!blocks.length) return 1;
      let cur = null, next = null;
      for (const el of blocks) {
        if (el.getBoundingClientRect().top + window.scrollY <= y + 0.5) cur = el; else { next = el; break; }
      }
      if (!cur) return 1;
      const start = +cur.dataset.line, end = Math.max(start, +cur.dataset.end) + 1;
      const top = cur.getBoundingClientRect().top + window.scrollY, h = cur.offsetHeight;
      if (y < top + h) return start + (end - start) * Math.max(0, (y - top) / Math.max(1, h));
      if (!next) return end;
      const nextTop = next.getBoundingClientRect().top + window.scrollY;
      return end + (+next.dataset.line - end) * Math.min(1, (y - top - h) / Math.max(1, nextTop - top - h));
    }
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
