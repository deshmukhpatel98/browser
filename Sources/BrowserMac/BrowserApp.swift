import AppKit
import BrowserCore
import SwiftUI
import WebKit

@main
struct BrowserApp: App {
    @StateObject private var store = BrowserStore()

    init() {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--export-icon"), flag + 1 < args.count {
            IconExport.write(to: args[flag + 1])
            exit(0)
        }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Browser") {
            BrowserWindow()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
                .tint(Theme.accent)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { store.newTab() }.keyboardShortcut("t")
                Button("Close Tab") { if let tab = store.selected { store.close(tab) } }.keyboardShortcut("w")
                Button("Reload") { store.selected?.webView.reload() }.keyboardShortcut("r")
                Button("Toggle Agent") { store.showAgent.toggle() }.keyboardShortcut("j")
            }
        }
    }
}

struct BrowserWindow: View {
    @EnvironmentObject var store: BrowserStore

    var body: some View {
        VStack(spacing: 0) {
            if let tab = store.selected {
                TopBar(tab: tab).id(tab.id).zIndex(1)
                if store.tabs.count > 1 { TabStrip() }
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 0) {
                    PageArea(tab: tab).id(tab.id)
                    if store.showAgent {
                        Rectangle().fill(Theme.line).frame(width: 1)
                        AgentPanel(agent: store.agent).frame(width: 360)
                    }
                }
            }
        }
        .background(Theme.chrome)
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowSetup())
    }
}

struct TopBar: View {
    @EnvironmentObject var store: BrowserStore
    @ObservedObject var tab: BrowserTab

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 76)
            IconButton(symbol: "chevron.left", help: "Back") { tab.webView.goBack() }
                .disabled(!tab.canGoBack)
            IconButton(symbol: "chevron.right", help: "Forward") { tab.webView.goForward() }
                .disabled(!tab.canGoForward)
            Spacer(minLength: 12)
            // A new tab shows the big bar in the page, so the small one steps aside.
            if tab.url != nil { Omnibox(tab: tab).frame(maxWidth: 560) }
            Spacer(minLength: 12)
            IconButton(symbol: "plus", help: "New tab") { store.newTab() }
            IconButton(symbol: "sparkles", help: "Show or hide the agent", active: store.showAgent) {
                store.showAgent.toggle()
            }
        }
        .padding(.trailing, 12)
        .frame(height: 52)
    }
}

struct TabStrip: View {
    @EnvironmentObject var store: BrowserStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(store.tabs) { tab in
                TabChip(tab: tab, isSelected: tab.id == store.selectedID)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

struct TabChip: View {
    @EnvironmentObject var store: BrowserStore
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Text(tab.title)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 26)
            HStack {
                if hovering {
                    Button { store.close(tab) } label: {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            .frame(width: 16, height: 16)
                            .background(Color.primary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(isSelected ? Theme.raised : Color.primary.opacity(hovering ? 0.05 : 0),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { store.selectedID = tab.id }
        .onHover { hovering = $0 }
    }
}

struct PageArea: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        ZStack {
            WebViewHost(webView: tab.webView)
            if tab.url == nil { StartPage(tab: tab) }
        }
    }
}

/// What a new tab shows: the mark and the one bar.
struct StartPage: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        VStack(spacing: 28) {
            LogoMark().frame(width: 72, height: 72)
            Omnibox(tab: tab, large: true).frame(maxWidth: 580)
        }
        .padding(40)
        .offset(y: -70)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel)
    }
}

struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
