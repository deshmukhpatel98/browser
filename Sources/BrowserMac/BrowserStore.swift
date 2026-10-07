import BrowserCore
import Foundation

@MainActor
final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?
    @Published var showAgent = false
    @Published var settings = ModelSettings.load()

    let agent = AgentSession()

    var selected: BrowserTab? { tabs.first { $0.id == selectedID } }

    init() {
        // A web address given at launch opens straight away.
        let address = CommandLine.arguments.dropFirst().first { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        newTab(address.flatMap(URL.init(string:)))
    }

    func newTab(_ url: URL? = nil) {
        let tab = BrowserTab()
        tabs.append(tab)
        selectedID = tab.id
        if let url { tab.load(url) }
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            newTab()
        } else if selectedID == tab.id {
            selectedID = tabs[min(index, tabs.count - 1)].id
        }
    }

    /// Everything typed into the bar ends up here.
    func perform(_ intent: BarIntent, _ text: String) {
        switch intent {
        case .go(let url):
            selected?.load(url)
        case .search:
            selected?.load(BrowserTab.search(for: text))
        case .ask:
            showAgent = true
            runAgent(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func runAgent(_ goal: String) {
        guard let tab = selected else { return }
        agent.start(goal, in: tab, settings: settings)
    }
}
