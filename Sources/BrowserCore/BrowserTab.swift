import Foundation
import WebKit

/// One open page. Uses the engine that ships with the device, so the app
/// stays small and starts fast on every Apple platform.
@MainActor
public final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    public let id = UUID()
    public let webView: WKWebView

    @Published public var title = "New Tab"
    @Published public var url: URL?
    @Published public var isLoading = false
    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var progress = 0.0

    private var observers: [NSKeyValueObservation] = []

    public override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // Identify as a normal Safari-family browser so sites serve their full pages.
        config.applicationNameForUserAgent = "Version/26.0 Safari/605.1.15"
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        observers = [
            webView.observe(\.title) { [weak self] view, _ in
                Task { @MainActor in
                    let title = view.title ?? ""
                    self?.title = title.isEmpty ? "New Tab" : title
                }
            },
            webView.observe(\.url) { [weak self] view, _ in
                Task { @MainActor in self?.url = view.url }
            },
            webView.observe(\.isLoading) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.estimatedProgress) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
        ]
    }

    public func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Turns what the user typed into a web address, or a search.
    public nonisolated static func destination(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return address(for: text) ?? search(for: text)
    }

    /// A web address, only if the text really looks like one.
    public nonisolated static func address(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if text.contains("://") { return URL(string: text) }
        if text.hasPrefix("localhost") { return URL(string: "http://" + text) }
        if text.contains("."), !text.hasSuffix(".") { return URL(string: "https://" + text) }
        return nil
    }

    public nonisolated static func search(for input: String) -> URL {
        var search = URLComponents(string: "https://duckduckgo.com/")!
        search.queryItems = [URLQueryItem(name: "q", value: input.trimmingCharacters(in: .whitespacesAndNewlines))]
        return search.url!
    }

    /// Runs a script in the agent's private world and returns its result.
    func run(_ script: String, _ arguments: [String: Any] = [:]) async throws -> Any? {
        try await webView.callAsyncJavaScript(script, arguments: arguments, in: nil, contentWorld: .defaultClient)
    }

    /// Waits until the page has stopped loading, within a limit.
    func settle() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
        var waited = 0.0
        while webView.isLoading && waited < 8 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            waited += 0.15
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    // Links that want a new window open in this tab instead.
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
