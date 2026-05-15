#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth
import CryptoKit

/// CoreBluetooth client for the MeshX BLE transport per `docs/WIRE_FORMAT.md` §1.
///
/// Connect/discover/subscribe, MXB1 chunking, and Noise frame handling are
/// wired. Hardware-dependent behavior (MTU negotiation timing, retry on
/// transient failures, reconnect handling) is still marked TODO.
public enum MeshxBLEUUID {
    public static let service = CBUUID(string: "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000")
    public static let rx      = CBUUID(string: "8f4f1202-6f3d-4f9c-9e3b-7f4a4f0f1000")
    public static let tx      = CBUUID(string: "8f4f1203-6f3d-4f9c-9e3b-7f4a4f0f1000")
}

public struct MeshxLegacyBeaconAdvertisement: Sendable, Equatable {
    public static let manufacturerCompanyIdentifier: UInt16 = 0xFFFF
    public static let manufacturerDataAdType: UInt8 = 0xFF
    public static let payloadSize = 22

    public var beaconVersion: UInt8
    public var envelopeVersion: UInt8
    public var payloadKind: String
    public var messageIdHash: Data
    public var senderPeerIdHash: Data
    public var beaconPayload: Data
    public var manufacturerData: Data
    public var advertisement: Data

    public static func parse(manufacturerData: Data) -> MeshxLegacyBeaconAdvertisement? {
        guard manufacturerData.count >= 2 + payloadSize else { return nil }
        let companyIdentifier = UInt16(manufacturerData[0]) | (UInt16(manufacturerData[1]) << 8)
        guard companyIdentifier == manufacturerCompanyIdentifier else { return nil }

        let payload = manufacturerData.subdata(in: 2..<(2 + payloadSize))
        guard payload.count == payloadSize,
              payload[payload.startIndex] == 0x4D,
              payload[payload.startIndex + 1] == 0x42 else {
            return nil
        }

        let payloadKind: String = payload[payload.startIndex + 4] == 1 ? "TX" : "unknown"

        var advertisement = Data(capacity: manufacturerData.count + 2)
        advertisement.append(UInt8(manufacturerData.count + 1))
        advertisement.append(manufacturerDataAdType)
        advertisement.append(manufacturerData)

        return MeshxLegacyBeaconAdvertisement(
            beaconVersion: payload[payload.startIndex + 2],
            envelopeVersion: payload[payload.startIndex + 3],
            payloadKind: payloadKind,
            messageIdHash: payload.subdata(in: (payload.startIndex + 6)..<(payload.startIndex + 14)),
            senderPeerIdHash: payload.subdata(in: (payload.startIndex + 14)..<(payload.startIndex + 22)),
            beaconPayload: payload,
            manufacturerData: manufacturerData,
            advertisement: advertisement
        )
    }

    /// Build a legacy beacon (`MB` magic) advertisement from envelope
    /// coordinates — the send-side counterpart of `parse`.
    ///
    /// This is the iOS counterpart of the Android
    /// `BleDispatcher.legacyBeaconPayload` helper; the byte layout is
    /// pinned by `WIRE_FORMAT.md` §10 and the on-air format is identical
    /// across the fleet so an Android scanner can decode an iOS-sent
    /// beacon and vice versa.
    ///
    /// `messageIdHash` and `senderPeerIdHash` are derived as
    /// `sha256(messageId)[0..8]` and `sha256(senderPeerId UTF-8)[0..8]`
    /// — exactly what the Android side does, so the same physical
    /// message produces matching hashes on both platforms.
    public static func build(
        messageId: Data,
        senderPeerId: String,
        payloadKind: String = "TX",
        envelopeVersion: UInt8 = 1,
        beaconVersion: UInt8 = 1
    ) -> MeshxLegacyBeaconAdvertisement {
        let messageHash = Data(SHA256.hash(data: messageId)).prefix(8)
        let senderHash = Data(SHA256.hash(data: Data(senderPeerId.utf8))).prefix(8)
        let kindCode: UInt8 = payloadKind.uppercased() == "TX" ? 1 : 0

        var beaconPayload = Data(capacity: payloadSize)
        beaconPayload.append(0x4D) // 'M'
        beaconPayload.append(0x42) // 'B'
        beaconPayload.append(beaconVersion)
        beaconPayload.append(envelopeVersion)
        beaconPayload.append(kindCode)
        beaconPayload.append(0x00) // reserved flags
        beaconPayload.append(contentsOf: messageHash)
        beaconPayload.append(contentsOf: senderHash)

        precondition(beaconPayload.count == payloadSize, "beacon payload must be \(payloadSize) bytes")

        // Manufacturer data the way CBAdvertisementDataManufacturerDataKey
        // expects it: little-endian 2-byte company id followed by the
        // payload. Matches the parse-side `manufacturerData` layout.
        var manufacturerData = Data(capacity: 2 + payloadSize)
        manufacturerData.append(UInt8(manufacturerCompanyIdentifier & 0xFF))
        manufacturerData.append(UInt8((manufacturerCompanyIdentifier >> 8) & 0xFF))
        manufacturerData.append(beaconPayload)

        // Full AD structure: [length, type, manufacturerData] — same
        // wrapping `parse` reconstructs, so build+parse round-trips.
        var advertisement = Data(capacity: 2 + manufacturerData.count)
        advertisement.append(UInt8(manufacturerData.count + 1))
        advertisement.append(manufacturerDataAdType)
        advertisement.append(manufacturerData)

        let resolvedKind = kindCode == 1 ? "TX" : payloadKind

        return MeshxLegacyBeaconAdvertisement(
            beaconVersion: beaconVersion,
            envelopeVersion: envelopeVersion,
            payloadKind: resolvedKind,
            messageIdHash: Data(messageHash),
            senderPeerIdHash: Data(senderHash),
            beaconPayload: beaconPayload,
            manufacturerData: manufacturerData,
            advertisement: advertisement
        )
    }
}

public protocol MeshxBLEClientDelegate: AnyObject {
    func meshxDidConnect(peerId: String)
    func meshxDidDisconnect(peerId: String)
    func meshxDidReceive(frame: Data, from peerId: String)
    func meshxDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    )
    func meshxDidError(_ error: Error)
}

public extension MeshxBLEClientDelegate {
    func meshxDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {}
}

public final class MeshxBLEClient: NSObject {
    public weak var delegate: MeshxBLEClientDelegate?

    private let central: CBCentralManager
    private let reassembler = ChunkReassembler()
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var rxCharacteristics: [UUID: CBCharacteristic] = [:]
    private var txCharacteristics: [UUID: CBCharacteristic] = [:]
    private var secureSessions: [UUID: MeshxSecureSession] = [:]
    private var establishedPeers: Set<UUID> = []
    private var streamCounter: UInt32 = 1
    private var shouldScan = false

    public override init() {
        // The central manager dispatch queue can be customized; default works
        // for a CLI/test harness, but production iOS apps should pass a
        // dedicated serial queue.
        self.central = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.central.delegate = self
    }

    /// Begin scanning once Bluetooth is powered on.
    public func startScan() {
        shouldScan = true
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                delegate?.meshxDidError(BLEError.stateNotPoweredOn(central.state))
            }
            return
        }

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func stopScan() {
        shouldScan = false
        central.stopScan()
    }

    /// Sends a complete MeshX frame to a peer without applying Noise.
    public func send(frame: Data, to peerId: String) throws {
        try write(frame: frame, to: peerId)
    }

    /// Encrypts and sends an application packet to an established peer.
    public func send(packet: Packet, to peerId: String) throws {
        guard let uuid = UUID(uuidString: peerId),
              let session = secureSessions[uuid],
              session.isEstablished else {
            throw BLEError.handshakeIncomplete(peerId)
        }

        let frame = try session.encrypt(packet: packet)
        try write(frame: frame, to: peerId)
    }

    private func write(frame: Data, to peerId: String) throws {
        guard let uuid = UUID(uuidString: peerId),
              let peripheral = peripherals[uuid],
              let rxChar = rxCharacteristics[uuid] else {
            throw BLEError.unknownPeer(peerId)
        }

        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let streamId = nextStreamId()
        let chunks = Chunk.encode(frame: frame, mtu: mtu, streamId: streamId)
        for chunk in chunks {
            peripheral.writeValue(chunk, for: rxChar, type: .withoutResponse)
        }
    }

    private func beginHandshake(with peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        guard rxCharacteristics[uuid] != nil else { return }
        guard txCharacteristics[uuid]?.isNotifying == true else { return }
        guard secureSessions[uuid] == nil else { return }

        let session = MeshxSecureSession(role: .initiator)
        secureSessions[uuid] = session

        do {
            if let frame = try session.startHandshake(msgId: nextStreamId()) {
                try write(frame: frame, to: uuid.uuidString)
            }
        } catch {
            secureSessions.removeValue(forKey: uuid)
            delegate?.meshxDidError(error)
        }
    }

    private func handleAssembledFrame(_ frame: Data, from peripheral: CBPeripheral) {
        let uuid = peripheral.identifier
        let session = secureSessions[uuid] ?? {
            let responder = MeshxSecureSession(role: .responder)
            secureSessions[uuid] = responder
            return responder
        }()

        do {
            let events = try session.receive(frame: frame, replyMsgId: nextStreamId())
            for event in events {
                switch event {
                case .outgoingFrame(let frame):
                    try write(frame: frame, to: uuid.uuidString)

                case .established:
                    if establishedPeers.insert(uuid).inserted {
                        delegate?.meshxDidConnect(peerId: uuid.uuidString)
                    }

                case .applicationFrame(let frame):
                    delegate?.meshxDidReceive(frame: frame, from: uuid.uuidString)
                }
            }
        } catch {
            delegate?.meshxDidError(error)
        }
    }

    private func nextStreamId() -> UInt32 {
        defer { streamCounter &+= 1 }
        return streamCounter
    }

    public enum BLEError: Error {
        case unknownPeer(String)
        case stateNotPoweredOn(CBManagerState)
        case handshakeIncomplete(String)
    }
}

extension MeshxBLEClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TODO: surface state transitions to the delegate; production iOS
        // apps must handle .unauthorized (info.plist usage description
        // missing) and .poweredOff explicitly with user-visible UI.
        if central.state == .poweredOn, shouldScan {
            startScan()
        } else if shouldScan && central.state != .poweredOn && central.state != .unknown && central.state != .resetting {
            delegate?.meshxDidError(BLEError.stateNotPoweredOn(central.state))
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           let beacon = MeshxLegacyBeaconAdvertisement.parse(manufacturerData: manufacturerData) {
            delegate?.meshxDidObserveLegacyBeacon(
                beacon,
                deviceId: peripheral.identifier.uuidString,
                rssi: RSSI.intValue
            )
            return
        }

        guard advertisesMeshxService(advertisementData) else { return }
        peripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    private func advertisesMeshxService(_ advertisementData: [String : Any]) -> Bool {
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let overflowUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []
        return serviceUUIDs.contains(MeshxBLEUUID.service) || overflowUUIDs.contains(MeshxBLEUUID.service)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([MeshxBLEUUID.service])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let peerId = peripheral.identifier.uuidString
        rxCharacteristics.removeValue(forKey: peripheral.identifier)
        txCharacteristics.removeValue(forKey: peripheral.identifier)
        secureSessions.removeValue(forKey: peripheral.identifier)
        establishedPeers.remove(peripheral.identifier)
        reassembler.forget(peerId: peerId)
        delegate?.meshxDidDisconnect(peerId: peerId)
        // TODO: reconnect strategy. For mesh, we usually want to retry
        // unless the user explicitly forgot the peer.
    }
}

extension MeshxBLEClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { delegate?.meshxDidError(error); return }
        guard let service = peripheral.services?.first(where: { $0.uuid == MeshxBLEUUID.service }) else { return }
        peripheral.discoverCharacteristics([MeshxBLEUUID.rx, MeshxBLEUUID.tx], for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error { delegate?.meshxDidError(error); return }
        for char in service.characteristics ?? [] {
            if char.uuid == MeshxBLEUUID.rx {
                rxCharacteristics[peripheral.identifier] = char
            }
            if char.uuid == MeshxBLEUUID.tx {
                txCharacteristics[peripheral.identifier] = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        beginHandshake(with: peripheral)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error { delegate?.meshxDidError(error); return }
        guard characteristic.uuid == MeshxBLEUUID.tx else { return }
        txCharacteristics[peripheral.identifier] = characteristic
        beginHandshake(with: peripheral)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error { delegate?.meshxDidError(error); return }
        guard characteristic.uuid == MeshxBLEUUID.tx,
              let chunk = characteristic.value else { return }
        let peerId = peripheral.identifier.uuidString
        if let assembled = reassembler.push(peerId: peerId, chunk: chunk) {
            handleAssembledFrame(assembled, from: peripheral)
        }
    }
}

public protocol MeshxBLEPeripheralDelegate: AnyObject {
    func meshxPeripheralDidStartAdvertising()
    func meshxPeripheralDidStopAdvertising()
    func meshxPeripheralDidConnect(peerId: String)
    func meshxPeripheralDidDisconnect(peerId: String)
    func meshxPeripheralDidReceive(frame: Data, from peerId: String)
    func meshxPeripheralDidError(_ error: Error)
}

public final class MeshxBLEPeripheral: NSObject {
    public weak var delegate: MeshxBLEPeripheralDelegate?

    private let manager: CBPeripheralManager
    private let reassembler = ChunkReassembler()
    private var rxCharacteristic: CBMutableCharacteristic?
    private var txCharacteristic: CBMutableCharacteristic?
    private var centrals: [UUID: CBCentral] = [:]
    private var secureSessions: [UUID: MeshxSecureSession] = [:]
    private var establishedPeers: Set<UUID> = []
    private var pendingNotifications: [(central: CBCentral, chunk: Data)] = []
    private var requestedLocalName: String?
    private var serviceConfigured = false
    private var shouldAdvertise = false
    private var streamCounter: UInt32 = 1

    public override init() {
        self.manager = CBPeripheralManager(delegate: nil, queue: nil)
        super.init()
        self.manager.delegate = self
    }

    public func startAdvertising(localName: String = "meshx-mobile") {
        requestedLocalName = localName
        shouldAdvertise = true

        guard manager.state == .poweredOn else {
            if manager.state != .unknown && manager.state != .resetting {
                delegate?.meshxPeripheralDidError(PeripheralError.stateNotPoweredOn(manager.state))
            }
            return
        }

        configureServiceIfNeeded()
        if serviceConfigured {
            startAdvertisingIfReady()
        }
    }

    public func stopAdvertising() {
        let wasActive = shouldAdvertise || manager.isAdvertising
        shouldAdvertise = false
        manager.stopAdvertising()
        if wasActive {
            delegate?.meshxPeripheralDidStopAdvertising()
        }
    }

    public func send(packet: Packet, to peerId: String) throws {
        guard let uuid = UUID(uuidString: peerId),
              let central = centrals[uuid],
              let session = secureSessions[uuid],
              session.isEstablished else {
            throw PeripheralError.handshakeIncomplete(peerId)
        }

        let frame = try session.encrypt(packet: packet)
        notify(frame: frame, to: central)
    }

    private func configureServiceIfNeeded() {
        guard !serviceConfigured, rxCharacteristic == nil, txCharacteristic == nil else { return }

        let rx = CBMutableCharacteristic(
            type: MeshxBLEUUID.rx,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let tx = CBMutableCharacteristic(
            type: MeshxBLEUUID.tx,
            properties: [.notify],
            value: nil,
            permissions: []
        )
        let service = CBMutableService(type: MeshxBLEUUID.service, primary: true)
        service.characteristics = [rx, tx]

        rxCharacteristic = rx
        txCharacteristic = tx
        manager.add(service)
    }

    private func startAdvertisingIfReady() {
        guard shouldAdvertise, serviceConfigured, !manager.isAdvertising else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [MeshxBLEUUID.service],
            CBAdvertisementDataLocalNameKey: requestedLocalName ?? "meshx-mobile"
        ])
    }

    /// Advertise a MeshX legacy beacon (advert-only profile, `MB` magic).
    ///
    /// Replaces any currently-running advertisement on this peripheral
    /// — CoreBluetooth only supports one advertising payload per
    /// `CBPeripheralManager`. Caller is responsible for sequencing
    /// against the GATT-service advert (typically: stop GATT advert,
    /// run beacon for ~5s window, restart GATT advert) — mirrors the
    /// Android `BleDispatcher` 5-second send window.
    ///
    /// Manufacturer data is the only field set; `CoreBluetooth`
    /// silently drops `CBAdvertisementDataManufacturerDataKey` when
    /// the app is backgrounded, so this method's effective range is
    /// foreground-active sessions — same operational envelope as
    /// Android's BleDispatcher under Doze.
    ///
    /// Returns the beacon that was advertised (for telemetry / dedup
    /// at the caller).
    @discardableResult
    public func startBeaconAdvertising(
        _ beacon: MeshxLegacyBeaconAdvertisement
    ) -> MeshxLegacyBeaconAdvertisement {
        guard manager.state == .poweredOn else {
            delegate?.meshxPeripheralDidError(PeripheralError.stateNotPoweredOn(manager.state))
            return beacon
        }

        if manager.isAdvertising {
            manager.stopAdvertising()
        }

        manager.startAdvertising([
            CBAdvertisementDataManufacturerDataKey: beacon.manufacturerData
        ])

        return beacon
    }

    /// Build + advertise a legacy beacon in one call.
    ///
    /// The send-side equivalent of `MeshxBLEClient.meshxDidObserveLegacyBeacon`:
    /// derive a beacon from envelope coordinates and put it on the air.
    /// Both ends agree on the byte layout per `WIRE_FORMAT.md §10`, so
    /// an iOS-sent beacon decodes cleanly on an Android scanner and
    /// vice versa.
    @discardableResult
    public func advertiseLegacyBeacon(
        messageId: Data,
        senderPeerId: String,
        payloadKind: String = "TX"
    ) -> MeshxLegacyBeaconAdvertisement {
        let beacon = MeshxLegacyBeaconAdvertisement.build(
            messageId: messageId,
            senderPeerId: senderPeerId,
            payloadKind: payloadKind
        )
        return startBeaconAdvertising(beacon)
    }

    private func handle(chunk: Data, from central: CBCentral) {
        let peerId = central.identifier.uuidString
        if let assembled = reassembler.push(peerId: peerId, chunk: chunk) {
            handleAssembledFrame(assembled, from: central)
        }
    }

    private func handleAssembledFrame(_ frame: Data, from central: CBCentral) {
        let uuid = central.identifier
        let session = secureSessions[uuid] ?? {
            let responder = MeshxSecureSession(role: .responder)
            secureSessions[uuid] = responder
            return responder
        }()

        do {
            let events = try session.receive(frame: frame, replyMsgId: nextStreamId())
            for event in events {
                switch event {
                case .outgoingFrame(let frame):
                    notify(frame: frame, to: central)

                case .established:
                    if establishedPeers.insert(uuid).inserted {
                        delegate?.meshxPeripheralDidConnect(peerId: uuid.uuidString)
                    }

                case .applicationFrame(let frame):
                    delegate?.meshxPeripheralDidReceive(frame: frame, from: uuid.uuidString)
                }
            }
        } catch {
            delegate?.meshxPeripheralDidError(error)
        }
    }

    private func notify(frame: Data, to central: CBCentral) {
        let mtu = max(Chunk.headerSize + 1, central.maximumUpdateValueLength)
        let chunks = Chunk.encode(frame: frame, mtu: mtu, streamId: nextStreamId())
        pendingNotifications.append(contentsOf: chunks.map { (central: central, chunk: $0) })
        flushNotifications()
    }

    private func flushNotifications() {
        guard let txCharacteristic else { return }

        while let next = pendingNotifications.first {
            let ok = manager.updateValue(
                next.chunk,
                for: txCharacteristic,
                onSubscribedCentrals: [next.central]
            )
            guard ok else { return }
            pendingNotifications.removeFirst()
        }
    }

    private func nextStreamId() -> UInt32 {
        defer { streamCounter &+= 1 }
        return streamCounter
    }

    public enum PeripheralError: Error {
        case stateNotPoweredOn(CBManagerState)
        case handshakeIncomplete(String)
    }
}

extension MeshxBLEPeripheral: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            configureServiceIfNeeded()
            startAdvertisingIfReady()
        } else if shouldAdvertise && peripheral.state != .unknown && peripheral.state != .resetting {
            delegate?.meshxPeripheralDidError(PeripheralError.stateNotPoweredOn(peripheral.state))
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            delegate?.meshxPeripheralDidError(error)
            return
        }

        serviceConfigured = true
        startAdvertisingIfReady()
    }

    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            delegate?.meshxPeripheralDidError(error)
        } else {
            delegate?.meshxPeripheralDidStartAdvertising()
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == MeshxBLEUUID.tx else { return }
        centrals[central.identifier] = central
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == MeshxBLEUUID.tx else { return }
        let peerId = central.identifier.uuidString
        centrals.removeValue(forKey: central.identifier)
        secureSessions.removeValue(forKey: central.identifier)
        establishedPeers.remove(central.identifier)
        reassembler.forget(peerId: peerId)
        delegate?.meshxPeripheralDidDisconnect(peerId: peerId)
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == MeshxBLEUUID.rx else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            guard let chunk = request.value else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }

            centrals[request.central.identifier] = request.central
            handle(chunk: chunk, from: request.central)
            peripheral.respond(to: request, withResult: .success)
        }
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushNotifications()
    }
}
#endif
