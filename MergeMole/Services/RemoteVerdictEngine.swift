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

/// The wire protocol a `RemoteVerdictEngine` speaks. OpenAI Chat Completions covers
/// OpenAI and every OpenAI-compatible host (OpenRouter, Together, Ollama, LM
/// Studio…); Anthropic's native Messages API covers Claude. Chosen from the
/// provider preset in Settings.
enum RemoteAPIFormat: Sendable {
    case openAI
    case anthropic
}

/// Bring-your-own verdicts via a remote model — OpenAI-compatible Chat Completions
/// or Anthropic's native Messages API. The model returns JSON we map to a `Verdict`;
/// it plugs into the same `VerdictEngine` seam as the on-device engine, so nothing
/// downstream changes.
///
/// We don't constrain the response format (`response_format` / structured outputs) —
/// relying on the prompt + forgiving parsing keeps it compatible with the widest
/// range of endpoints.
struct RemoteVerdictEngine: VerdictEngine {
    let endpoint: String
    let model: String
    let apiKey: String
    let format: RemoteAPIFormat

    func verdict(for pr: PullRequest) async throws -> Verdict {
        let input = VerdictInput(pr)
        let content = try await complete(system: Self.systemPrompt, user: input.promptText)
        // The deterministic floor can only raise the model's call, never lower it.
        return try Self.parseVerdict(content).raisingPriority(toAtLeast: input.priorityFloor)
    }

    /// Lightweight reachability/auth/model check for the Settings "Verify" button.
    func validate() async throws {
        _ = try await complete(system: nil, user: "Reply with the word OK.", maxTokens: 5)
    }

    /// The model IDs the endpoint advertises (`GET /v1/models`). OpenAI-compatible
    /// hosts and Anthropic both answer with `{ "data": [{ "id": … }] }`, so one path
    /// serves both — only the auth header differs. Populates the Settings model picker.
    func availableModels() async throws -> [String] {
        guard let url = Self.appending("/models", to: endpoint) else { throw RemoteModelError.notConfigured }
        var request = URLRequest(url: url)
        applyAuth(to: &request)
        let data = try await send(request)
        return Self.modelIDs(from: data)
    }

    // MARK: HTTP

    private func complete(system: String?, user: String, maxTokens: Int? = nil) async throws -> String {
        switch format {
        case .openAI:    return try await completeOpenAI(system: system, user: user, maxTokens: maxTokens)
        case .anthropic: return try await completeAnthropic(system: system, user: user, maxTokens: maxTokens)
        }
    }

    /// OpenAI Chat Completions: `/chat/completions`, bearer auth, `choices[].message.content`.
    /// We send only `model` + `messages` — no `temperature`, no token cap. Newer
    /// OpenAI models reject both (`temperature` must stay default, and `max_tokens`
    /// was replaced by `max_completion_tokens`), while omitting them is accepted by
    /// every OpenAI-compatible host, so the bare request is the most portable one.
    /// `maxTokens` is ignored here; it only applies to the Anthropic path, where the
    /// API requires it.
    private func completeOpenAI(system: String?, user: String, maxTokens: Int?) async throws -> String {
        guard let url = Self.appending("/chat/completions", to: endpoint) else { throw RemoteModelError.notConfigured }

        var messages: [[String: String]] = []
        if let system { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": user])

        let body: [String: Any] = ["model": model, "messages": messages]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard let content = Self.openAIContent(from: data) else { throw RemoteModelError.badResponse }
        return content
    }

    /// Anthropic's native Messages API: `/messages`, `x-api-key` + `anthropic-version`,
    /// `system` is a top-level field, `max_tokens` is required, and the reply is
    /// `content[].text`. We omit `temperature` so the call stays valid across every
    /// Claude model (the newest ones reject sampling params).
    private func completeAnthropic(system: String?, user: String, maxTokens: Int?) async throws -> String {
        guard let url = Self.appending("/messages", to: endpoint) else { throw RemoteModelError.notConfigured }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens ?? 1024,
            "messages": [["role": "user", "content": user]],
        ]
        if let system { body["system"] = system }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard let content = Self.anthropicContent(from: data) else { throw RemoteModelError.badResponse }
        return content
    }

    /// Shared transport: fire the request, map connection failures to `.network`,
    /// and turn any non-200 into `.http` carrying the endpoint's own message.
    private func send(_ request: URLRequest) async throws -> Data {
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
        return data
    }

    /// Auth + version headers for the active format. OpenAI uses a bearer token;
    /// Anthropic uses `x-api-key` and requires `anthropic-version`.
    private func applyAuth(to request: inout URLRequest) {
        switch format {
        case .openAI:
            if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        case .anthropic:
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            if !apiKey.isEmpty { request.setValue(apiKey, forHTTPHeaderField: "x-api-key") }
        }
    }

    // MARK: URL

    /// Treat the input as a base URL and append `path`, unless the user already gave
    /// the full path. Handles trailing slashes.
    private static func appending(_ path: String, to endpoint: String) -> URL? {
        var base = endpoint.trimmingCharacters(in: .whitespaces)
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty else { return nil }
        let full = base.hasSuffix(path) ? base : base + path
        return URL(string: full)
    }

    // MARK: Response parsing

    private static func openAIContent(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { return nil }
        return content
    }

    private static func anthropicContent(from data: Data) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let blocks = root["content"] as? [[String: Any]]
        else { return nil }
        // Concatenate the text blocks (usually a single one).
        let text = blocks
            .compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }
            .joined()
        return text.isEmpty ? nil : text
    }

    private static func modelIDs(from data: Data) -> [String] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let entries = root["data"] as? [[String: Any]]
        else { return [] }
        return entries.compactMap { $0["id"] as? String }
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

    /// The shared behavioural spec (`VerdictGuidance`, identical to the on-device
    /// engine so verdicts read the same across backends) plus a remote-only
    /// JSON-format instruction — the on-device engine uses guided generation, so the
    /// format ask belongs here, not in the shared prompt. The allowed priority values
    /// come straight from the enum, so the prompt and parser can't drift.
    private static let systemPrompt = VerdictGuidance.systemPrompt + "\n\n" + """
    Respond with ONLY a JSON object and no other text: {"priority": "<\(Priority.wireList)>", \
    "summary": "<the summary line>", "rationale": "<the review line>"}
    """
}
