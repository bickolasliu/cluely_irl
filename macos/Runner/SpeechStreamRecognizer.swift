//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Adapted for macOS
//
import AVFoundation
import Speech

class SpeechStreamRecognizer {
    static let shared = SpeechStreamRecognizer()

    var onRecognitionResult: ((String) -> Void)?
    var isRecording: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText: String = "" // latest accepted recognized text

    let languageDic = [
        "CN": "zh-CN",
        "EN": "en-US",
        "RU": "ru-RU",
        "KR": "ko-KR",
        "JP": "ja-JP",
        "ES": "es-ES",
        "FR": "fr-FR",
        "DE": "de-DE",
        "NL": "nl-NL",
        "NB": "nb-NO",
        "DA": "da-DK",
        "SV": "sv-SE",
        "FI": "fi-FI",
        "IT": "it-IT"
    ]
    
    let dateFormatter = DateFormatter()
    
    private var lastTranscription: SFTranscription? // cache to make contrast between near results
    private var cacheString = "" // cache stream recognized formattedString
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    private init() {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
            } catch {
                print("SFSpeechRecognizer------permission error----\(error)")
            }
        }
    }
    
    func startRecognition(identifier: String) {
        print("🎤 Starting speech recognition...")

        // Clean up any existing session first
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""

        let localIdentifier = languageDic[identifier]
        print("startRecognition----localIdentifier----\(localIdentifier ?? "en-US")--identifier---\(identifier)---")
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localIdentifier ?? "en-US"))
        guard let recognizer = recognizer else {
            print("❌ Speech recognizer is not available")
            return
        }

        guard recognizer.isAvailable else {
            print("❌ startRecognition recognizer is not available")
            return
        }

        print("✅ Recognizer available, creating request...")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        print("✅ Recognition request created, starting task...")
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print("❌ SpeechRecognizer Recognition error: \(error)")

                // Check if it's the "Siri and Dictation disabled" error
                let nsError = error as NSError
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 201 {
                    print("⚠️ CRITICAL: Siri and Dictation are disabled!")
                    print("   → Go to System Settings → Privacy & Security → Speech Recognition")
                    print("   → Toggle ON to enable dictation")

                    // Mark as failed and stop the microphone on glasses
                    DispatchQueue.main.async {
                        BluetoothManager.shared.speechRecognitionFailed = true
                        BluetoothManager.shared.stopRecordingWithTimeout()
                    }
                }
            } else if let result = result {
                print("🗣️ Transcription: \(result.bestTranscription.formattedString)")

                let currentTranscription = result.bestTranscription
                if lastTranscription == nil {
                    cacheString = currentTranscription.formattedString
                } else {

                    if (currentTranscription.segments.count < lastTranscription?.segments.count ?? 1 || currentTranscription.segments.count == 1) {
                        self.lastRecognizedText += cacheString
                        cacheString = ""
                    } else {
                        cacheString = currentTranscription.formattedString
                    }
                }

                lastTranscription = result.bestTranscription
            }
        }

        isRecording = true
        print("✅ Speech recognition fully started and ready for audio")
    }

    func stopRecognition() {
        isRecording = false
        print("stopRecognition-----self.lastRecognizedText-------\(self.lastRecognizedText)------cacheString----------\(cacheString)---")
        self.lastRecognizedText += cacheString

        DispatchQueue.main.async {
            self.onRecognitionResult?(self.lastRecognizedText)
        }

        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
    }
    
    func appendPCMData(_ pcmData: Data) {
        guard let recognitionRequest = recognitionRequest else {
            print("⚠️ Recognition request is not available (may still be initializing)")
            return
        }

        print("🎵 Appending PCM data: \(pcmData.count) bytes")

        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(pcmData.count) / audioFormat.streamDescription.pointee.mBytesPerFrame) else {
            print("Failed to create audio buffer")
            return
        }
        audioBuffer.frameLength = audioBuffer.frameCapacity

        pcmData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            if let audioDataPointer = bufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                let audioBufferPointer = audioBuffer.int16ChannelData?.pointee
                audioBufferPointer?.initialize(from: audioDataPointer, count: pcmData.count / MemoryLayout<Int16>.size)
                recognitionRequest.append(audioBuffer)
            } else {
                print("Failed to get pointer to audio data")
            }
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

