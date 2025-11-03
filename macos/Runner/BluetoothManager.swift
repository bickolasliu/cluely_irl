import CoreBluetooth

struct PairedGlasses {
    let channelNumber: String
    let leftDeviceName: String
    let rightDeviceName: String
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()

    @Published var pairedGlasses: [PairedGlasses] = []
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Not connected"

    var centralManager: CBCentralManager!
    private var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    private var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    private var currentConnectingDeviceName: String?

    var onBLEDataReceived: (([String: Any]) -> Void)?
    var onStartVoiceInput: (() -> Void)?
    var onStopVoiceInput: (() -> Void)?

    var leftPeripheral:CBPeripheral?
    var leftUUIDStr:String?
    var rightPeripheral:CBPeripheral?
    var rightUUIDStr:String?

    var UARTServiceUUID:CBUUID
    var UARTRXCharacteristicUUID:CBUUID
    var UARTTXCharacteristicUUID:CBUUID

    var leftWChar:CBCharacteristic?
    var rightWChar:CBCharacteristic?
    var leftRChar:CBCharacteristic?
    var rightRChar:CBCharacteristic?

    var hasStartedSpeech = false
    var pcmPacketCount = 0
    var recordingStartTime: Date?
    var autoStopTimer: Timer?
    var speechRecognitionFailed = false
    var heartbeatTimer: Timer?
    var heartbeatSeq: UInt8 = 0

    override init() {
        UARTServiceUUID          = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)

        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan(result: @escaping (Result<String, Error>) -> Void) {
        guard centralManager.state == .poweredOn else {
            result(.failure(NSError(domain: "BluetoothManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not powered on."])))
            return
        }

        centralManager.scanForPeripherals(withServices: nil, options: nil)
        result(.success("Scanning for devices..."))
    }

    func stopScan(result: @escaping (Result<String, Error>) -> Void) {
        centralManager.stopScan()
        result(.success("Scan stopped"))
    }

    func connectToDevice(deviceName: String, result: @escaping (Result<String, Error>) -> Void) {
        centralManager.stopScan()

        guard let peripheralPair = pairedDevices[deviceName] else {
            result(.failure(NSError(domain: "BluetoothManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Device not found"])))
            return
        }

        guard let leftPeripheral = peripheralPair.0, let rightPeripheral = peripheralPair.1 else {
            result(.failure(NSError(domain: "BluetoothManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "One or both peripherals are not found"])))
            return
        }

        currentConnectingDeviceName = deviceName

        centralManager.connect(leftPeripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
        centralManager.connect(rightPeripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])

        DispatchQueue.main.async {
            self.connectionStatus = "Connecting to \(deviceName)..."
        }
        result(.success("Connecting to \(deviceName)..."))
    }

    func disconnectFromGlasses(result: @escaping (Result<String, Error>) -> Void) {
        // Stop heartbeat
        stopHeartbeat()

        for (_, devices) in connectedDevices {
            if let leftPeripheral = devices.0 {
                centralManager.cancelPeripheralConnection(leftPeripheral)
            }
            if let rightPeripheral = devices.1 {
                centralManager.cancelPeripheralConnection(rightPeripheral)
            }
        }
        connectedDevices.removeAll()
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Not connected"
        }
        result(.success("Disconnected all devices."))
    }

    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        let components = name.components(separatedBy: "_")
        guard components.count > 1, let channelNumber = components[safe: 1] else { return }

        if name.contains("_L_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].0 = peripheral // Left device
        } else if name.contains("_R_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].1 = peripheral // Right device
        }

        if let leftPeripheral = pairedDevices["Pair_\(channelNumber)"]?.0, let rightPeripheral = pairedDevices["Pair_\(channelNumber)"]?.1 {
            let glasses = PairedGlasses(
                channelNumber: channelNumber,
                leftDeviceName: leftPeripheral.name ?? "",
                rightDeviceName: rightPeripheral.name ?? ""
            )

            DispatchQueue.main.async {
                // Only add if not already in list
                if !self.pairedGlasses.contains(where: { $0.channelNumber == channelNumber }) {
                    self.pairedGlasses.append(glasses)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let deviceName = currentConnectingDeviceName else { return }
        guard let peripheralPair = pairedDevices[deviceName] else { return }

        if connectedDevices[deviceName] == nil {
            connectedDevices[deviceName] = (nil, nil)
        }

        if peripheralPair.0 === peripheral {
            connectedDevices[deviceName]?.0 = peripheral // Left device connected

            self.leftPeripheral = peripheral
            self.leftPeripheral?.delegate = self
            self.leftPeripheral?.discoverServices([UARTServiceUUID])

            self.leftUUIDStr = peripheral.identifier.uuidString;

            print("didConnect----self.leftPeripheral---------\(self.leftPeripheral)--self.leftUUIDStr----\(self.leftUUIDStr)----")
        } else if peripheralPair.1 === peripheral {
            connectedDevices[deviceName]?.1 = peripheral // Right device connected

            self.rightPeripheral = peripheral
            self.rightPeripheral?.delegate = self
            self.rightPeripheral?.discoverServices([UARTServiceUUID])

            self.rightUUIDStr = peripheral.identifier.uuidString

            print("didConnect----self.rightPeripheral---------\(self.rightPeripheral)---self.rightUUIDStr----\(self.rightUUIDStr)-----")
        }

        if let leftPeripheral = connectedDevices[deviceName]?.0, let rightPeripheral = connectedDevices[deviceName]?.1 {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionStatus = "Connected:\nLeft: \(leftPeripheral.name ?? "")\nRight: \(rightPeripheral.name ?? "")"
            }
            currentConnectingDeviceName = nil
            // Heartbeat will start after characteristics are discovered
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        print("\(Date()) didDisconnectPeripheral-----peripheral-----\(peripheral)--")
        
        if let error = error {
            print("Disconnect error: \(error.localizedDescription)")
        } else {
            print("Disconnected without error.")
        }
        
        central.connect(peripheral, options: nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("peripheral------\(peripheral)-----didDiscoverServices--------")
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid .isEqual(UARTServiceUUID){
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("peripheral------\(peripheral)-----didDiscoverCharacteristicsFor----service----\(service)----")
        guard let characteristics = service.characteristics else { return }

        if service.uuid.isEqual(UARTServiceUUID){
            for characteristic in characteristics {
                if characteristic.uuid.isEqual(UARTRXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftRChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightRChar = characteristic
                    }
                } else if characteristic.uuid.isEqual(UARTTXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftWChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightWChar = characteristic
                    }
                }
            }
            
            if(peripheral.identifier.uuidString == self.leftUUIDStr){
                if(self.leftRChar != nil && self.leftWChar != nil){
                    self.leftPeripheral?.setNotifyValue(true, for: self.leftRChar!)

                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "L")

                    // If both sides are ready, start heartbeat
                    if self.rightRChar != nil && self.rightWChar != nil && heartbeatTimer == nil {
                        print("💓 Both glasses ready - starting heartbeat messages (every 8 seconds)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.startHeartbeat()
                        }
                    }
                }
            }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                if(self.rightRChar != nil && self.rightWChar != nil){
                    self.rightPeripheral?.setNotifyValue(true, for: self.rightRChar!)
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "R")

                    // If both sides are ready, start heartbeat
                    if self.leftRChar != nil && self.leftWChar != nil && heartbeatTimer == nil {
                        print("💓 Both glasses ready - starting heartbeat messages (every 8 seconds)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.startHeartbeat()
                        }
                    }
                }
            }
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("subscribe fail: \(error)")
            return
        }
        if characteristic.isNotifying {
            print("subscribe success")
        } else {
            print("subscribe cancel")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
        case .poweredOff:
            print("Bluetooth is powered off.")
        default:
            print("Bluetooth state is unknown or unsupported.")
        }
    }
    
    
    func stopRecordingWithTimeout() {
        print("🛑 Stopping recording (timeout or manual)")
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        pcmPacketCount = 0
        recordingStartTime = nil

        // Send mic off command
        let micOffCommand = Data([0x0E, 0x00])
        sendData(data: micOffCommand, lr: "R")
        print("🎤 Sent microphone deactivation command")

        // Stop speech recognition
        SpeechStreamRecognizer.shared.stopRecognition()
    }

    func startHeartbeat() {
        // Stop existing timer
        heartbeatTimer?.invalidate()
        heartbeatSeq = 0

        // Send heartbeat every 8 seconds
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }

        // Send first heartbeat immediately
        sendHeartbeat()
    }

    func sendHeartbeat() {
        // Heartbeat format: [0x25, length_lo, length_hi, seq, 0x04, seq]
        let length: UInt16 = 6
        let packet = Data([
            0x25,
            UInt8(length & 0xFF),
            UInt8((length >> 8) & 0xFF),
            heartbeatSeq,
            0x04,
            heartbeatSeq
        ])

        heartbeatSeq = heartbeatSeq &+ 1 // Wrapping increment

        // Send to left first, then right
        sendData(data: packet, lr: "L")
        sendData(data: packet, lr: "R")

        print("💓 Heartbeat sent (seq: \(heartbeatSeq - 1))")
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("💔 Heartbeat stopped")
    }

    func sendData(data: Data, lr: String? = nil) -> Bool {
        return writeData(writeData: data, lr: lr)
    }

    func writeData(writeData: Data, cbPeripheral: CBPeripheral? = nil, lr: String? = nil) -> Bool {
        if lr == "L" {
            guard let leftPeripheral = self.leftPeripheral, leftPeripheral.state == .connected, let leftWChar = self.leftWChar else {
                print("⚠️ Cannot write to LEFT: peripheral not connected or characteristic nil (state: \(self.leftPeripheral?.state.rawValue ?? -1))")
                return false
            }
            leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
            return true
        }
        if lr == "R" {
            guard let rightPeripheral = self.rightPeripheral, rightPeripheral.state == .connected, let rightWChar = self.rightWChar else {
                print("⚠️ Cannot write to RIGHT: peripheral not connected or characteristic nil (state: \(self.rightPeripheral?.state.rawValue ?? -1))")
                return false
            }
            rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
            return true
        }

        // Send to both
        var leftSuccess = false
        var rightSuccess = false

        if let leftPeripheral = self.leftPeripheral, leftPeripheral.state == .connected, let leftWChar = self.leftWChar {
            leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
            leftSuccess = true
        } else {
            print("⚠️ Cannot write to LEFT: not connected or characteristic nil")
        }

        if let rightPeripheral = self.rightPeripheral, rightPeripheral.state == .connected, let rightWChar = self.rightWChar {
            rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
            rightSuccess = true
        } else {
            print("⚠️ Cannot write to RIGHT: not connected or characteristic nil")
        }

        return leftSuccess && rightSuccess
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("\(Date()) didWriteValueFor----characteristic---\(characteristic)---- \(error!)")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("\(Date()) didWriteValueFor----------- \(error!)")
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("\(Date()) didUpdateValueFor------\(peripheral.identifier.uuidString)----\(peripheral.name)-----\(characteristic.value)--")
        let data = characteristic.value
        self.getCommandValue(data: data!,cbPeripheral: peripheral)
    }
    
    func getCommandValue(data:Data,cbPeripheral:CBPeripheral? = nil){
        let rspCommand = AG_BLE_REQ(rawValue: (data[0]))
        switch rspCommand{
            case .BLE_REQ_TRANSFER_MIC_DATA:
                 // Only process PCM data if speech recognition is already active
                 // (started by command 23 from glasses)
                 if !SpeechStreamRecognizer.shared.isRecording {
                     // Ignore PCM data if not actively recording
                     // This can happen if glasses send residual data after connection
                     return
                 }

                 // Only log every 10th packet to reduce spam
                 pcmPacketCount += 1
                 if pcmPacketCount % 10 == 1 {
                     let elapsed = recordingStartTime.map { Int(-$0.timeIntervalSinceNow) } ?? 0
                     print("🎵 Recording: \(pcmPacketCount) packets (\(elapsed)s)")
                 }

                 let effectiveData = data.subdata(in: 2..<data.count)
                 let pcmConverter = PcmConverter()
                 var pcmData = pcmConverter.decode(effectiveData)

                 let inputData = pcmData as Data
                 SpeechStreamRecognizer.shared.appendPCMData(inputData)

                 break
            default:
                // Check for control commands (0xF5 prefix)
                if data.count >= 2 && data[0] == 0xF5 {
                    let commandIndex = data[1]
                    let hexCommand = String(format: "0x%02X", commandIndex)

                    switch commandIndex {
                    case 0: // Exit feature
                        print("Received BLE command: 0xF5 \(hexCommand) (decimal: \(commandIndex))")
                        print("🚪 Exit command (double tap)")
                        // TODO: Handle exit
                    case 1: // Page navigation
                        print("Received BLE command: 0xF5 \(hexCommand) (decimal: \(commandIndex))")
                        let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
                        print("📄 Page navigation - \(isLeft ? "Previous" : "Next") page")
                        // TODO: Handle page navigation
                    case 9, 10, 17: // Initialization/status commands sent by glasses on connection
                        // Silently ignore - these are not user actions
                        break
                    case 23: // 0x17 hex = 23 decimal - Start voice input (long-press left button)
                        print("Received BLE command: 0xF5 \(hexCommand) (decimal: \(commandIndex))")
                        print("🎤 Glasses triggered voice input START (cmd 23) - User pressed left button")
                        pcmPacketCount = 0
                        recordingStartTime = Date()
                        speechRecognitionFailed = false // Reset in case user enabled dictation

                        // Set auto-stop timer (30 seconds max)
                        autoStopTimer?.invalidate()
                        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                            print("⏱️ Auto-stopping recording after 30 seconds")
                            self?.stopRecordingWithTimeout()
                        }

                        onStartVoiceInput?()
                    case 24: // 0x18 hex = 24 decimal - Stop voice input
                        print("Received BLE command: 0xF5 \(hexCommand) (decimal: \(commandIndex))")
                        print("🛑 Glasses triggered voice input STOP (cmd 24)")
                        autoStopTimer?.invalidate()
                        onStopVoiceInput?()
                    default:
                        print("⚠️ Unknown BLE command: \(commandIndex) (hex: \(hexCommand))")
                    }
                }

                let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
                let legStr = isLeft ? "L" : "R"

                // Log the actual data bytes for debugging
                let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("📥 BLE Response from \(legStr): \(hexString) (\(data.count) bytes)")

                // Check for acknowledgment or error responses
                if data.count >= 2 && data[0] == 0xC9 {
                    print("✅ Received acknowledgment (0xC9) from glasses")
                } else if data.count >= 2 && data[0] == 0x4E {
                    print("📝 Received 0x4E response - possible text display acknowledgment")
                }

                var dictionary = [String: Any]()
                dictionary["type"] = "type"
                dictionary["lr"] = legStr
                dictionary["data"] = data

                onBLEDataReceived?(dictionary)
                break
        }
    }

    // MARK: - Even AI Protocol Methods
    func sendEvenAIData(text: String, newScreen: UInt8, pos: Int, currentPage: Int, maxPage: Int) async -> Bool {
        print("📤 Sending to glasses: '\(text)' (page \(currentPage)/\(maxPage))")

        // Protocol: 0x4E for AI Result / Text Sending
        // Format: [cmd, seq, total_pkg, current_pkg, newscreen, pos_hi, pos_lo, cur_page, max_page, ...text_data..., crc_lo, crc_hi]

        var packet = Data()
        packet.append(0x4E) // Command: Send AI Result
        packet.append(0x00) // seq: sequence number (can be 0 for single packet)
        packet.append(0x01) // total_package_num: 1 (we're sending one package at a time)
        packet.append(0x00) // current_package_num: 0 (first/only package)
        packet.append(newScreen) // newscreen: status byte (e.g., 0x31 for "new content + AI displaying")
        packet.append(UInt8((pos >> 8) & 0xFF)) // new_char_pos0: high byte of position
        packet.append(UInt8(pos & 0xFF)) // new_char_pos1: low byte of position
        packet.append(UInt8(currentPage)) // current_page_num
        packet.append(UInt8(maxPage)) // max_page_num

        // Add text data
        if let textData = text.data(using: .utf8) {
            packet.append(textData)
        }

        // NOTE: NO CRC for 0x4E text command! (Only used for BMP image updates)
        // The working Flutter code does NOT add CRC for text display

        // Print detailed hex dump for debugging
        let hexString = packet.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("🔍 Hex dump of packet (\(packet.count) bytes):")
        print("   \(hexString)")
        print("   Header: 4E \(String(format: "%02X", packet[1])) \(String(format: "%02X", packet[2])) \(String(format: "%02X", packet[3])) \(String(format: "%02X", newScreen)) \(String(format: "%02X", packet[5])) \(String(format: "%02X", packet[6])) \(String(format: "%02X", currentPage)) \(String(format: "%02X", maxPage))")
        print("   Text length: \(text.utf8.count) bytes")

        // Send to LEFT first, then RIGHT (matching Flutter implementation)
        let leftSuccess = sendData(data: packet, lr: "L")
        if leftSuccess {
            print("✅ Sent \(packet.count) bytes to LEFT glasses")
        } else {
            print("❌ Failed to send to LEFT glasses")
        }

        // Small delay between left and right
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then send to RIGHT
        let rightSuccess = sendData(data: packet, lr: "R")
        if rightSuccess {
            print("✅ Sent \(packet.count) bytes to RIGHT glasses")
        } else {
            print("❌ Failed to send to RIGHT glasses")
        }

        return leftSuccess && rightSuccess
    }

    private func calculateCRC(data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if (crc & 0x0001) != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc = crc >> 1
                }
            }
        }
        return crc
    }
}

// Extension for safe array indexing
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
