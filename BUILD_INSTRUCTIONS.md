# Build & Run Instructions - Even GPT macOS App

## Prerequisites

1. **macOS 10.15 or later**
2. **Xcode 14.0+** (with Command Line Tools installed)
3. **CocoaPods** - Install if needed: `sudo gem install cocoapods`
4. **OpenAI API Key** - Make sure `.env` file exists with your API key

## Step 1: Install Dependencies

Open Terminal and navigate to the project directory:

```bash
cd /Users/nicholasliu/Documents/coretsu/even_realities
cd macos
pod install
```

This will install any CocoaPods dependencies (if any).

## Step 2: Open Xcode Project

Open the workspace (NOT the .xcodeproj):

```bash
open Runner.xcworkspace
```

If `.xcworkspace` doesn't exist, open the project directly:

```bash
open Runner.xcodeproj
```

## Step 3: Configure Xcode Project

Once Xcode opens, you need to add the new Swift files to the build:

### A. Check Build Phases

1. In Xcode, select the **Runner** project in the left sidebar
2. Select the **Runner** target
3. Go to **Build Phases** tab
4. Expand **Compile Sources**
5. Ensure these Swift files are included:
   - `EvenGPTApp.swift` ⭐ (NEW - Main entry point)
   - `AppDelegate.swift`
   - `ContentView.swift` ⭐ (NEW - UI)
   - `ChatViewModel.swift` ⭐ (NEW - View Model)
   - `OpenAIService.swift` ⭐ (NEW - API)
   - `BluetoothManager.swift`
   - `SpeechStreamRecognizer.swift`
   - `ServiceIdentifiers.swift`
   - `GattProtocal.swift`
   - `PcmConverter.m` (Objective-C)

6. **If any NEW files are missing**, click the **+** button and add them from the Runner folder.

### B. Remove Flutter References

1. In **Build Phases > Link Binary With Libraries**:
   - Remove any Flutter framework references if present
   - Keep CoreBluetooth, Speech, AVFoundation, Foundation, AppKit

2. In **Build Settings**:
   - Search for "Framework Search Paths"
   - Remove any Flutter-related paths

### C. Update Build Settings

1. Select **Runner** target
2. Go to **Build Settings** tab
3. Search for these settings and update:
   - **Product Name**: Set to `Even GPT` (or your preferred name)
   - **Product Bundle Identifier**: `com.yourdomain.evengpt` (change to your identifier)
   - **Deployment Target**: macOS 10.15 or higher
   - **Swift Language Version**: Swift 5

## Step 4: Verify Entitlements & Permissions

Check that entitlements are set correctly:

1. Select **Runner** target
2. Go to **Signing & Capabilities** tab
3. Ensure these capabilities are enabled:
   - ✅ App Sandbox
   - ✅ Network (Outgoing Connections - Client)
   - ✅ Bluetooth
   - ✅ Audio Input (Microphone)

The app also needs these usage descriptions in Info.plist (already configured):
- Bluetooth usage
- Microphone usage
- Speech recognition usage

## Step 5: Configure Signing

1. Select **Runner** target
2. Go to **Signing & Capabilities** tab
3. Under **Signing**, choose your development team
4. Xcode should automatically manage signing

## Step 6: Build the App

1. Select **Runner** scheme from the scheme selector (top toolbar)
2. Select **My Mac** as the destination
3. Click **Build** (⌘B) or **Run** (⌘R)

### Common Build Issues & Fixes

#### Issue: "No such module 'FlutterMacOS'"
**Fix**: Remove any remaining Flutter imports from Swift files. They should all be removed already.

#### Issue: LC3 codec compilation errors
**Fix**:
1. Go to Build Phases > Compile Sources
2. Find all `.c` files in the `lc3/` folder
3. Ensure they're included in the build

#### Issue: Bridging header errors
**Fix**:
1. Go to Build Settings
2. Search for "Objective-C Bridging Header"
3. Set to: `Runner/Runner-Bridging-Header.h`

#### Issue: Missing @main attribute
**Fix**: Verify `EvenGPTApp.swift` has `@main` attribute (it should).

## Step 7: Run & Test

Once the build succeeds:

1. **Run the app** (⌘R)
2. Grant permissions when prompted:
   - ✅ Bluetooth access
   - ✅ Microphone access
   - ✅ Speech recognition

### Testing Checklist

#### Without Glasses:
- [ ] App launches successfully
- [ ] Shows "Not connected" status
- [ ] Can type a question in text field
- [ ] Click "Send" sends to OpenAI and displays response
- [ ] Response appears in the window

#### With Glasses:
- [ ] Click connection status to scan
- [ ] Paired glasses appear in list
- [ ] Click glasses to connect
- [ ] Status shows "Connected: Left/Right device names"
- [ ] Type question → sends to GPT-4 → displays in app AND glasses
- [ ] Hold voice button in app → mic activates → release → processes speech
- [ ] Long-press left TouchBar on glasses → voice input → GPT response

### Keyboard Shortcuts (Future Enhancement)
- Press and hold **Space** to activate voice (can be added)

## Step 8: Troubleshooting

### App crashes on launch
- Check Console.app for crash logs
- Verify all Swift files compile without errors
- Check that `.env` file exists in project root

### "API key not found" error
- Verify `.env` file exists at: `/Users/nicholasliu/Documents/coretsu/even_realities/.env`
- Format: `OPENAI_API_KEY=sk-...`
- No quotes, no spaces around `=`

### Bluetooth doesn't find glasses
- Check glasses are powered on and in pairing mode
- Check macOS Bluetooth is enabled
- Check entitlements include Bluetooth permission
- Grant Bluetooth access when macOS prompts

### Speech recognition doesn't work
- Grant microphone permission when prompted
- Grant speech recognition permission
- Check System Preferences > Security & Privacy > Microphone
- Check System Preferences > Security & Privacy > Speech Recognition

### Voice button does nothing
- Check Console for speech recognition errors
- Verify `SpeechStreamRecognizer` is initialized
- Check microphone permission granted

### No response from OpenAI
- Check internet connection
- Verify API key is valid
- Check Console for network errors
- Test API key with curl:
  ```bash
  curl https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer YOUR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model": "gpt-4-turbo", "messages": [{"role": "user", "content": "Hello"}]}'
  ```

## File Structure

```
even_realities/
├── .env                                  # OpenAI API key
├── macos/
│   ├── Runner.xcodeproj/                # Xcode project
│   ├── Runner.xcworkspace/              # Workspace (if using Pods)
│   ├── Podfile                          # CocoaPods dependencies
│   └── Runner/
│       ├── EvenGPTApp.swift            # ⭐ Main app entry
│       ├── AppDelegate.swift            # App lifecycle
│       ├── ContentView.swift            # ⭐ Main UI
│       ├── ChatViewModel.swift          # ⭐ State management
│       ├── OpenAIService.swift          # ⭐ GPT-4 API
│       ├── BluetoothManager.swift       # BLE for glasses
│       ├── SpeechStreamRecognizer.swift # Voice input
│       ├── ServiceIdentifiers.swift     # BLE UUIDs
│       ├── GattProtocal.swift          # BLE protocol helpers
│       ├── PcmConverter.h/m            # Audio conversion
│       ├── Runner-Bridging-Header.h    # ObjC bridging
│       ├── lc3/                        # LC3 audio codec
│       ├── Info.plist                  # App metadata
│       └── *.entitlements              # Permissions
```

## Next Steps

After successful build:
1. Test with your Even Realities G1 glasses
2. Customize the UI in `ContentView.swift`
3. Adjust GPT prompts in `OpenAIService.swift`
4. Add keyboard shortcuts for voice input
5. Improve error handling and user feedback

## Support

If you encounter issues:
1. Check Console.app for error messages
2. Review Xcode build logs
3. Verify all permissions are granted
4. Test API key separately
5. Check glasses are properly paired with macOS
