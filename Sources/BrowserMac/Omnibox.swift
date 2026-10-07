import BrowserCore
import SwiftUI

/// The one bar: address, search and agent in a single box.
/// Small in the top bar, large on a new tab.
struct Omnibox: View {
    @EnvironmentObject var store: BrowserStore
    @ObservedObject var tab: BrowserTab
    var large = false

    // BROWSER_DEMO_TEXT pre-fills the bar, for checking the look without typing.
    @State private var text = ProcessInfo.processInfo.environment["BROWSER_DEMO_TEXT"] ?? ""
    @State private var picked = 0
    @FocusState private var focused: Bool

    private var options: [BarIntent] { BarIntent.options(for: text) }
    private var height: CGFloat { large ? 50 : 30 }
    private var radius: CGFloat { large ? 14 : 9 }

    var body: some View {
        bar
            .overlay(alignment: .top) {
                if focused && !options.isEmpty {
                    choices.offset(y: height + 6)
                }
            }
            .onChange(of: text) { _, _ in picked = 0 }
            .task {
                // Focus once the window is ready, so a new tab is ready to type in.
                guard large else { return }
                try? await Task.sleep(nanoseconds: 200_000_000)
                focused = true
            }
    }

    private var bar: some View {
        ZStack {
            HStack(spacing: 10) {
                if large { Image(systemName: "magnifyingglass").foregroundStyle(.secondary) }
                TextField(large ? "Search, go to a site, or say what you want done" : "Search, go, or ask",
                          text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { if options.indices.contains(picked) { run(options[picked]) } }
                    .onKeyPress(.downArrow) { picked = min(picked + 1, options.count - 1); return .handled }
                    .onKeyPress(.upArrow) { picked = max(picked - 1, 0); return .handled }
                    .onKeyPress(.escape) { focused = false; return .handled }
            }
            .padding(.horizontal, large ? 16 : 12)
            .opacity(focused || large ? 1 : 0)

            if !focused && !large {
                HStack(spacing: 6) {
                    if tab.url?.scheme == "https" {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Text(tab.url?.host?.replacingOccurrences(of: "www.", with: "") ?? "Search, go, or ask")
                        .foregroundStyle(tab.url == nil ? .secondary : .primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    text = tab.url?.absoluteString ?? ""
                    focused = true
                }

                HStack {
                    Spacer()
                    if tab.url != nil {
                        IconButton(symbol: tab.isLoading ? "xmark" : "arrow.clockwise",
                                   help: tab.isLoading ? "Stop" : "Reload") {
                            if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
                        }
                        .scaleEffect(0.85)
                    }
                }
                .padding(.trailing, 2)
            }
        }
        .font(.system(size: large ? 15 : 13))
        .frame(height: height)
        .background(large ? Theme.raised : Theme.field, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Capsule().fill(Theme.accent)
                    .frame(width: geo.size.width * tab.progress, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(tab.isLoading ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: tab.progress)
            }
            .padding(.horizontal, 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(focused ? Theme.accent.opacity(0.7) : (large ? Theme.line : .clear), lineWidth: focused ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(large ? 0.06 : 0), radius: 12, y: 4)
    }

    private var choices: some View {
        VStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.element) { index, intent in
                HStack(spacing: 10) {
                    Image(systemName: icon(intent))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(intent == .ask ? Theme.accent : .secondary)
                        .frame(width: 18)
                    Text(title(intent)).lineLimit(1)
                    Spacer()
                    Text(kind(intent)).font(.system(size: 11)).foregroundStyle(.tertiary)
                    if index == picked {
                        Image(systemName: "return").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(index == picked ? Theme.field : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { run(intent) }
                .onHover { if $0 { picked = index } }
            }
        }
        .padding(5)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line) }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private func run(_ intent: BarIntent) {
        let typed = text
        text = ""
        focused = false
        store.perform(intent, typed)
    }

    private func icon(_ intent: BarIntent) -> String {
        switch intent {
        case .go: return "globe"
        case .search: return "magnifyingglass"
        case .ask: return "sparkles"
        }
    }

    private func title(_ intent: BarIntent) -> String {
        switch intent {
        case .go(let url): return url.host ?? url.absoluteString
        case .search, .ask: return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func kind(_ intent: BarIntent) -> String {
        switch intent {
        case .go: return "Open"
        case .search: return "Search"
        case .ask: return "Agent"
        }
    }
}
