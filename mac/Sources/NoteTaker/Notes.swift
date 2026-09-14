import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case groq, gemini, openrouter, ollama

    var id: String { rawValue }

    var label: String {
        switch self {
        case .groq: return "Groq (free key)"
        case .gemini: return "Google Gemini (free key)"
        case .openrouter: return "OpenRouter (free models)"
        case .ollama: return "Ollama (local, no key)"
        }
    }

    var model: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .gemini: return "gemini-2.0-flash"
        case .openrouter: return "meta-llama/llama-3.3-70b-instruct:free"
        case .ollama: return "llama3.1"
        }
    }

    var url: URL {
        switch self {
        case .groq: return URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .ollama: return URL(string: "http://localhost:11434/v1/chat/completions")!
        }
    }

    var hint: String {
        switch self {
        case .groq: return "Free key: console.groq.com/keys"
        case .gemini: return "Free key: aistudio.google.com/apikey"
        case .openrouter: return "Free key: openrouter.ai/keys — model is a :free one"
        case .ollama: return "Fully local. Run: OLLAMA_ORIGINS=* ollama serve — only works when this page is on http://localhost"
        }
    }

    var needsKey: Bool { self != .ollama }
}

enum NotesClient {
    private static let prompt = """
    You are taking notes for a student during a lecture. Below is a raw, unpunctuated speech-to-text transcript that may contain recognition errors — infer the intended words.

    Write clear lecture notes in markdown:
    - A "## Summary" of 2-3 sentences
    - "## Key points" as nested bullets organized by topic
    - "## Terms & definitions" for any jargon defined
    - "## Action items" for anything assigned, due, or flagged as exam material (omit the section if none)

    Only use what is in the transcript. Do not invent facts.

    Transcript:

    """

    struct GenericError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let max_tokens: Int
        let messages: [Message]
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    private struct ErrorResponse: Decodable {
        struct Err: Decodable { let message: String }
        let error: Err
    }

    static func generate(transcript: String, provider: Provider, key: String) async throws -> String {
        var request = URLRequest(url: provider.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider.needsKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let body = ChatRequest(
            model: provider.model,
            max_tokens: 4000,
            messages: [ChatRequest.Message(role: "user", content: prompt + transcript)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GenericError(message: "No response from server.")
        }

        guard (200..<300).contains(http.statusCode) else {
            if let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw GenericError(message: decoded.error.message)
            }
            throw GenericError(message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw GenericError(message: "No content returned by the provider.")
            }
            return content
        } catch {
            throw GenericError(message: "Couldn't parse the provider's response.")
        }
    }
}
