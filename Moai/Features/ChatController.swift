import SwiftUI
import WebKit

/// Claude in the island: the real claude.ai session in a panel, no
/// API key. Sign in once; the login lives in the default website
/// data store and survives relaunches. The web view is created on
/// first use and kept alive so the conversation survives collapses.
@MainActor
final class ChatController: NSObject, ObservableObject {
    static let homeURL = URL(string: "https://claude.ai/new")!

    @Published private(set) var isLoading = true

    /// A quiet coat of Moai over claude.ai: pure black behind the
    /// chat so the card melts into the island, and slim scrollbars.
    /// Unknown selectors no-op harmlessly if the site changes.
    private static let blendCSS = "html,body{background:#000 !important}"
        + ":root{--bg-000:#000;--bg-100:#000}"
        + "::-webkit-scrollbar{width:6px;height:6px}"
        + "::-webkit-scrollbar-thumb{background:rgba(255,255,255,.14);border-radius:3px}"
        + "::-webkit-scrollbar-track,::-webkit-scrollbar-corner{background:transparent}"

    private(set) lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let styler = WKUserScript(
            source: "var s=document.createElement('style');"
                + "s.textContent=\"\(Self.blendCSS)\";"
                + "document.documentElement.appendChild(s);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(styler)
        let web = WKWebView(frame: .zero, configuration: configuration)
        // Trackpad swipes travel the chat history like a browser.
        web.allowsBackForwardNavigationGestures = true
        // Google's sign-in refuses embedded browsers by user agent;
        // Safari's own string keeps every login door open.
        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
            + " AppleWebKit/605.1.15 (KHTML, like Gecko)"
            + " Version/17.4 Safari/605.1.15"
        web.navigationDelegate = self
        web.uiDelegate = self
        // The pane is part of the island: dark, always.
        web.appearance = NSAppearance(named: .darkAqua)
        web.underPageBackgroundColor = .black
        web.load(URLRequest(url: Self.homeURL))
        return web
    }()

    func goHome() {
        webView.load(URLRequest(url: Self.homeURL))
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }
}

extension ChatController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        isLoading = false
    }
}

extension ChatController: WKUIDelegate {
    /// Login flows love popups; route them through the same view
    /// instead of asking a panel to spawn windows.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

/// The chat surface: claude.ai as a quiet rounded card inside the
/// island, with a shimmer while pages settle.
struct ChatPane: View {
    @ObservedObject var chat: ChatController
    @State private var hovered = false

    var body: some View {
        ZStack {
            ChatWebView(webView: chat.webView)
                .clipShape(RoundedRectangle(
                    cornerRadius: Theme.Radius.card, style: .continuous
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            if chat.isLoading {
                ThinkingDots()
                    .transition(.opacity)
            }
        }
        // A login page can dead-end with no way out; back and home
        // float in on hover so a stuck page is never a trap.
        .overlay(alignment: .topTrailing) {
            if hovered {
                HStack(spacing: Theme.Space.xs) {
                    HoverGlyphButton(
                        symbol: "chevron.left", scale: .s, tint: Theme.textSecondary
                    ) {
                        chat.goBack()
                    }
                    HoverGlyphButton(
                        symbol: "house", scale: .s, tint: Theme.textSecondary
                    ) {
                        chat.goHome()
                    }
                }
                .padding(Theme.Space.xs)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .padding(Theme.Space.s)
                .transition(.opacity)
            }
        }
        .onHover { hovered = $0 }
        .animation(Theme.Motion.hover, value: hovered)
        .animation(Theme.Motion.content, value: chat.isLoading)
    }
}

private struct ChatWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
