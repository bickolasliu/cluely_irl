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
                }
            }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                if(self.rightRChar != nil && self.rightWChar != nil){
                    self.rightPeripheral?.setNotifyValue(true, for: self.rightRChar!)
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "R")
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
    
    
    func sendData(data: Data, lr: String? = nil) {
        writeData(writeData: data, lr: lr)
    }

    func writeData(writeData: Data, cbPeripheral: CBPeripheral? = nil, lr: String? = nil) {
        if lr == "L" {
            if self.leftWChar != nil {
                self.leftPeripheral?.writeValue(writeData, for: self.leftWChar!, type: .withoutResponse)
            }
            return
        }
        if lr == "R" {
            if self.rightWChar != nil {
                self.rightPeripheral?.writeValue(writeData, for: self.rightWChar!, type: .withoutResponse)
            }
            return
        }
        
        if let leftWChar = self.leftWChar {
            self.leftPeripheral?.writeValue(writeData, for: leftWChar, type: .withoutResponse)
        } else {
            print("writeData leftWChar is nil, cannot write data to right peripheral.")
        }

        if let rightWChar = self.rightWChar {
            self.rightPeripheral?.writeValue(writeData, for: rightWChar, type: .withoutResponse)
        } else {
            print("writeData rightWChar is nil, cannot write data to right peripheral.")
        }
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
                 // Auto-start recognition if not already started
                 if !SpeechStreamRecognizer.shared.isRecording {
                     print("🎤 PCM data detected - auto-starting recognition")
                     SpeechStreamRecognizer.shared.startRecognition(identifier: "EN")
                 }

                 let hexString = data.map { String(format: "%02hhx", $0) }.joined()
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
                    print("Received BLE command: 0xF5 \(commandIndex)")

                    switch commandIndex {
                    case 23: // Start voice input
                        print("🎤 Glasses triggered voice input START")
                        onStartVoiceInput?()
                    case 24: // Stop voice input
                        print("🛑 Glasses triggered voice input STOP")
                        onStopVoiceInput?()
                    default:
                        print("Unknown command index: \(commandIndex)")
                    }
                }

                let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
                let legStr = isLeft ? "L" : "R"
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

        // Add CRC-16 checksum (exclude CRC bytes themselves)
        let crc = calculateCRC(data: packet)
        packet.append(UInt8(crc & 0xFF)) // CRC low byte
        packet.append(UInt8((crc >> 8) & 0xFF)) // CRC high byte

        // Send to both glasses (left then right)
        sendData(data: packet, lr: nil)

        print("✅ Sent \(packet.count) bytes to glasses (0x4E protocol)")
        return true
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
