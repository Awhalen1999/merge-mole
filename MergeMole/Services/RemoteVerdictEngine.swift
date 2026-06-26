import Foundation

enum RemoteModelError: LocalizedError {
    case notConfigured
    case network
    case http(Int, String?)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Enter an endpoint and model first."
        case .network:       return "Couldn't reach the endpoint. Check the URL and your connection."
        case .http(let code, let message):
            if let message, !message.isEmpty { return "Endpoint error (HTTP \(code)): \(message)" }
            return "Endpoint returned an error (HTTP \(code))."
        case .badResponse:   return "The endpoint's reply wasn't in the expected format."
        }
    }
}

/// Bring-your-own verdicts via any OpenAI-compatible Chat Completions endpoint —
/// hosted (OpenAI, OpenRouter, Together…) or local (Ollama, LM Studio). The model
/// returns JSON we map to a `Verdict`; it plugs into the same `VerdictEngine` seam
/// as the on-device engine, so nothing downstream changes.
///
/// We don't send `response_format` — relying on the prompt + forgiving parsing
/// keeps it compatible with the widest range of endpoints.
struct RemoteVerdictEngine: VerdictEngine {
    let endpoint: String
    let model: String
    let apiKey: String

    func verdict(for pr: PullRequest) async throws -> Verdict {
        let content = try await complete(system: Self.instructions, user: VerdictInput(pr).promptText)
        return try Self.parseVerdict(content)
    }

    /// Lightweight reachability/auth/model check for the Settings "Verify" button.
    func validate() async throws {
        _ = try await complete(system: nil, user: "Reply with the word OK.", maxTokens: 5)
    }

    // MARK: HTTP

    private func complete(system: String?, user: String, maxTokens: Int? = nil) async throws -> String {
        guard let url = Self.completionsURL(from: endpoint) else { throw RemoteModelError.notConfigured }

        var messages: [[String: String]] = []
        if let system { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": user])

        var body: [String: Any] = ["model": model, "messages": messages, "temperature": 0.3]
        if let maxTokens { body["max_tokens"] = maxTokens }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RemoteModelError.network
        }

        guard let http = response as? HTTPURLResponse else { throw RemoteModelError.network }
        guard http.statusCode == 200 else {
            throw RemoteModelError.http(http.statusCode, Self.errorMessage(from: data))
        }
        guard let content = Self.content(from: data) else { throw RemoteModelError.badResponse }
        return content
    }

    // MARK: URL

    /// Treat the input as a base URL and append the chat-completions path, unless
    /// the user already gave the full path. Handles trailing slashes.
    private static func completionsURL(from endpoint: String) -> URL? {
        var base = endpoint.trimmingCharacters(in: .whitespaces)
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty else { return nil }
        let full = base.hasSuffix("/chat/completions") ? base : base + "/chat/completions"
        return URL(string: full)
    }

    // MARK: Response parsing

    private static func content(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { return nil }
        return content
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let error = root["error"] as? [String: Any] { return error["message"] as? String }
        return (root["error"] as? String) ?? (root["message"] as? String)
    }

    private static func parseVerdict(_ content: String) throws -> Verdict {
        // Forgiving: pull the first {...} block, in case the model wrapped it in
        // prose or markdown fences.
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start < end,
              let object = (try? JSONSerialization.jsonObject(with: Data(content[start...end].utf8))) as? [String: Any]
        else { throw RemoteModelError.badResponse }

        let summary = (object["summary"] as? String) ?? ""
        guard !summary.isEmpty else { throw RemoteModelError.badResponse }

        // The allowed tokens (and their fallback) live on the enum — see
        // `Priority.init(wire:)`.
        return Verdict(
            priority: Priority(wire: object["priority"] as? String),
            summary: summary,
            rationale: (object["rationale"] as? String) ?? ""
        )
    }

    // MARK: Prompt

    /// The allowed-value lists come straight from the enums, so the prompt and the
    /// parser can't disagree about the vocabulary. The summary guidance matches the
    /// on-device engine's, so verdicts read the same regardless of backend.
    private static let instructions = """
    You triage GitHub pull requests for a busy reviewer. Respond with ONLY a JSON \
    object and no other text: {"priority": one of \(Priority.wireList), "summary": \
    what the PR does in one concrete line of at most 14 words (start with a verb, no \
    "This PR" preamble, don't just repeat the title), "rationale": one short clause \
    giving the main reason for the priority call}. Be specific; never invent details \
    the input doesn't support.
    """
}
