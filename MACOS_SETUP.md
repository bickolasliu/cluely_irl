# macOS Even AI App - Setup Guide

## Overview
This macOS app allows you to interact with Even Realities G1 AR glasses using voice or text input. Questions are sent to OpenAI's GPT-4 and responses are displayed on the glasses.

## What Was Implemented

### 1. OpenAI Integration ✅
- Switched from Alibaba Qwen to OpenAI GPT-4-turbo
- Added environment variable support with `flutter_dotenv`
- API key stored securely in `.env` file (not committed to git)

### 2. macOS Bluetooth Support ✅
- Ported iOS CoreBluetooth implementation to macOS
- Supports dual BLE connection (left and right glasses)
- Method channels for Flutter-native communication
- Files added:
  - `macos/Runner/BluetoothManager.swift`
  - `macos/Runner/ServiceIdentifiers.swift`
  - `macos/Runner/GattProtocal.swift`
  - `macos/Runner/PcmConverter.h` and `.m`
  - `macos/Runner/lc3/` (audio codec)
  - `macos/Runner/Runner-Bridging-Header.h`

### 3. macOS Speech Recognition ✅
- Ported iOS speech recognition to macOS
- Uses Apple's Speech framework for voice commands
- Processes LC3 audio from glasses microphone
- File added: `macos/Runner/SpeechStreamRecognizer.swift`

### 4. Text Input UI ✅
- Added text input field and Send button to home page
- Allows testing AI responses without voice input
- Displays results in app and sends to glasses
- Updates in `lib/views/home_page.dart`

### 5. Permissions & Entitlements ✅
- Updated `macos/Runner/Info.plist` with privacy descriptions
- Updated entitlements for Bluetooth, microphone, and network access
- Both Debug and Release entitlements configured

## Setup Instructions

### 1. Install Dependencies
```bash
cd /Users/nicholasliu/Documents/coretsu/even_realities
flutter pub get
```

### 2. Configure OpenAI API Key
Create a `.env` file in the project root:
```bash
echo "OPENAI_API_KEY=your_actual_openai_api_key_here" > .env
```

Replace `your_actual_openai_api_key_here` with your OpenAI API key from https://platform.openai.com/api-keys

### 3. Build and Run
```bash
# For debug build
flutter run -d macos

# For release build
flutter build macos --release
```

## Usage

### Connecting to Glasses
1. Launch the app on macOS
2. Click "Not connected" area to start scanning for glasses
3. Select your paired glasses from the list (e.g., "Pair_XXX")
4. Wait for connection confirmation

### Voice Mode
1. Once connected, long press the left TouchBar on glasses
2. Speak your question (up to 30 seconds)
3. Release when finished
4. AI response will appear on glasses automatically

### Text Mode (Testing)
1. Type your question in the text field at the bottom
2. Click "Send" or press Enter
3. Response appears in app and on glasses

### Controls
- **Single tap left**: Previous page
- **Single tap right**: Next page
- **Double tap**: Exit AI mode
- **Long press left**: Start voice input

## File Structure

### Modified Files
- `lib/services/api_services.dart` - OpenAI integration
- `lib/services/evenai.dart` - Updated to use ApiService
- `lib/main.dart` - Added dotenv loading
- `lib/views/home_page.dart` - Added text input UI
- `macos/Runner/AppDelegate.swift` - Method channels setup
- `macos/Runner/Info.plist` - Privacy permissions
- `macos/Runner/DebugProfile.entitlements` - Debug permissions
- `macos/Runner/Release.entitlements` - Release permissions
- `pubspec.yaml` - Added flutter_dotenv dependency
- `.gitignore` - Added .env exclusion

### New Files
- `.env.example` - Template for environment variables
- `macos/Runner/BluetoothManager.swift`
- `macos/Runner/ServiceIdentifiers.swift`
- `macos/Runner/GattProtocal.swift`
- `macos/Runner/SpeechStreamRecognizer.swift`
- `macos/Runner/PcmConverter.h` and `.m`
- `macos/Runner/Runner-Bridging-Header.h`
- `macos/Runner/lc3/` - LC3 audio codec library

## Troubleshooting

### Bluetooth Not Working
- Check that Bluetooth is enabled in System Settings
- Grant Bluetooth permission when prompted
- Restart the app if connection fails

### Speech Recognition Not Working
- Grant Microphone permission when prompted
- Grant Speech Recognition permission in System Settings
- Check Console logs for error messages

### OpenAI API Errors
- Verify your API key in `.env` file
- Check your OpenAI account has credits
- Ensure you have internet connection
- Check network permissions in entitlements

### Build Errors
- Run `flutter clean` and `flutter pub get`
- Check Xcode project for missing files
- Ensure all Swift files are added to target

## Notes

- The app uses on-device speech recognition (requires macOS 10.15+)
- GPT-4-turbo responses are limited to 500 tokens for AR display
- System prompt optimized for concise responses
- Dual Bluetooth connection required (left and right glasses)
- LC3 audio codec handles microphone data from glasses

## Next Steps

To further customize:
1. Adjust `max_tokens` in `api_services.dart` for longer/shorter responses
2. Modify system prompt in `api_services.dart` for different AI behavior
3. Change model to `gpt-4` or `gpt-3.5-turbo` for cost/performance trade-offs
4. Customize UI colors and layout in `home_page.dart`

## Support

For issues with:
- Even Realities protocol: See README.md
- OpenAI API: https://platform.openai.com/docs
- Flutter macOS: https://docs.flutter.dev/platform-integration/macos/building

