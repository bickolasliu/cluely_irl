# Even GPT - AI Conversation Assistant for Even Realities G1 Glasses

A native Swift/SwiftUI macOS application for Even Realities G1 AR glasses with OpenAI GPT-5 integration and real-time web search.

## Features

### Conversation Assistant Mode

- Continuous listening via glasses microphone
- GPT-5 analyzes transcript every 5 seconds (configurable)
- Displays contextual suggestions or direct answers on glasses
- Uses OpenAI Responses API with web search for factual queries
- 5-line format optimized for AR display (3 words per line)

### Legacy Q&A Mode

- Voice input via Mac or glasses microphone
- GPT-4o integration using Chat Completions API
- Responses displayed on macOS app and glasses
- Full chat history

### Core Capabilities

- Dual Bluetooth connectivity (separate BLE channels for left/right arms)
- On-device speech recognition using Apple Speech Framework
- LC3 audio codec for Bluetooth LE audio decoding
- Custom BLE protocol for glasses display

## Requirements

- macOS 11.0+ (Big Sur or later)
- Xcode 14.0+
- Even Realities G1 Glasses
- OpenAI API Key with GPT-5 access ([get one here](https://platform.openai.com/api-keys))

## Quick Start

### 1. Configure API Key

Create a `.env` file in the project root:

```bash
echo "OPENAI_API_KEY=your-api-key-here" > .env
```

The app searches for the API key in multiple locations:
- Environment variable `OPENAI_API_KEY`
- `.env` file in project root
- `.env` file in home directory
- `.env` file in app bundle

### 2. Open in Xcode

```bash
cd macos
open Runner.xcodeproj
```

### 3. Build & Run

Press `⌘R` or click the Play button. Grant permissions when prompted:
- Bluetooth
- Microphone
- Speech Recognition

### 4. Connect Glasses

1. Click "Scan for Glasses"
2. Select your G1 glasses from the list (e.g., "Pair_0")
3. Wait for "Connected" status (both left and right channels)

## Usage

### Conversation Assistant Mode

This mode provides continuous transcript analysis with real-time suggestions.

1. Connect glasses
2. Click "Start Listening"
   - Glasses microphone activates continuously
   - Live transcript appears in the app
3. Speak normally - glasses capture your speech
4. Every 5 seconds, GPT-5 analyzes the transcript:
   - Questions receive direct answers with web-searched facts
   - Statements receive contextual follow-up suggestions
5. Results display automatically on glasses (5 lines)
6. Click "Stop Listening" to deactivate

Examples:

```
Input: "How tall is the Empire State building"
Output:
  1,454 feet
  381 meters
  102 floors
  Built 1931
  NYC landmark

Input: "discussing the project budget"
Output:
  Timeline?
  Cost breakdown
  ROI estimate
  Resources?
  Risks
```

Configuration:
- Adjust analysis interval (default 5 seconds) in app UI
- Clear transcript manually with Clear button
- Transcript persists when you stop listening

### Legacy Q&A Mode

For one-off questions with longer responses.

From Mac:
1. Type question in text field, click Send
2. View answer in app and on glasses

From Glasses:
1. Long-press left TouchBar, speak, release
2. Answer displays on glasses and in app

From App (Voice):
1. Hold microphone button, speak, release
2. Question sent to GPT-4o
3. Answer appears in app and on glasses

## Project Structure

```
macos/
├── Runner.xcodeproj/              # Xcode project
└── Runner/
    ├── EvenGPTApp.swift           # App entry point
    ├── AppDelegate.swift          # App lifecycle & BLE event handlers
    ├── ContentView.swift          # SwiftUI main interface
    ├── ChatViewModel.swift        # State management & chat logic
    ├── ConversationAssistant.swift # AI conversation analysis
    ├── OpenAIService.swift        # GPT-5 Responses API + GPT-4o Chat API
    ├── BluetoothManager.swift     # BLE protocol for G1 glasses
    ├── SpeechStreamRecognizer.swift # Voice recognition
    ├── ServiceIdentifiers.swift   # BLE UUIDs
    ├── GattProtocal.swift         # BLE helpers
    ├── PcmConverter.h/m           # LC3 to PCM audio conversion
    ├── Runner-Bridging-Header.h   # Obj-C bridge
    ├── lc3/                       # LC3 audio codec (34 files)
    ├── Assets.xcassets/           # App icons
    ├── Info.plist                 # App metadata
    └── *.entitlements             # Permissions

EvenDemoApp-main/                  # Original Flutter demo (reference)
```

## Architecture

### Conversation Assistant Flow

```
Continuous Mode Activated
  ↓
Glasses Mic On (BLE: 0x0E 0x01)
  ↓
Glasses → LC3 Audio Stream (BLE: 0xF1)
  ↓
LC3 Decoder → PCM
  ↓
Apple Speech Recognition → Live Transcript
  ↓
ConversationAssistant (every 5s)
  ↓
GPT-5 Responses API (with web_search tool)
  ↓
Response Generation:
  - Question detected → Answer with facts
  - Statement → Contextual suggestions
  ↓
Format: 5 lines × 3 words
  ↓
BLE Protocol (0x4E packets)
  ↓
Glasses Display (AR overlay)
```

### Voice Q&A Flow (Legacy)

```
Glasses (Long-press) OR App (Hold button)
  → BLE: 0xF5 0x17 (glasses) / Mac mic (app)
  → App sends: 0x0E 0x01 (activate mic if glasses)
  → LC3 audio stream → Speech Recognition
  → GPT-4o Chat Completions API
  → Response → 0x4E packets
  → Glasses Display
```

### Components

- SwiftUI - Declarative UI with reactive state updates
- Combine - Reactive state management and async publishers
- CoreBluetooth - Dual-channel BLE communication (left/right)
- Speech Framework - On-device speech recognition
- LC3 Codec - Bluetooth LE audio codec (C library, ~34 files)
- URLSession - Async/await API calls to OpenAI

## OpenAI Integration

### GPT-5 with Web Search (Conversation Assistant)

Uses the Responses API (`/v1/responses`) with web search tool:

```swift
{
  "model": "gpt-5",
  "input": "How tall is the Empire State building",
  "tools": [{"type": "web_search"}],
  "tool_choice": "auto"
}
```

- Endpoint: `https://api.openai.com/v1/responses`
- Model: `gpt-5`
- Tool: `web_search`
- Timeout: 60 seconds
- Output: Text only (sources/citations stripped for display)

### GPT-4o Chat (Legacy Q&A)

Uses the Chat Completions API (`/v1/chat/completions`):

```swift
{
  "model": "gpt-4o",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant..."},
    {"role": "user", "content": "What is the weather today?"}
  ],
  "max_tokens": 500
}
```

- Endpoint: `https://api.openai.com/v1/chat/completions`
- Model: `gpt-4o`
- Timeout: 30 seconds
- Max tokens: 500

## BLE Protocol (Even G1)

### Commands Sent to Glasses

| Command | Purpose | Format |
|---------|---------|--------|
| `0x0E 0x01` | Activate microphone | `[0x0E, 0x01]` (right BLE only) |
| `0x0E 0x00` | Deactivate microphone | `[0x0E, 0x00]` (right BLE only) |
| `0x4E ...` | Send text/AI response | See protocol below |

### Text Display Protocol (0x4E)

```
[0x4E, seq, total_pkg, current_pkg, newscreen, pos_hi, pos_lo, cur_page, max_page, ...text..., crc_lo, crc_hi]
```

Key Fields:
- `newscreen` - Screen status byte
  - `0x31` = New content + AI displaying (auto mode)
  - `0x41` = New content + AI complete
  - `0x51` = New content + AI manual mode
  - `0x71` = New content + Text display mode (Conversation Assistant)
- `cur_page` / `max_page` - Pagination (1-indexed)
- CRC-16 - Data integrity checksum

### Commands Received from Glasses

| Command | Gesture | Action |
|---------|---------|--------|
| `0xF5 0x00` | Double tap | Exit/close feature |
| `0xF5 0x01` | Single tap (L/R) | Page up/down |
| `0xF5 0x17` | Long-press left | Start EvenAI voice input |
| `0xF5 0x18` | Release | End EvenAI voice input |
| `0xF1 ...` | Audio stream | LC3-encoded mic data |
| `0x0E 0xC9` | Response | Mic activation successful |
| `0x0E 0xCA` | Response | Mic activation failed |

## Development

### Key Files to Modify

Conversation Assistant Logic:
- `ConversationAssistant.swift` - Analysis logic, GPT prompt engineering, suggestion formatting
  - Line 186-250: Main prompt for GPT-5 (question detection, answer formatting)
  - Line 304-322: Formatting for glasses display (5 lines max)

OpenAI Integration:
- `OpenAIService.swift` - API client for GPT-5/GPT-4o
  - Line 140-201: Responses API with web search
  - Line 203-243: Chat Completions API (fallback)

UI Components:
- `ContentView.swift` - Main SwiftUI interface
- `ChatViewModel.swift` - State management and mode switching

BLE Communication:
- `BluetoothManager.swift` - Protocol implementation, packet construction
- `GattProtocal.swift` - Low-level BLE helpers

### Customization Examples

Adjust Analysis Interval:

In `ConversationAssistant.swift` (line 22):
```swift
private var analysisInterval: TimeInterval = 10.0 // Change from 5.0 to 10.0
```

Modify GPT-5 Prompt:

Edit `ConversationAssistant.swift` lines 190-250 to change:
- Question detection logic
- Answer formatting style
- Suggestion generation approach
- Words per line (currently 3)

Change Display Format:

Edit `formatForGlasses()` in `ConversationAssistant.swift` (line 304):
```swift
// Increase chars per line (default 20)
if text.count > 30 {
    return String(text.prefix(28)) + ".."
}
```

Switch AI Models:

In `OpenAIService.swift`:
- Line 149: Change `"gpt-5"` to another Responses API model
- Line 212: Change `"gpt-4o"` to another Chat model (e.g., `"gpt-4-turbo"`)

Disable Web Search:

In `ChatViewModel.swift` (line 254):
```swift
let response = try await openAIService.sendChatRequest(
    question: prompt, 
    enableWebSearch: false  // Change from true to false
)
```

## Troubleshooting

### Glasses Won't Connect

- Check glasses are powered on and charged
- Verify macOS Bluetooth is enabled (System Settings → Bluetooth)
- Restart glasses (power off/on)
- Rescan in the app after restart
- Look for paired devices named "Pair_X" (X = channel number)
- Verify both left and right peripherals are discovered

### No Voice Recognition

- Grant microphone permission (System Settings → Privacy & Security → Microphone)
- Grant speech recognition permission (Privacy & Security → Speech Recognition)
- Check Xcode console for speech errors
- Verify glasses mic is sending data (look for `0xF1` packets in console)
- Check PCM conversion logs

### Conversation Assistant Not Working

- Ensure glasses are connected before starting listening mode
- Check that OpenAI API key has GPT-5 access
- Look for "Analyzing conversation" logs in console
- Verify transcript is updating in app UI
- Check for "Got response with web search" in console
- Note: Analysis stops if no speech for >30 seconds

### API Errors

- **401 Unauthorized**: Check API key is valid and loaded
  - Look for "Loaded API key from..." in console
  - Verify `.env` file exists and contains `OPENAI_API_KEY=sk-...`
- **403 Forbidden**: GPT-5 access may not be enabled for your account
  - Falls back to GPT-4o for non-web-search requests
- **429 Rate Limit**: Too many requests, wait and retry
- **500 Server Error**: OpenAI service issue, retry later
- Check internet connection
- Review OpenAI account quotas and billing status

### Glasses Display Issues

- **No text appears**: Check BLE connection status (both L/R must be connected)
- **Garbled text**: Verify CRC checksum calculation
- **Truncated text**: Response may be too long, check packet splitting logic
- **Text not updating**: Look for "Sent XXX bytes to L/R" in console
- Try shorter responses (edit GPT prompt to request briefer answers)

### Console Logs

Press `⌘⇧Y` in Xcode to view logs. Key indicators:

- Voice recognition activity
- BLE send/receive operations
- Conversation analysis progress
- Success/error messages
- GPT-5 web search operations
- Glasses display formatting

## Known Limitations

- GPT-5 Latency: Web search takes 5-10 seconds for first analysis
- Transcript Accuracy: Speech recognition works best in quiet environments
- Display Width: Glasses have ~488px width limit (21pt font ≈ 18-20 chars/line)
- Audio Quality: LC3 codec quality depends on Bluetooth connection strength
- Question Detection: May occasionally misclassify statements as questions

## Future Enhancements

- Multi-language support (currently English only)
- Context retention across sessions (conversation memory)
- Custom wake words (instead of button press)
- Offline mode (cached responses)
- Voice feedback (text-to-speech to glasses speakers)
- Domain-specific prompt engineering

## License

See [LICENSE](LICENSE) file.

## Credits

Built with:
- [Even Realities G1 SDK](https://docs.evenrealities.com/) - BLE protocol documentation
- [OpenAI API](https://platform.openai.com/) - GPT-5 with web search, GPT-4o
- LC3 codec implementation - Bluetooth LE audio decoding
- Apple Speech Framework - On-device speech recognition

## Reference Documentation

- `EVEN_REALITIES_DOC.md` - Detailed BLE protocol specs from Even Realities
- `gpt5_websearch.md` - OpenAI Responses API documentation
- `EvenDemoApp-main/` - Original Flutter demo (reference implementation)

---

**Note**: This is a native Swift rewrite of the original Flutter demo app with GPT-5 conversation assistant capabilities, real-time web search, and continuous listening mode.
