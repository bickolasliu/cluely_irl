//
//  ConversationAssistant.swift
//  Runner
//
//  Conversation coach that analyzes transcript and provides suggestions
//

import Foundation

struct ConversationSuggestion {
    let text: String
    let timestamp: Date
}

class ConversationAssistant {
    static let shared = ConversationAssistant()

    var onSuggestionsUpdated: (([ConversationSuggestion]) -> Void)?
    var onGlassesSuggestions: ((String) -> Void)? // 5 lines max for glasses

    private var analysisTimer: Timer?
    private var analysisInterval: TimeInterval = 5.0 // Configurable
    private var openAIService = OpenAIService()

    private var fullTranscript: String = "" // Complete running transcript
    private var transcriptStartTime: Date? // Track when transcript started

    private init() {}

    // MARK: - Configuration

    func setAnalysisInterval(_ interval: TimeInterval) {
        analysisInterval = interval
        print("⚙️ Analysis interval set to \(interval) seconds")

        // Restart timer if running
        if analysisTimer != nil {
            startAnalysis()
        }
    }

    // MARK: - Transcript Management

    func updateTranscript(_ text: String) {
        // Update the full running transcript
        fullTranscript = text

        if transcriptStartTime == nil {
            transcriptStartTime = Date()
        }

        print("📝 Transcript updated: \(fullTranscript.count) chars total")
        print("📄 Recent transcript: \(fullTranscript.suffix(150))...")
    }

    func manualAnalyze() {
        print("🔍 Manual analysis triggered")
        analyzeConversation()
    }

    func getRecentTranscript() -> String {
        return fullTranscript
    }

    func clearTranscript() {
        fullTranscript = ""
        transcriptStartTime = nil
        print("🗑️ Transcript cleared")
    }

    // MARK: - Analysis

    func startAnalysis() {
        stopAnalysis()

        print("🧠 Starting conversation analysis (every \(analysisInterval)s)")

        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.analyzeConversation()
        }

        // Run first analysis immediately
        analyzeConversation()
    }

    func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        print("🛑 Stopped conversation analysis")
    }

    private func analyzeConversation() {
        let transcript = getRecentTranscript()

        guard !transcript.isEmpty else {
            print("⏭️ Skipping analysis - no transcript")
            return
        }

        print("🧠 Analyzing conversation... (\(transcript.count) chars)")

        Task {
            do {
                let suggestions = try await getSuggestions(for: transcript)
                await MainActor.run {
                    self.onSuggestionsUpdated?(suggestions)

                    // Format for glasses (5 lines max, 3-5 words each)
                    let glassesText = self.formatForGlasses(suggestions)
                    self.onGlassesSuggestions?(glassesText)
                }
            } catch {
                print("❌ Analysis failed: \(error)")
            }
        }
    }

    private func getSuggestions(for transcript: String) async throws -> [ConversationSuggestion] {
        print("📤 Sending to OpenAI API...")

        let prompt = """
Based on this conversation: "\(transcript)"

Give me 5 short suggestions (3-5 words each) for what to say next. Reply with ONLY the suggestions, one per line:
"""

        print("📝 Prompt: \(prompt)")

        let response = try await openAIService.sendChatRequest(question: prompt)

        print("✅ Got response from OpenAI: \(response)")

        // Parse response into suggestions
        var lines = response.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Remove numbering if present (1., 2., etc.)
        lines = lines.map { line in
            line.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
        }

        print("📋 Parsed \(lines.count) suggestions: \(lines)")

        let suggestions = lines.prefix(5).map { line in
            ConversationSuggestion(text: String(line), timestamp: Date())
        }

        print("✅ Returning \(suggestions.count) suggestions")

        return suggestions
    }

    private func formatForGlasses(_ suggestions: [ConversationSuggestion]) -> String {
        // Take top 5 suggestions, ensure they're brief
        let formatted = suggestions.prefix(5).map { suggestion in
            // Truncate to ~25 chars per line (glasses display limit)
            let truncated = String(suggestion.text.prefix(25))
            return truncated
        }

        return formatted.joined(separator: "\n")
    }
}
