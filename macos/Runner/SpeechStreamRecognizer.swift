//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Adapted for macOS - Continuous Mac microphone listening
//
import AVFoundation
import Speech

class SpeechStreamRecognizer {
    static let shared = SpeechStreamRecognizer()

    var onRecognitionResult: ((String) -> Void)?
    var onPartialTranscript: ((String) -> Void)? // Real-time partial results
    var isRecording: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    private var fullTranscript: String = "" // Complete ongoing transcript
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

    // MARK: - Continuous Mac Microphone Listening

    func startContinuousMacListening(identifier: String) {
        print("🎤 Starting continuous Mac microphone listening...")

        // Clean up any existing session
        stopContinuousMacListening()

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("❌ Failed to create audio engine")
            return
        }

        inputNode = audioEngine.inputNode

        let localIdentifier = languageDic[identifier] ?? "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localIdentifier))

        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Failed to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        print("🔄 Starting fresh - clearing transcript")
        fullTranscript = ""

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Recognition error: \(error)")
                let nsError = error as NSError
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 201 {
                    print("⚠️ Siri and Dictation are disabled!")
                    DispatchQueue.main.async {
                        self.stopContinuousMacListening()
                    }
                }
                return
            }

            if let result = result {
                let transcript = result.bestTranscription.formattedString

                // Update full transcript
                if result.isFinal {
                    self.fullTranscript += transcript + " "
                    print("✅ Final segment: \(transcript)")
                    print("📝 Full transcript now: \(self.fullTranscript)")

                    // Send complete transcript
                    DispatchQueue.main.async {
                        self.onRecognitionResult?(self.fullTranscript)
                    }
                } else {
                    // Send partial results in real-time
                    let currentText = self.fullTranscript + transcript
                    print("⏳ Partial: \(transcript) (appending to \(self.fullTranscript.count) existing chars)")
                    DispatchQueue.main.async {
                        self.onPartialTranscript?(currentText)
                    }
                }
            }
        }

        // Configure audio format
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            print("✅ Continuous Mac microphone listening started")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }

    func stopContinuousMacListening() {
        print("🛑 Stopping continuous Mac microphone listening")

        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionRequest?.endAudio()

        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        audioEngine = nil
        inputNode = nil

        isRecording = false
    }

    func getFullTranscript() -> String {
        return fullTranscript
    }

    func clearTranscript() {
        fullTranscript = ""
    }

    // MARK: - Legacy methods for glasses microphone (keep for compatibility)

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

