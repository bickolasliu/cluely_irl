import SwiftUI
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let timestamp: Date
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentQuestion: String = ""
    @Published var currentAnswer: String = ""
    @Published var isProcessing: Bool = false
    @Published var isRecording: Bool = false

    // Conversation Assistant Mode
    @Published var isListening: Bool = false
    @Published var liveTranscript: String = ""
    @Published var suggestions: [ConversationSuggestion] = []
    @Published var analysisInterval: Double = 5.0 // seconds

    private var openAIService = OpenAIService()
    private var conversationAssistant = ConversationAssistant.shared

    init() {
        setupConversationAssistant()

        // Legacy: Set up callback for speech recognition from glasses
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] recognizedText in
            print("🎤 Recognized text from glasses: \(recognizedText)")
            Task { @MainActor in
                if !recognizedText.isEmpty {
                    await self?.sendQuestion(recognizedText)
                }
            }
        }
    }

    private func setupConversationAssistant() {
        // Real-time transcript updates (partial - while speaking)
        SpeechStreamRecognizer.shared.onPartialTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.liveTranscript = transcript
                // Also update conversation assistant with partial transcript
                self?.conversationAssistant.updateTranscript(transcript)
            }
        }

        // Complete transcript updates (final - after pause)
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] transcript in
            Task { @MainActor in
                self?.liveTranscript = transcript
                // Update conversation assistant with final transcript
                self?.conversationAssistant.updateTranscript(transcript)
            }
        }

        // Suggestions updates
        conversationAssistant.onSuggestionsUpdated = { [weak self] newSuggestions in
            Task { @MainActor in
                self?.suggestions = newSuggestions
            }
        }

        // Glasses display
        conversationAssistant.onGlassesSuggestions = { [weak self] glassesText in
            Task { @MainActor in
                await self?.sendSuggestionsToGlasses(glassesText)
            }
        }
    }

    // MARK: - Conversation Assistant Controls

    func startListening() {
        print("▶️ Starting conversation assistant...")
        isListening = true

        // Start continuous Mac microphone listening
        SpeechStreamRecognizer.shared.startContinuousMacListening(identifier: "EN")

        // Start LLM analysis
        conversationAssistant.startAnalysis()
    }

    func stopListening() {
        print("⏹️ Stopping conversation assistant...")
        isListening = false

        // Stop microphone
        SpeechStreamRecognizer.shared.stopContinuousMacListening()

        // Stop analysis
        conversationAssistant.stopAnalysis()
    }

    func updateAnalysisInterval(_ interval: Double) {
        analysisInterval = interval
        conversationAssistant.setAnalysisInterval(interval)
    }

    func clearTranscript() {
        liveTranscript = ""
        suggestions = []
        conversationAssistant.clearTranscript()
        SpeechStreamRecognizer.shared.clearTranscript()
    }

    private func sendSuggestionsToGlasses(_ text: String) async {
        guard BluetoothManager.shared.isConnected else {
            print("⚠️ Glasses not connected, skipping display")
            return
        }

        print("👓 Sending suggestions to glasses")
        print("📝 Text to send: \(text)")

        let result = await BluetoothManager.shared.sendEvenAIData(
            text: text,
            newScreen: 0x71, // Text display mode
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )

        if result {
            print("✅ Successfully sent to glasses")
        } else {
            print("❌ Failed to send to glasses")
        }
    }

    func testGlassesDisplay() async {
        print("🧪 TESTING GLASSES DISPLAY")

        let testText = """
Ask about timeline
Mention budget
Request examples
Clarify scope
Discuss risks
"""

        print("📝 Test text (5 lines):")
        print(testText)

        guard BluetoothManager.shared.isConnected else {
            print("❌ Glasses not connected!")
            return
        }

        print("✅ Glasses connected, sending test...")

        let result = await BluetoothManager.shared.sendEvenAIData(
            text: testText,
            newScreen: 0x71,
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )

        print(result ? "✅ Test sent successfully" : "❌ Test send failed")
    }

    // MARK: - Legacy Q&A Mode (kept for backward compatibility)

    func sendQuestion(_ question: String) async {
        guard !question.isEmpty else { return }

        isProcessing = true
        currentQuestion = question
        currentAnswer = "Processing..."

        do {
            let answer = try await openAIService.sendChatRequest(question: question)
            currentAnswer = answer

            // Add to history
            let message = ChatMessage(question: question, answer: answer, timestamp: Date())
            messages.insert(message, at: 0)

            // Send to glasses if connected
            if BluetoothManager.shared.isConnected {
                await sendToGlasses(answer)
            }

        } catch {
            currentAnswer = "Error: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func startVoiceRecording() {
        isRecording = true
        SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")

        // Set up a listener for speech recognition results
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] text in
            Task { @MainActor in
                self?.currentQuestion = text
            }
        }
    }

    func stopVoiceRecording() async {
        isRecording = false
        SpeechStreamRecognizer.shared.stopRecognition()

        // Send the recognized text
        if !currentQuestion.isEmpty {
            await sendQuestion(currentQuestion)
        }
    }

    private func sendToGlasses(_ text: String) async {
        print("🔧 Sending text to glasses (TextService mode - 0x71)")

        // Truncate and format text exactly like Flutter TextService
        let truncatedText = String(text.prefix(100))

        // Add leading newlines (Flutter adds \n\n for short text)
        let formattedText = "\n\n\(truncatedText)"

        print("📝 Formatted text: '\(formattedText)'")

        // Send with 0x70 status (0x71 after OR with 0x01)
        // This is for TEXT DISPLAY (not EvenAI voice mode!)
        print("📤 Sending text with 0x71 (text display mode)")
        await BluetoothManager.shared.sendEvenAIData(
            text: formattedText,
            newScreen: 0x71, // 0x01 | 0x70 (text display status)
            pos: 0,
            currentPage: 1,
            maxPage: 1
        )
    }

    private func measureStringList(_ text: String) -> [String] {
        // Simple line splitting for now
        // In production, would measure actual width as Flutter code did
        let paragraphs = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        return paragraphs.filter { !$0.isEmpty }
    }

    func clearCurrent() {
        currentQuestion = ""
        currentAnswer = ""
    }
}
