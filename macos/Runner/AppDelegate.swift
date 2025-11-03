import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Even GPT macOS app launched")

        // Set up Bluetooth event handlers for glasses commands
        BluetoothManager.shared.onStartVoiceInput = {
            print("📱 AppDelegate: Starting voice recognition from glasses")
            SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")
        }

        BluetoothManager.shared.onStopVoiceInput = {
            print("📱 AppDelegate: Stopping voice recognition from glasses")
            SpeechStreamRecognizer.shared.stopRecognition()
        }

        BluetoothManager.shared.onBLEDataReceived = { data in
            print("BLE data received: \(data)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
