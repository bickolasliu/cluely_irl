import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var questionText: String = ""
    @State private var isScanning: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            ConnectionStatusView()

            Divider()

            // Main content area
            if !bluetoothManager.isConnected {
                // Show scanning/pairing UI
                ScanningView(isScanning: $isScanning)
            } else {
                // Show chat interface
                ChatInterfaceView(questionText: $questionText)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        HStack {
            Image(systemName: bluetoothManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .foregroundColor(bluetoothManager.isConnected ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Status")
                    .font(.headline)
                Text(bluetoothManager.connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ScanningView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var isScanning: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Even Realities G1 Glasses")
                .font(.title2)
                .fontWeight(.semibold)

            if isScanning {
                ProgressView("Scanning for glasses...")
                    .padding()
            } else {
                Button(action: startScan) {
                    Label("Scan for Glasses", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }

            if !bluetoothManager.pairedGlasses.isEmpty {
                Divider()
                    .padding(.vertical)

                Text("Available Glasses")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(bluetoothManager.pairedGlasses, id: \.channelNumber) { glasses in
                            GlassesDeviceRow(glasses: glasses)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12) // Add vertical padding to prevent border/shadow clipping
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func startScan() {
        isScanning = true
        bluetoothManager.startScan { _ in
            // Auto-stop after 15 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                isScanning = false
                bluetoothManager.stopScan { _ in }
            }
        }
    }
}

struct GlassesDeviceRow: View {
    let glasses: PairedGlasses
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var isHovering = false

    var body: some View {
        Button(action: { connectToGlasses() }) {
            HStack(spacing: 12) {
                // Glasses icon
                Image(systemName: "eyeglasses")
                    .font(.system(size: 32))
                    .foregroundColor(isHovering ? .accentColor : .secondary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pair: \(glasses.channelNumber)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "l.square.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(glasses.leftDeviceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "r.square.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(glasses.rightDeviceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .opacity(isHovering ? 1.0 : 0.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? Color.accentColor.opacity(0.05) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: isHovering ? Color.black.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Click to connect to these glasses")
    }

    private func connectToGlasses() {
        bluetoothManager.connectToDevice(deviceName: "Pair_\(glasses.channelNumber)") { _ in }
    }
}

struct ChatInterfaceView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Binding var questionText: String
    @State private var isHoldingVoiceButton: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Current response display
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if chatViewModel.isProcessing {
                        HStack {
                            ProgressView()
                            Text("Processing...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else if !chatViewModel.currentAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            if !chatViewModel.currentQuestion.isEmpty {
                                Text("Q: \(chatViewModel.currentQuestion)")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .padding(.bottom, 4)
                            }

                            Text(chatViewModel.currentAnswer)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("Press and hold the voice button or type a question")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }

                    // Chat history
                    if !chatViewModel.messages.isEmpty {
                        Divider()
                            .padding(.vertical)

                        Text("History")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(chatViewModel.messages) { message in
                            ChatHistoryRow(message: message)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Input area
            HStack(spacing: 12) {
                // Voice input button
                Button(action: {}) {
                    Image(systemName: chatViewModel.isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(chatViewModel.isRecording ? .red : .primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(chatViewModel.isRecording ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHoldingVoiceButton {
                                isHoldingVoiceButton = true
                                chatViewModel.startVoiceRecording()
                            }
                        }
                        .onEnded { _ in
                            isHoldingVoiceButton = false
                            Task {
                                await chatViewModel.stopVoiceRecording()
                            }
                        }
                )
                .help("Hold to speak")

                // Text input
                TextField("Type a question...", text: $questionText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendQuestion()
                    }
                    .disabled(chatViewModel.isProcessing)

                // Send button
                Button(action: sendQuestion) {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .disabled(questionText.isEmpty || chatViewModel.isProcessing)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func sendQuestion() {
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        questionText = ""
        Task {
            await chatViewModel.sendQuestion(question)
        }
    }
}

struct ChatHistoryRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text("Q: \(message.question)")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(message.answer)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothManager.shared)
        .environmentObject(ChatViewModel())
        .frame(width: 600, height: 700)
}
