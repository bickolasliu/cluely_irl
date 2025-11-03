import Foundation

// MARK: - Responses API Models for GPT-5 with Web Search

struct WebSearchTool: Codable {
    let type: String = "web_search"
}

struct ResponsesRequest: Codable {
    let model: String
    let input: String
    let tools: [WebSearchTool]
    let tool_choice: String?
}

struct ResponsesResponse: Codable {
    struct OutputItem: Codable {
        struct ContentItem: Codable {
            let text: String?
            let type: String?
        }
        let type: String
        let content: [ContentItem]?
    }
    let output: [OutputItem]?
    let output_text: String? // Some responses include this directly
}

// MARK: - Chat Completions API Models (fallback)

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let max_tokens: Int?
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

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

    func sendChatRequest(question: String, enableWebSearch: Bool = false) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        if enableWebSearch {
            // Use Responses API with GPT-5 and web search
            return try await sendResponsesAPIRequest(question: question)
        } else {
            // Use Chat Completions API for non-web-search requests
            return try await sendChatCompletionsRequest(question: question)
        }
    }

    private func sendResponsesAPIRequest(question: String) async throws -> String {
        let url = URL(string: "\(baseURL)/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0 // Increased timeout for GPT-5 with web search

        let body = ResponsesRequest(
            model: "gpt-5",
            input: question,
            tools: [WebSearchTool()],
            tool_choice: "auto"
        )

        request.httpBody = try JSONEncoder().encode(body)

        print("🔍 Using Responses API with GPT-5 + web search")
        print("📤 Request to: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Log detailed error
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAI API Error (\(httpResponse.statusCode)):")
                print("   \(errorString.prefix(500))")
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse Responses API response
        let decoder = JSONDecoder()
        let responsesResponse = try decoder.decode(ResponsesResponse.self, from: data)

        // Extract text from output (ignoring sources/citations/annotations)
        // We only want the pure text content for display on glasses
        if let outputText = responsesResponse.output_text {
            print("✅ Got response (output_text): \(outputText.prefix(100))...")
            return outputText
        }

        // Or extract from output array (still ignoring annotations)
        let text = responsesResponse.output?.compactMap { outputItem in
            outputItem.content?.compactMap { $0.text }.joined()
        }.joined(separator: "\n") ?? ""

        guard !text.isEmpty else {
            print("❌ No text in response")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Response: \(jsonString.prefix(500))")
            }
            throw OpenAIError.invalidResponse
        }

        print("✅ Got response (output array): \(text.prefix(100))...")
        return text
    }

    private func sendChatCompletionsRequest(question: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let body = OpenAIChatRequest(
            model: "gpt-4o",
            messages: [
                OpenAIChatMessage(role: "system", content: "You are a helpful assistant. Keep responses concise and clear for display on AR glasses."),
                OpenAIChatMessage(role: "user", content: question)
            ],
            max_tokens: 500
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ OpenAI API Error (\(httpResponse.statusCode)): \(errorString.prefix(500))")
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(OpenAIChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
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
