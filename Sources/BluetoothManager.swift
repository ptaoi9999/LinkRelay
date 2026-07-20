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
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var transferCharacteristic: CBMutableCharacteristic?
    
    // Message Store reference
    private let messageStore: MessageStore
    
    // Simple Symmetric Key for Demo (Store-and-Forward Mesh Encryption)
    private let symmetricKey: SymmetricKey
    
    // State Tracking
    private var discoveredPeripherals = Set<CBPeripheral>()
    private var connectedPeripherals = [UUID: CBPeripheral]()
    private var pendingOutgoingPayloads: [Data] = []
    
    public init(messageStore: MessageStore) {
        self.messageStore = messageStore
        // Simple 256-bit key derived from a static phrase for encryption/decryption
        let keyData = "LinkRelayMeshPreSharedKey12345678".data(using: .utf8)!
        self.symmetricKey = SymmetricKey(data: SHA256.hash(data: keyData))
        
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
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
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        addLog("Started scanning...")
    }
    
    public func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        addLog("Stopped scanning.")
    }
    
    public func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "LinkRelayNode"
        ]
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        addLog("Started advertising...")
    }
    
    public func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        addLog("Stopped advertising.")
    }
    
    // Send a new local message
    public func sendMessage(_ text: String, sender: String) {
        let message = RelayMessage(text: text, sender: sender, hopCount: 1)
        messageStore.addMessage(message)
        encryptAndBroadcast(message)
    }
    
    // Encrypt and store in advertisement payload / characteristic data
    private func encryptAndBroadcast(_ message: RelayMessage) {
        do {
            let encoder = JSONEncoder()
            let rawData = try encoder.encode(message)
            
            // AES-GCM Encryption
            let sealedBox = try AES.GCM.seal(rawData, using: symmetricKey)
            let combinedData = sealedBox.combined
            
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
            peripheralManager.updateValue(data, for: char, onSubscribedCentrals: nil)
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
            // Decrypt AES-GCM
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            
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
        switch central.state {
        case .poweredOn:
            addLog("Central state: Powered On")
            startScanning()
        case .poweredOff:
            addLog("Central state: Powered Off")
            stopScanning()
        default:
            addLog("Central state changed: \(central.state.rawValue)")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        // Prevent infinite loops or spam
        guard !discoveredPeripherals.contains(peripheral) else { return }
        discoveredPeripherals.insert(peripheral)
        addLog("Discovered peer: \(peripheral.name ?? "Unknown Device")")
        
        // Connect to read characteristics
        centralManager.connect(peripheral, options: nil)
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
        switch peripheral.state {
        case .poweredOn:
            addLog("Peripheral state: Powered On")
            
            // Set up BLE Service and Characteristic
            let characteristic = CBMutableCharacteristic(
                type: Self.characteristicUUID,
                properties: [.read, .write, .notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            let service = CBMutableService(type: Self.serviceUUID, primary: true)
            service.characteristics = [characteristic]
            
            peripheralManager.add(service)
            self.transferCharacteristic = characteristic
            
            startAdvertising()
        case .poweredOff:
            addLog("Peripheral state: Powered Off")
            stopAdvertising()
        default:
            addLog("Peripheral state changed: \(peripheral.state.rawValue)")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                handleIncomingPayload(data)
                peripheralManager.respond(to: request, withResult: .success)
            }
        }
    }
}
