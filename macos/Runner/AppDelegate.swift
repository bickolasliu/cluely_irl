import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Cluely IRL macOS app launched")

        // Set up Bluetooth event handlers for glasses commands
        BluetoothManager.shared.onStartVoiceInput = {
            print("📱 AppDelegate: Starting voice recognition from glasses")

            // Send command to activate glasses microphone (0x0E 0x01)
            let micOnCommand = Data([0x0E, 0x01])
            BluetoothManager.shared.sendData(data: micOnCommand, lr: "R") // Right side mic
            print("🎤 Sent microphone activation command to glasses")

            // Start speech recognition
            SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")
        }

        BluetoothManager.shared.onStopVoiceInput = {
            print("📱 AppDelegate: Stopping voice recognition from glasses")
            SpeechStreamRecognizer.shared.stopRecognition()

            // Send command to deactivate glasses microphone (0x0E 0x00)
            let micOffCommand = Data([0x0E, 0x00])
            BluetoothManager.shared.sendData(data: micOffCommand, lr: "R")
            print("🎤 Sent microphone deactivation command to glasses")
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
