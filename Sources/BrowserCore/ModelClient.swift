import Foundation
import Security

/// Where the agent's model lives. Any server that speaks the common
/// chat-completions format works: a local model runner or a hosted one.
public struct ModelSettings: Equatable {
    public var baseURL: String
    public var model: String
    public var apiKey: String

    public static let defaultBaseURL = "http://localhost:11434/v1"

    public static func load() -> ModelSettings {
        let d = UserDefaults.standard
        return ModelSettings(
            baseURL: d.string(forKey: "model.baseURL") ?? defaultBaseURL,
            model: d.string(forKey: "model.name") ?? "",
            apiKey: Keychain.get("model.apiKey") ?? ""
        )
    }

    public func save() {
        let d = UserDefaults.standard
        d.set(baseURL, forKey: "model.baseURL")
        d.set(model, forKey: "model.name")
        Keychain.set("model.apiKey", apiKey)
    }

    public var isReady: Bool { !baseURL.isEmpty && !model.isEmpty }
}

public struct ModelMessage {
    public let role: String
    public let content: String
}

public enum ModelError: LocalizedError {
    case notConfigured
    case badURL
    case server(Int, String)
    case badReply

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "No model is set. Open Model settings and choose one."
        case .badURL: return "The model address is not a valid URL."
        case .server(let code, let body): return "The model server answered \(code): \(body.prefix(200))"
        case .badReply: return "The model's reply could not be read."
        }
    }
}

struct ModelClient {
    let settings: ModelSettings

    func complete(_ messages: [ModelMessage]) async throws -> String {
        guard settings.isReady else { throw ModelError.notConfigured }
        let base = settings.baseURL.hasSuffix("/") ? String(settings.baseURL.dropLast()) : settings.baseURL
        guard let url = URL(string: base + "/chat/completions") else { throw ModelError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.model,
            "temperature": 0,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ] as [String: Any])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ModelError.server(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw ModelError.badReply }
        return content
    }
}

/// The API key is kept in the system keychain, not in plain settings.
enum Keychain {
    private static let service = "browser.agent"

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ key: String, _ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
