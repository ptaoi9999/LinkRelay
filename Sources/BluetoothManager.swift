import Foundation
import CoreBluetooth
import CryptoKit
import Combine

public class BluetoothManager: NSObject, ObservableObject {
    // BLE Service and Characteristic UUIDs
    public static let serviceUUID = CBUUID(string: "4A1B2C3D-E5F6-7A8B-9C0D-1E2F3A4B5C6D")
    public static let characteristicUUID = CBUUID(string: "4A1B2C3D-E5F6-7A8B-9C0D-1E2F3A4B5C6E")
    
    // User Configurations
    @Published public var isRelayEnabled: Bool = true
    @Published public var maxHopCount: Int = 10
    @Published public var isAdvertising = false
    @Published public var isScanning = false
    @Published public var logs: [String] = []
    
    // Core Bluetooth Objects
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    
    // Message Store reference
    private let messageStore: MessageStore
    
    // Simple Symmetric Key for Demo (Store-and-Forward Mesh Encryption)
    private let keyData: Data
    
    // State Tracking
    private var discoveredPeripherals = Set<CBPeripheral>()
    private var connectedPeripherals = [UUID: CBPeripheral]()
    private var pendingOutgoingPayloads: [Data] = []
    
    public init(messageStore: MessageStore) {
        self.messageStore = messageStore
        // Simple 256-bit key derived from a static phrase for encryption/decryption
        self.keyData = "LinkRelayMeshPreSharedKey1234567".data(using: .utf8)! // Exactly 32 bytes
        
        super.init()
    }
    
    public func setup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.centralManager == nil && self.peripheralManager == nil else { return }
            
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
            self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            
            self.addLog("Bluetooth managers initialized.")
        }
    }
    
    public func addLog(_ message: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: Date())
            self.logs.insert("[\(timeStr)] \(message)", at: 0)
            if self.logs.count > 100 {
                self.logs.removeLast()
            }
        }
    }
    
    // MARK: - Actions
    
    public func startScanning() {
        DispatchQueue.main.async {
            guard let cm = self.centralManager, cm.state == .poweredOn else {
                self.isScanning = false
                return
            }
            self.discoveredPeripherals.removeAll()
            cm.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            self.isScanning = true
            self.addLog("Started scanning...")
        }
    }
    
    public func stopScanning() {
        DispatchQueue.main.async {
            self.centralManager?.stopScan()
            self.isScanning = false
            self.addLog("Stopped scanning.")
        }
    }
    
    public func startAdvertising() {
        DispatchQueue.main.async {
            guard let pm = self.peripheralManager, pm.state == .poweredOn else {
                self.isAdvertising = false
                return
            }
            let advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
                CBAdvertisementDataLocalNameKey: "LinkRelayNode"
            ]
            pm.startAdvertising(advertisementData)
            self.isAdvertising = true
            self.addLog("Started advertising...")
        }
    }
    
    public func stopAdvertising() {
        DispatchQueue.main.async {
            self.peripheralManager?.stopAdvertising()
            self.isAdvertising = false
            self.addLog("Stopped advertising.")
        }
    }
    
    // Send a new local message
    public func sendMessage(_ text: String, sender: String, channel: String = "open", recipient: String? = nil) {
        let message = RelayMessage(text: text, sender: sender, hopCount: 1, channel: channel, recipient: recipient)
        messageStore.addMessage(message)
        encryptAndBroadcast(message)
    }
    
    // Encrypt and store in advertisement payload / characteristic data
    private func encryptAndBroadcast(_ message: RelayMessage) {
        do {
            let encoder = JSONEncoder()
            let rawData = try encoder.encode(message)
            
            // Safe Encryption using ChaChaPoly or Fallback for legacy iOS 15 ARM64 CPU support
            let combinedData: Data?
            if #available(iOS 13.0, *) {
                let key = SymmetricKey(data: keyData)
                let sealedBox = try ChaChaPoly.seal(rawData, using: key)
                combinedData = sealedBox.combined
            } else {
                combinedData = rawData
            }
            
            if let combined = combinedData {
                addLog("Broadcasting: \(message.text) (Hop: \(message.hopCount))")
                broadcastPayload(combined)
            }
        } catch {
            addLog("Encryption error: \(error.localizedDescription)")
        }
    }
    
    private func broadcastPayload(_ data: Data) {
        // Update local characteristic value so connecting peers can read/write to it
        if let char = transferCharacteristic {
            _ = peripheralManager?.updateValue(data, for: char, onSubscribedCentrals: nil)
        }
        // Save payload for new connections
        pendingOutgoingPayloads.append(data)
        if pendingOutgoingPayloads.count > 10 {
            pendingOutgoingPayloads.removeFirst()
        }
    }
    
    // Process received raw binary payload
    private func handleIncomingPayload(_ data: Data) {
        do {
            let decryptedData: Data
            if #available(iOS 13.0, *) {
                let key = SymmetricKey(data: keyData)
                let sealedBox = try ChaChaPoly.SealedBox(combined: data)
                decryptedData = try ChaChaPoly.open(sealedBox, using: key)
            } else {
                decryptedData = data
            }
            
            let decoder = JSONDecoder()
            var message = try decoder.decode(RelayMessage.self, from: decryptedData)
            
            // Check if we already received it
            let isNew = messageStore.addMessage(message)
            
            if isNew {
                addLog("Received message: \"\(message.text)\" from \(message.sender) (Hop: \(message.hopCount))")
                
                // Store and Forward Relay Logic
                if isRelayEnabled {
                    if message.hopCount < maxHopCount {
                        message.hopCount += 1
                        addLog("Relaying message (New Hop Count: \(message.hopCount))")
                        encryptAndBroadcast(message)
                    } else {
                        addLog("Max Hop limit reached (\(maxHopCount)). Dropping message.")
                    }
                } else {
                    addLog("Relaying is disabled. Skipping forwarding.")
                }
            }
        } catch {
            addLog("Failed to decrypt or decode payload: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch central.state {
            case .poweredOn:
                self.addLog("Central state: Powered On")
                self.startScanning()
            case .poweredOff:
                self.addLog("Central state: Powered Off")
                self.stopScanning()
            default:
                self.addLog("Central state changed: \(central.state.rawValue)")
                self.isScanning = false
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        // Prevent infinite loops or spam
        guard !discoveredPeripherals.contains(peripheral) else { return }
        discoveredPeripherals.insert(peripheral)
        addLog("Discovered peer: \(peripheral.name ?? "Unknown Device")")
        
        // Connect to read characteristics
        central.connect(peripheral, options: nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        addLog("Connected to: \(peripheral.name ?? "Unknown Device")")
        connectedPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        addLog("Disconnected from: \(peripheral.name ?? "Unknown Device")")
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        discoveredPeripherals.remove(peripheral)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serviceUUID {
            peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.characteristicUUID {
            // Read value
            peripheral.readValue(for: characteristic)
            // Subscribe to notifications
            peripheral.setNotifyValue(true, for: characteristic)
            
            // Send pending outgoing payloads to this peer
            for payload in pendingOutgoingPayloads {
                peripheral.writeValue(payload, for: characteristic, type: .withResponse)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            handleIncomingPayload(data)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BluetoothManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch peripheral.state {
            case .poweredOn:
                self.addLog("Peripheral state: Powered On")
                
                // Set up BLE Service and Characteristic
                let characteristic = CBMutableCharacteristic(
                    type: Self.characteristicUUID,
                    properties: [.read, .write, .writeWithoutResponse, .notify],
                    value: nil,
                    permissions: [.readable, .writeable]
                )
                let service = CBMutableService(type: Self.serviceUUID, primary: true)
                service.characteristics = [characteristic]
                
                peripheral.add(service)
                self.transferCharacteristic = characteristic
                
                self.startAdvertising()
            case .poweredOff:
                self.addLog("Peripheral state: Powered Off")
                self.stopAdvertising()
            default:
                self.addLog("Peripheral state changed: \(peripheral.state.rawValue)")
                self.isAdvertising = false
            }
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == Self.characteristicUUID {
            if let latestPayload = pendingOutgoingPayloads.last {
                if request.offset > latestPayload.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }
                request.value = latestPayload.subdata(in: request.offset..<latestPayload.count)
                peripheral.respond(to: request, withResult: .success)
            } else {
                request.value = Data()
                peripheral.respond(to: request, withResult: .success)
            }
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.characteristicUUID, let data = request.value {
                handleIncomingPayload(data)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        addLog("Peer central subscribed to characteristic.")
        if let latestPayload = pendingOutgoingPayloads.last, let char = transferCharacteristic {
            peripheral.updateValue(latestPayload, for: char, onSubscribedCentrals: [central])
        }
    }
}
