import Foundation

enum ClaudeError: LocalizedError {
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let message):
            return message
        }
    }
}

struct ClaudeService {
    private struct MessageResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        struct APIError: Decodable {
            let message: String
        }
        let content: [Block]?
        let error: APIError?
    }

    static func send(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ClaudeError.badResponse("Bad URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "system": "You are Moai, a tiny assistant living in the Mac notch. Answer in as few words as possible. Plain text only, no markdown.",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)

        if let apiError = decoded.error {
            throw ClaudeError.badResponse(apiError.message)
        }

        let text = decoded.content?
            .compactMap { $0.text }
            .joined(separator: "\n") ?? ""

        guard !text.isEmpty else {
            throw ClaudeError.badResponse("Empty response from API")
        }
        return text
    }
}
