import Foundation

/// What the one bar can do with what you typed: open a site, search, or
/// hand it to the agent. The first option is the one Return will pick.
public enum BarIntent: Hashable {
    case go(URL)
    case search
    case ask

    public static func options(for input: String) -> [BarIntent] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if let url = BrowserTab.address(for: text) { return [.go(url), .search, .ask] }
        return looksLikeTask(text) ? [.ask, .search] : [.search, .ask]
    }

    private static let taskWords: Set<String> = [
        "add", "book", "buy", "cancel", "check", "compare", "download", "draft", "explain", "fill",
        "find", "get", "list", "make", "open", "order", "pay", "post", "read", "reply", "schedule",
        "send", "show", "sign", "summarise", "summarize", "tell", "track", "write",
    ]

    /// A request reads like an instruction; a search reads like a few keywords.
    static func looksLikeTask(_ text: String) -> Bool {
        let words = text.lowercased().split(separator: " ")
        guard let first = words.first else { return false }
        if taskWords.contains(String(first)) { return true }
        if text.lowercased().contains("this page") || text.lowercased().contains("for me") { return true }
        return words.count >= 6
    }
}
