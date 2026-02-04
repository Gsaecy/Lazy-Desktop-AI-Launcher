import Foundation

struct DeepSeekClient {
    let apiKey: String

    // 常见 DeepSeek OpenAI-compatible endpoint
    var endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    var model = "deepseek-chat"

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    func ask(_ prompt: String) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "DeepSeek", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: body])
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}//
//  DeepSeekClient.swift
//  LazyDesktopAI
//
//  Created by 郭宏宇 on 2026/2/4.
//

