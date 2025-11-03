# Xcode Configuration Steps - Remove Flutter Dependencies

## The Problem
The build is failing because the project still has Flutter build scripts that are looking for deleted Flutter files.

## Solution: Remove Flutter Target Dependency

Follow these steps carefully:

### Step 1: Open Xcode
```bash
cd /Users/nicholasliu/Documents/coretsu/even_realities/macos
open Runner.xcodeproj
```

### Step 2: Remove Flutter Assemble Dependency

1. In Xcode left sidebar, click on the **Runner** project (blue icon at top)
2. In the middle panel, select **Runner** under TARGETS (not PROJECTS)
3. Go to **Build Phases** tab
4. Look for **Dependencies** section
5. Find "Flutter Assemble" in the list
6. Click the **-** (minus) button to remove it

### Step 3: Remove Flutter Build Scripts

Still in **Build Phases**, scroll through and look for:
- Any script phase named "Run Script" that contains Flutter commands
- Remove or disable them by unchecking "Run script only when installing"

### Step 4: Add New Swift Files to Build

1. Still in **Build Phases** tab
2. Expand **Compile Sources**
3. Click the **+** button
4. Add these NEW files if they're missing:
   - `EvenGPTApp.swift`
   - `ContentView.swift`
   - `ChatViewModel.swift`
   - `OpenAIService.swift`

5. **Remove** this file if present:
   - `MainFlutterWindow.swift` (we deleted this)
   - `GeneratedPluginRegistrant.swift` (Flutter-generated)

### Step 5: Check Framework References

1. Go to **Build Phases** > **Link Binary With Libraries**
2. **Remove** if present:
   - `FlutterMacOS.framework`
   - `App.framework`

3. **Ensure these are present** (add if missing):
   - `CoreBluetooth.framework`
   - `Speech.framework`
   - `AVFoundation.framework`
   - `Foundation.framework`
   - `AppKit.framework`
   - `SwiftUI.framework`

### Step 6: Update Build Settings

1. Go to **Build Settings** tab
2. Search for "Framework Search Paths"
3. Remove any paths containing "Flutter"
4. Search for "Header Search Paths"
5. Remove any paths containing "Flutter"

### Step 7: Fix Swift Version

1. Still in **Build Settings**
2. Search for "Swift Language Version"
3. Set to **Swift 5**

### Step 8: Remove Flutter Assemble Target Completely

1. In left sidebar project navigator, look at the project structure
2. Click on **Runner** project (blue icon)
3. In middle panel under TARGETS, right-click **Flutter Assemble**
4. Select **Delete** (choose "Move to Trash")

### Step 9: Clean Build

1. Go to menu: **Product > Clean Build Folder** (⇧⌘K)
2. Or hold **Shift + Command + K**

### Step 10: Try Building

1. Select **Runner** scheme from the scheme dropdown (top toolbar)
2. Select **My Mac** as destination
3. Click **Run** button (▶️) or press **⌘R**

---

## Alternative: Quick Command-Line Fix

If you prefer to stay in the terminal, I can create a simple workaround:

```bash
cd /Users/nicholasliu/Documents/coretsu/even_realities/macos
# This creates a dummy Flutter script that does nothing
mkdir -p Flutter
echo "#!/bin/bash" > Flutter/flutter_export_environment.sh
echo "exit 0" >> Flutter/flutter_export_environment.sh
chmod +x Flutter/flutter_export_environment.sh
```

But the proper fix is to remove the Flutter Assemble target as described above.

---

## After Successful Build

Once it builds, test:
1. Grant Bluetooth permission when prompted
2. Grant Microphone permission when prompted
3. Grant Speech Recognition permission when prompted
4. Try typing a test question and clicking Send
5. Verify response appears in the window

---

## Need Help?

If you get stuck on any step, let me know which step number and what error you see!
