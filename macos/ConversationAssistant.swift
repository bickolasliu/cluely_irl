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
    private var isAnalyzing: Bool = false // Prevent concurrent analyses
    private var lastTranscriptUpdate: Date? // Track last transcript change
    private var currentAnalysisTask: Task<Void, Never>? // Track current task for cancellation

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
        // Update the full running transcript (throttled logging)
        fullTranscript = text
        lastTranscriptUpdate = Date()

        if transcriptStartTime == nil {
            transcriptStartTime = Date()
            print("📝 Transcript started")
        }
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
        lastTranscriptUpdate = nil
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

        // Cancel any pending analysis task
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil
        isAnalyzing = false

        print("🛑 Stopped conversation analysis")
    }

    private func analyzeConversation() {
        // Prevent concurrent analyses
        guard !isAnalyzing else {
            print("⏭️ Skipping analysis - previous analysis still running")
            return
        }

        // Skip if no recent transcript updates (idle for >30 seconds)
        if let lastUpdate = lastTranscriptUpdate {
            let idleTime = Date().timeIntervalSince(lastUpdate)
            if idleTime > 30 {
                print("⏭️ Skipping analysis - idle for \(Int(idleTime))s")
                return
            }
        }

        let transcript = getRecentTranscript()

        guard !transcript.isEmpty else {
            print("⏭️ Skipping analysis - no transcript")
            return
        }

        guard transcript.count > 10 else {
            print("⏭️ Skipping analysis - transcript too short (\(transcript.count) chars)")
            return
        }

        print("🧠 Analyzing conversation... (\(transcript.count) chars)")
        isAnalyzing = true

        // Cancel any existing task
        currentAnalysisTask?.cancel()

        currentAnalysisTask = Task {
            defer {
                Task { @MainActor in
                    self.isAnalyzing = false
                    self.currentAnalysisTask = nil
                }
            }

            // Check for cancellation
            guard !Task.isCancelled else {
                print("⏭️ Analysis cancelled")
                return
            }

            do {
                let suggestions = try await getSuggestions(for: transcript)

                // Check again before updating UI
                guard !Task.isCancelled else {
                    print("⏭️ Analysis cancelled after completion")
                    return
                }

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
        print("📤 Sending to GPT-5 with web search enabled...")

        // Focus on the most recent part of the transcript (last 200 chars)
        let recentTranscript = String(transcript.suffix(200))

        let prompt = """
RECENT CONVERSATION (most important):
"\(recentTranscript)"

CRITICAL: Focus on the MOST RECENT utterance (end of transcript above). This is what was just said!

YOUR TASK: If the most recent utterance contains a QUESTION, provide the ANSWER. Otherwise, suggest what to say next.

QUESTION DETECTION (HIGH PRIORITY):
- Look for question words: "what", "who", "where", "when", "how", "which", "why"
- Look for question marks: "?"
- Look for phrases like: "tell me about", "I wonder", "do you know"

IF QUESTION DETECTED → ANSWER IT (use web search):
Example: "what's the tallest building" → Reply with:
Burj Khalifa
828 meters
Dubai
Opened 2010
163 floors

Example: "who won the super bowl" → Reply with:
Chiefs won
38-35 score
Feb 2024
Mahomes MVP
Vegas

IF NO QUESTION → SUGGEST RESPONSES:
Example: "discussing the project budget" → Reply with:
Timeline?
Costs breakdown
ROI estimate
Resources needed
Risk factors

CRITICAL RULES:
1. Maximum 3 words per line
2. Focus on END of transcript (what was JUST said)
3. ALWAYS answer questions with FACTS (use web search)
4. Be ultra-concise - abbreviate everything
5. No numbering, no extra text

Reply with ONLY 5 items, one per line:
"""

        print("📝 Sending optimized prompt (focusing on last 200 chars)...")

        let response = try await openAIService.sendChatRequest(question: prompt, enableWebSearch: true)

        print("✅ Got response with web search: \(response)")

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
        // Take top 5 suggestions
        let formatted = suggestions.prefix(5).map { suggestion in
            // Keep ultra-short keywords as-is (should already be 1-3 words)
            // Glasses can handle ~18-20 chars per line comfortably
            let text = suggestion.text

            // Only truncate if somehow longer than 20 chars
            if text.count > 20 {
                return String(text.prefix(18)) + ".."
            }
            return text
        }

        let result = formatted.joined(separator: "\n")
        print("👓 Formatted for glasses (\(formatted.count) lines, \(result.count) total chars):")
        formatted.forEach { print("   '\($0)'") }
        return result
    }
}
