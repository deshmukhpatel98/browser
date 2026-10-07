import BrowserCore
import SwiftUI

struct AgentPanel: View {
    @EnvironmentObject var store: BrowserStore
    @ObservedObject var agent: AgentSession
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Text("Agent").font(.system(size: 13, weight: .semibold))
                if agent.isRunning {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                }
                Spacer()
                if agent.isRunning {
                    IconButton(symbol: "stop.fill", help: "Stop", active: true) { agent.stop() }
                } else {
                    IconButton(symbol: "trash", help: "Clear") { agent.clear() }
                        .disabled(agent.events.isEmpty)
                }
                IconButton(symbol: "slider.horizontal.3", help: "Model settings") { showSettings = true }
                    .popover(isPresented: $showSettings) { ModelSettingsView() }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 44)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if agent.events.isEmpty { emptyState }
                        ForEach(agent.events) { event in
                            EventRow(event: event).id(event.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .onChange(of: agent.events.count) { _, _ in
                    if let last = agent.events.last {
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let approval = agent.pendingApproval {
                ApprovalCard(approval: approval, agent: agent)
            }
        }
        .background(Theme.panel)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.settings.isReady ? "Nothing running" : "Connect a model to start")
                .font(.system(size: 15, weight: .medium))
            Text(store.settings.isReady
                 ? "Type what you want done in the bar. I ask before I buy, send, post or delete anything."
                 : "Open the settings above and choose the model the agent should use.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }
}

struct ApprovalCard: View {
    let approval: PendingApproval
    let agent: AgentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Needs your OK", systemImage: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(approval.summary).font(.system(size: 13))
            HStack {
                Spacer()
                Button("Cancel") { agent.answer(false) }
                Button("Approve") { agent.answer(true) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.accent.opacity(0.35)) }
        .padding(.horizontal, 12)
    }
}

struct EventRow: View {
    let event: AgentEvent

    var body: some View {
        switch event.kind {
        case .user:
            Text(event.text)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .thought:
            Text(event.text).font(.system(size: 12)).foregroundStyle(.secondary)
        case .action:
            HStack(spacing: 8) {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text(event.text).font(.system(size: 12, weight: .medium)).lineLimit(2)
            }
        case .result:
            Text(event.text).font(.system(size: 13)).textSelection(.enabled)
        case .error:
            Label(event.text, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
    }
}

struct ModelSettingsView: View {
    @EnvironmentObject var store: BrowserStore
    @State private var draft = ModelSettings.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model").font(.headline)
            field("Server address", text: $draft.baseURL)
            field("Model name", text: $draft.model)
            VStack(alignment: .leading, spacing: 4) {
                Text("API key").font(.caption).foregroundStyle(.secondary)
                SecureField("Leave blank for a local model", text: $draft.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            Text("Use a model running on this Mac, or any service that uses the standard chat format. The key is kept in your keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Save") {
                    draft.save()
                    store.settings = draft
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft == store.settings)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }
}
