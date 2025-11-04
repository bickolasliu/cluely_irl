import SwiftUI

@main
struct CluelyIRLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @StateObject private var chatViewModel = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(bluetoothManager)
                .environmentObject(chatViewModel)
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with connection status
            connectionBar

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Conversation Assistant").tag(0)
                Text("Connection").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            TabView(selection: $selectedTab) {
                ConversationAssistantView()
                    .tag(0)

                ConnectionView()
                    .tag(1)
            }
            .tabViewStyle(.automatic)
        }
    }

    private var connectionBar: some View {
        HStack {
            Text("Cluely IRL")
                .font(.title3)
                .bold()

            Spacer()

            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(bluetoothManager.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(bluetoothManager.isConnected ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ConnectionView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        ContentView()
    }
}
