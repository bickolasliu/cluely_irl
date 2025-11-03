//
//  ConversationAssistantView.swift
//  Runner
//
//  Real-time conversation coach UI
//

import SwiftUI

struct ConversationAssistantView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            header
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main content - split view
            HSplitView {
                // Left: Live Transcript
                transcriptView
                    .frame(minWidth: 250)

                // Right: AI Suggestions
                suggestionsView
                    .frame(minWidth: 250)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showSettings) {
            settingsView
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isListening ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(viewModel.isListening ? Color.red.opacity(0.3) : Color.clear, lineWidth: 4)
                            .scaleEffect(viewModel.isListening ? 1.3 : 1)
                            .animation(
                                viewModel.isListening ?
                                    Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                                value: viewModel.isListening
                            )
                    )

                Text(viewModel.isListening ? "Listening..." : "Paused")
                    .font(.headline)
                    .foregroundColor(viewModel.isListening ? .red : .secondary)
            }

            Spacer()

            // Analysis interval
            Text("Analysis: \(Int(viewModel.analysisInterval))s")
                .font(.caption)
                .foregroundColor(.secondary)

            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
            }

            // Clear button
            Button(action: { viewModel.clearTranscript() }) {
                Image(systemName: "trash")
            }
            .help("Clear transcript")

            // Test glasses button
            Button(action: testGlassesDisplay) {
                Image(systemName: "eyeglasses")
            }
            .help("Test glasses display")

            // Start/Stop button
            Button(action: toggleListening) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "play.circle.fill")
                    Text(viewModel.isListening ? "Stop" : "Start")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isListening ? .red : .green)
            .help(viewModel.isListening ? "Stop listening" : "Start conversation assistant")
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Transcript")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            ScrollView {
                ScrollViewReader { proxy in
                    Text(viewModel.liveTranscript.isEmpty ? "Waiting for speech..." : viewModel.liveTranscript)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("transcript")
                        .onChange(of: viewModel.liveTranscript) { _ in
                            withAnimation {
                                proxy.scrollTo("transcript", anchor: .bottom)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Suggestions")
                    .font(.headline)

                Spacer()

                if !viewModel.suggestions.isEmpty {
                    Text("Updated: \(timeAgo(viewModel.suggestions.first?.timestamp ?? Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if viewModel.suggestions.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("AI suggestions will appear here")
                            .foregroundColor(.secondary)
                        if viewModel.isListening {
                            Text("Analyzing conversation...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            suggestionCard(index: index + 1, suggestion: suggestion)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func suggestionCard(index: Int, suggestion: ConversationSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            Text("\(index)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            // Suggestion text
            Text(suggestion.text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2)
                .bold()

            Form {
                Section("Analysis Interval") {
                    HStack {
                        Text("Analyze every")
                        Slider(value: $viewModel.analysisInterval, in: 3...30, step: 1)
                        Text("\(Int(viewModel.analysisInterval))s")
                            .frame(width: 35)
                    }
                    Text("How often to send transcript to AI for analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            Button("Done") {
                showSettings = false
                viewModel.updateAnalysisInterval(viewModel.analysisInterval)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 250)
    }

    // MARK: - Actions

    private func toggleListening() {
        if viewModel.isListening {
            viewModel.stopListening()
        } else {
            viewModel.startListening()
        }
    }

    private func testGlassesDisplay() {
        print("🧪 Testing glasses display...")
        Task {
            await viewModel.testGlassesDisplay()
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 10 {
            return "just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else {
            return "\(seconds / 60)m ago"
        }
    }
}
