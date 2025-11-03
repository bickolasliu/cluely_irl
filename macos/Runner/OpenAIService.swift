import Foundation

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"

    init() {
        // Load API key from .env file
        self.apiKey = Self.loadAPIKey()
    }

    private static func loadAPIKey() -> String {
        // 1. Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            print("✅ Loaded API key from environment variable")
            return envKey
        }

        let fileManager = FileManager.default

        // 2. Try bundle resource (if .env is added to Xcode project)
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil) {
            if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
                if let key = parseEnvFile(content) {
                    print("✅ Loaded API key from bundle: \(envPath)")
                    return key
                }
            }
        }

        // 3. Try multiple file system locations
        let possiblePaths = [
            "/Users/nicholasliu/Documents/coretsu/even_realities/.env",
            (NSHomeDirectory() as NSString).appendingPathComponent(".env"),
            Bundle.main.resourcePath.map { ($0 as NSString).appendingPathComponent(".env") },
        ].compactMap { $0 }

        print("🔍 Searching for .env file in:")
        for envPath in possiblePaths {
            print("  - \(envPath) ... ", terminator: "")
            if fileManager.fileExists(atPath: envPath) {
                print("EXISTS")
                if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
                    if let key = parseEnvFile(content) {
                        print("✅ Loaded API key from: \(envPath)")
                        return key
                    } else {
                        print("⚠️  File exists but no valid key found")
                    }
                } else {
                    print("⚠️  File exists but couldn't read it")
                }
            } else {
                print("NOT FOUND")
            }
        }

        print("❌ OPENAI_API_KEY not found in any location")
        return ""
    }

    private static func parseEnvFile(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENAI_API_KEY=") {
                let key = trimmed.replacingOccurrences(of: "OPENAI_API_KEY=", with: "")
                let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        return nil
    }

    func sendChatRequest(question: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant. Keep responses concise and clear for display on AR glasses."],
                ["role": "user", "content": question]
            ],
            "max_tokens": 500
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return content
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add OPENAI_API_KEY to .env file."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}
