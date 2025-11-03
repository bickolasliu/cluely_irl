# Even GPT - Native macOS App for Even Realities G1 Glasses

A native Swift/SwiftUI macOS application that acts as a GPT-4 wrapper for Even Realities G1 AR glasses. Voice input from glasses → GPT-4 processing → visual response on glasses display.

## Features

- 🎤 **Voice Input** - Hold app button or long-press glasses TouchBar to speak questions
- 🤖 **GPT-4 Integration** - Powered by OpenAI's GPT-4 Turbo API
- 🥽 **Dual Display** - Responses shown in macOS app AND on AR glasses
- 📡 **Bluetooth Connectivity** - Direct BLE communication with G1 glasses
- 🗣️ **On-Device Speech Recognition** - Privacy-focused local speech processing
- 📝 **Chat History** - Track all Q&A sessions

## Requirements

- **macOS 11.0+** (Big Sur or later)
- **Xcode 14.0+**
- **Even Realities G1 Glasses**
- **OpenAI API Key** ([Get one here](https://platform.openai.com/api-keys))

## Quick Start

### 1. Configure API Key

Create a `.env` file in the project root:

```bash
echo "OPENAI_API_KEY=your-api-key-here" > .env
```

### 2. Open in Xcode

```bash
cd macos
open Runner.xcodeproj
```

### 3. Build & Run

- Press **⌘R** or click the ▶️ Play button
- Grant permissions when prompted:
  - ✅ Bluetooth
  - ✅ Microphone
  - ✅ Speech Recognition

### 4. Connect Glasses

1. Click the connection status in the app
2. Click "Scan for Glasses"
3. Select your G1 glasses from the list
4. Wait for "Connected" status

### 5. Ask Questions

**From App:**
- Type question in text field → Click Send

**From Glasses:**
- Long-press left TouchBar → Speak → Release
- View response on glasses display and in app

## Project Structure

```
macos/
├── Runner.xcodeproj/           # Xcode project
└── Runner/
    ├── EvenGPTApp.swift       # App entry point
    ├── AppDelegate.swift       # App lifecycle & BLE event handlers
    ├── ContentView.swift       # SwiftUI main interface
    ├── ChatViewModel.swift     # State management & chat logic
    ├── OpenAIService.swift     # GPT-4 API client
    ├── BluetoothManager.swift  # BLE protocol for G1 glasses
    ├── SpeechStreamRecognizer.swift  # Voice recognition
    ├── ServiceIdentifiers.swift      # BLE UUIDs
    ├── GattProtocal.swift     # BLE helpers
    ├── PcmConverter.h/m       # Audio format conversion
    ├── Runner-Bridging-Header.h     # Obj-C bridge
    ├── lc3/                   # LC3 audio codec (34 files)
    ├── Assets.xcassets/       # App icons
    ├── Info.plist            # App metadata
    └── *.entitlements        # Permissions
```

## BLE Protocol (Even G1)

### Commands Sent to Glasses

| Command | Purpose | Format |
|---------|---------|--------|
| `0x0E 0x01` | Activate microphone | `[0x0E, 0x01]` |
| `0x0E 0x00` | Deactivate microphone | `[0x0E, 0x00]` |
| `0x4E ...` | Send text/AI response | See below |

### Text Display Protocol (0x4E)

```
[0x4E, seq, total_pkg, current_pkg, newscreen, pos_hi, pos_lo, cur_page, max_page, ...text..., crc_lo, crc_hi]
```

**Fields:**
- `newscreen`: `0x31` = new content + AI displaying
- `cur_page` / `max_page`: Pagination support
- CRC-16 checksum for data integrity

### Commands Received from Glasses

| Command | Gesture | Action |
|---------|---------|--------|
| `0xF5 0x00` | Double tap | Exit/close feature |
| `0xF5 0x01` | Single tap | Page navigation |
| `0xF5 0x11` | Long-press left | Start voice input |
| `0xF1 ...` | Audio stream | LC3-encoded mic data |

## Architecture

### Voice Input Flow

```
Glasses (Long-press)
  → BLE: 0xF5 0x11
  → App sends: 0x0E 0x01 (activate mic)
  → Glasses streams LC3 audio
  → LC3 Decoder → PCM
  → Speech Recognition
  → GPT-4 API
  → Response → 0x4E packets
  → Glasses Display
```

### Components

- **SwiftUI**: Modern declarative UI
- **Combine**: Reactive state management
- **CoreBluetooth**: BLE communication
- **Speech Framework**: On-device speech recognition
- **LC3 Codec**: Bluetooth LE audio codec (C library)
- **URLSession**: Async/await API calls

## Development

### Key Files

**UI Layer:**
- `EvenGPTApp.swift` - App definition & window config
- `ContentView.swift` - Main UI (scanning, chat, input)
- `ChatViewModel.swift` - Business logic & state

**Services:**
- `OpenAIService.swift` - GPT-4 API client
- `BluetoothManager.swift` - G1 BLE protocol
- `SpeechStreamRecognizer.swift` - Voice → text

**Native Code:**
- `PcmConverter.m` - LC3 → PCM audio conversion
- `lc3/*.c` - LC3 codec implementation

### Customization

**Adjust GPT Prompts:**

Edit `OpenAIService.swift` line 50:
```swift
"messages": [
    ["role": "system", "content": "Your custom system prompt"],
    ["role": "user", "content": question]
]
```

**Change Response Length:**

Edit `OpenAIService.swift` line 54:
```swift
"max_tokens": 500  // Adjust for longer/shorter responses
```

**UI Styling:**

Modify `ContentView.swift` colors, fonts, layout

## Troubleshooting

### Glasses Won't Connect
- Ensure glasses are powered on
- Check macOS Bluetooth is enabled
- Try restarting glasses and app
- Check System Settings → Bluetooth for permissions

### No Voice Recognition
- Grant microphone permission in System Settings → Privacy & Security
- Grant speech recognition permission
- Check console for speech recognition errors
- Verify glasses mic is sending data (check for PCM logs)

### API Errors
- Verify `.env` file exists with valid API key
- Check internet connection
- Review OpenAI API quotas/billing
- Check console for detailed error messages

### Glasses Display Not Working
- Verify protocol format matches G1 specs
- Check console for "✅ Sent XXX bytes" messages
- Ensure CRC checksum is correct
- Try shorter text responses

### Check Console Logs

Press **⌘⇧Y** in Xcode to open console and look for:
- `🎤` Voice recognition logs
- `📤` BLE send logs
- `✅` Success indicators
- `❌` Error messages

## License

See [LICENSE](LICENSE) file.

## Credits

Built with:
- [Even Realities G1 SDK](https://docs.evenrealities.com/)
- [OpenAI API](https://platform.openai.com/)
- LC3 codec implementation

---

**Note**: This is a native Swift rewrite of the original Flutter demo app, optimized for macOS with enhanced BLE protocol handling and modern async/await patterns.
