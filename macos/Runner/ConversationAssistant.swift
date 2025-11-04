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
    private var analysisInterval: TimeInterval = 3.0 // Configurable
    private var openAIService = OpenAIService()

    private var fullTranscript: String = "" // Complete running transcript
    private var transcriptStartTime: Date? // Track when transcript started
    private var isAnalyzing: Bool = false // Prevent concurrent analyses
    private var lastTranscriptUpdate: Date? // Track last transcript change
    private var currentAnalysisTask: Task<Void, Never>? // Track current task for cancellation
    private var lastAnalyzedTranscript: String = "" // Track transcript we last analyzed

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
        lastAnalyzedTranscript = "" // Reset so next analysis will run
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

        // Lower threshold for glasses mic (shorter voice sessions)
        guard transcript.count > 5 else {
            print("⏭️ Skipping analysis - transcript too short (\(transcript.count) chars)")
            return
        }

        // Skip if transcript hasn't changed since last analysis
        if transcript == lastAnalyzedTranscript {
            print("⏭️ Skipping analysis - transcript unchanged")
            return
        }

        print("🧠 Analyzing conversation... (\(transcript.count) chars, changed: \(transcript != lastAnalyzedTranscript))")
        lastAnalyzedTranscript = transcript
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

        // Focus on the most recent part of the transcript (last 300 chars for better context)
        let recentTranscript = String(transcript.suffix(300))

        // Extract the VERY LAST sentence/utterance (most critical)
        let lastUtterance = extractLastUtterance(from: recentTranscript)

        let prompt = """
You are an AI assistant for smart glasses. Analyze the user's speech and provide ultra-concise, actionable information.

CURRENT UTTERANCE (just spoken):
"\(lastUtterance)"

CONTEXT (recent conversation):
"\(recentTranscript)"

TASK:
Analyze the CURRENT UTTERANCE and provide exactly 5 lines of output.
- If it's a QUESTION: Answer with key facts (use web search for current/factual info)
- If it's a STATEMENT: Suggest relevant follow-up points or questions

OUTPUT FORMAT:
Return exactly 5 lines. Each line must be 6 words maximum. No numbering, bullets, or formatting.

EXAMPLES:

Input: "How tall is the Eiffel Tower"
Output:
330 meters tall
1,083 feet
Built 1889
Paris landmark
Iron lattice tower

Input: "Who won the 2024 election"
Output:
[Current winner]
Electoral votes
Key states
Victory margin
Inauguration date

Input: "discussing quarterly sales targets"
Output:
Current numbers?
Growth rate
Top performers
Challenges
Action items

Input: "thinking about visiting Japan"
Output:
Best season?
Visa requirements
Budget estimate
Top cities
Trip duration

CRITICAL RULES:
1. Exactly 5 lines, no more, no less
2. Each line: max 6 words only
3. Focus on the CURRENT utterance (the last thing spoken)
4. No sources, citations, or URLs
5. No numbering (1., 2., etc.) or bullets (-, •)
6. Be factual for questions, suggestive for statements
7. Ultra-concise - every word counts

OUTPUT (5 lines, 1-4 words each):
"""

        print("📝 Sending optimized prompt (last utterance: '\(lastUtterance.prefix(50))...', context: \(recentTranscript.count) chars)...")

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

    private func extractLastUtterance(from transcript: String) -> String {
        // Extract the last sentence or question from the transcript
        // Look for sentence boundaries: period, question mark, or significant pause indicators

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find the last sentence by looking for punctuation
        let sentenceDelimiters = CharacterSet(charactersIn: ".?!")
        let components = trimmed.components(separatedBy: sentenceDelimiters)

        // Get the last non-empty component
        let lastSentence = components.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? trimmed

        // If the last sentence is very short, it might be incomplete - take more context
        let lastUtterance = lastSentence.trimmingCharacters(in: .whitespaces)

        // If it's too short (less than 5 chars), just return the last 150 chars of full transcript
        if lastUtterance.count < 5 {
            return String(trimmed.suffix(150))
        }

        // Limit to last 150 chars to keep it focused
        return String(lastUtterance.suffix(150))
    }

    private func formatForGlasses(_ suggestions: [ConversationSuggestion]) -> String {
        // Take top 5 suggestions
        let formatted = suggestions.prefix(5).map { suggestion in
            // Keep ultra-short keywords as-is (should already be 1-3 words)
            // Glasses can handle ~40 chars per line (488px width, font size 21)
            let text = suggestion.text

            if text.count > 40 {
                return String(text.prefix(38)) + ".."
            }
            return text
        }

        let result = formatted.joined(separator: "\n")
        print("👓 Formatted for glasses (\(formatted.count) lines, \(result.count) total chars):")
        formatted.forEach { print("   '\($0)'") }
        return result
    }
}
