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

    private var openAIService = OpenAIService()

    init() {
        // Set up callback for speech recognition from glasses
        SpeechStreamRecognizer.shared.onRecognitionResult = { [weak self] recognizedText in
            print("🎤 Recognized text from glasses: \(recognizedText)")
            Task { @MainActor in
                if !recognizedText.isEmpty {
                    await self?.sendQuestion(recognizedText)
                }
            }
        }
    }

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
        // Split text into lines for glasses display
        let lines = measureStringList(text)

        if lines.isEmpty { return }

        // Send first page
        let firstPage = lines.prefix(5).joined(separator: "\n")
        await BluetoothManager.shared.sendEvenAIData(
            text: firstPage,
            newScreen: 0x31, // 0x01 | 0x30
            pos: 0,
            currentPage: 1,
            maxPage: Int(ceil(Double(lines.count) / 5.0))
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
