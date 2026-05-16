import Foundation
import CoreBluetooth
import Security
// MeshxLegacyBeaconAdvertisement, MeshxBLEClient, MeshxBLEPeripheral,
// Packet, Frame live in the local meshx_mobile Swift package.
// Under `xcodebuild`, the Xcode project pulls them in via the
// MeshxMobile package product (so `import MeshxMobile` is needed).
// Under `mix mob.deploy --native`, the shell script compiles every
// .swift file into a single module, so the import would fail. Use
// `canImport` to keep both paths working.
#if canImport(MeshxMobile)
import MeshxMobile
#endif

final class MeshxNativeBLEBridge: NSObject {
    static let shared = MeshxNativeBLEBridge()

    private var client: MeshxBLEClient?
    private var peripheral: MeshxBLEPeripheral?
    private var messageObserver: MessageAdvertisementObserver?
    private var centralPeers = Set<String>()
    private var peripheralPeers = Set<String>()
    private var messageId: UInt32 = 1

    func startScan() {
        ensureClient().startScan()
        ensureMessageObserver().startScan()
        emitStatus("Scanning")
    }

    func startAdvertising(localName: String) {
        ensurePeripheral().startAdvertising(localName: localName)
        emitStatus("Advertising as \(localName)")
    }

    func stop() {
        client?.stopScan()
        peripheral?.stopAdvertising()
        messageObserver?.stopScan()
        emitStatus("Stopped")
    }

    func sendPing(peerId: String, payload: Data) {
        let packet = Packet(type: .data, msgId: nextMessageId(), payload: payload)

        do {
            if centralPeers.contains(peerId), let client {
                try client.send(packet: packet, to: peerId)
                emitStatus("Ping sent")
                return
            }

            if peripheralPeers.contains(peerId), let peripheral {
                try peripheral.send(packet: packet, to: peerId)
                emitStatus("Ping sent")
                return
            }

            // No GATT-connected peer — fall back to the advert-only
            // profile. Mirrors Android's
            // `MeshxBleNative.sendToPeer(forceLegacyBeacon: true)` so
            // iOS and Android exchange message *references* even when
            // neither side has a paired GATT connection. The payload's
            // 16-byte messageId is derived from a random UUID; the
            // beacon carries the hash, not the bytes.
            dispatchLegacyBeacon(senderPeerId: peerId, payload: payload)
        } catch {
            emitError(String(describing: error))
        }
    }

    /// Build a legacy beacon from a payload and put it on the air via
    /// the peripheral's beacon advertise path. The 22-byte beacon
    /// carries `sha256(messageId)[0..8]` and
    /// `sha256(senderPeerId)[0..8]` — exact byte-compatibility with the
    /// Android side per `WIRE_FORMAT.md §10`.
    private func dispatchLegacyBeacon(senderPeerId: String, payload: Data) {
        var messageId = Data(count: 16)
        let result = messageId.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard result == errSecSuccess else {
            emitError("legacy beacon dispatch: SecRandomCopyBytes failed (\(result))")
            return
        }

        let peripheral = ensurePeripheral()
        peripheral.advertiseLegacyBeacon(
            messageId: messageId,
            senderPeerId: senderPeerId,
            payloadKind: "TX"
        )
        emitStatus("Beacon dispatched (\(payload.count)B payload referenced)")
    }

    private func ensureClient() -> MeshxBLEClient {
        if let client { return client }

        let client = MeshxBLEClient()
        client.delegate = self
        self.client = client
        return client
    }

    private func ensureMessageObserver() -> MessageAdvertisementObserver {
        if let messageObserver { return messageObserver }

        let observer = MessageAdvertisementObserver()
        observer.delegate = self
        self.messageObserver = observer
        return observer
    }

    private func ensurePeripheral() -> MeshxBLEPeripheral {
        if let peripheral { return peripheral }

        let peripheral = MeshxBLEPeripheral()
        peripheral.delegate = self
        self.peripheral = peripheral
        return peripheral
    }

    private func nextMessageId() -> UInt32 {
        defer { messageId &+= 1 }
        return messageId
    }

    private func emitStatus(_ status: String) {
        status.withCString { meshx_ble_emit_status($0) }
    }

    private func emitError(_ message: String) {
        message.withCString { meshx_ble_emit_error($0) }
    }

    private func emitReceived(frame: Data, peerId: String) {
        do {
            let (packet, rest) = try Frame.decode(frame)
            guard rest.isEmpty else {
                emitError("Received frame with trailing bytes")
                return
            }

            peerId.withCString {
                meshx_ble_emit_received($0, Int32(packet.type.rawValue), packet.msgId, UInt32(packet.payload.count))
            }
        } catch {
            emitError(String(describing: error))
        }
    }
}

extension MeshxNativeBLEBridge: MeshxBLEClientDelegate {
    func meshxDidConnect(peerId: String) {
        centralPeers.insert(peerId)
        peerId.withCString { meshx_ble_emit_connected($0) }
    }

    func meshxDidDisconnect(peerId: String) {
        centralPeers.remove(peerId)
        peerId.withCString { meshx_ble_emit_disconnected($0) }
    }

    func meshxDidReceive(frame: Data, from peerId: String) {
        emitReceived(frame: frame, peerId: peerId)
    }

    func meshxDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        deviceId.withCString { deviceIdPtr in
            beacon.payloadKind.withCString { payloadKindPtr in
                beacon.messageIdHash.withUnsafeBytes { messageHashBuffer in
                    beacon.senderPeerIdHash.withUnsafeBytes { senderHashBuffer in
                        beacon.advertisement.withUnsafeBytes { advertisementBuffer in
                            beacon.beaconPayload.withUnsafeBytes { beaconPayloadBuffer in
                                beacon.manufacturerData.withUnsafeBytes { manufacturerBuffer in
                                    meshx_ble_emit_received_message_beacon(
                                        deviceIdPtr,
                                        Int32(rssi),
                                        Int32(beacon.beaconVersion),
                                        Int32(beacon.envelopeVersion),
                                        payloadKindPtr,
                                        messageHashBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        senderHashBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        advertisementBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(beacon.advertisement.count),
                                        beaconPayloadBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(beacon.beaconPayload.count),
                                        manufacturerBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(beacon.manufacturerData.count),
                                        UInt32(MeshxLegacyBeaconAdvertisement.manufacturerCompanyIdentifier)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func meshxDidError(_ error: Error) {
        emitError(String(describing: error))
    }
}

extension MeshxNativeBLEBridge: MeshxBLEPeripheralDelegate {
    func meshxPeripheralDidStartAdvertising() {
        emitStatus("Advertising")
    }

    func meshxPeripheralDidStopAdvertising() {
        emitStatus("Stopped")
    }

    func meshxPeripheralDidConnect(peerId: String) {
        peripheralPeers.insert(peerId)
        peerId.withCString { meshx_ble_emit_connected($0) }
    }

    func meshxPeripheralDidDisconnect(peerId: String) {
        peripheralPeers.remove(peerId)
        peerId.withCString { meshx_ble_emit_disconnected($0) }
    }

    func meshxPeripheralDidReceive(frame: Data, from peerId: String) {
        emitReceived(frame: frame, peerId: peerId)
    }

    func meshxPeripheralDidError(_ error: Error) {
        emitError(String(describing: error))
    }
}

extension MeshxNativeBLEBridge: MessageAdvertisementObserverDelegate {
    func meshxDidObserveReceivedMessage(_ event: ReceivedMessageEvent) {
        let metadata = event.rawTransportMetadata

        event.receivedDeviceId.withCString { deviceIdPtr in
            event.senderPeerId.withCString { senderPtr in
                event.messageId.withUnsafeBytes { messageIdBuffer in
                    metadata.messagePayload.withUnsafeBytes { messagePayloadBuffer in
                        metadata.advertisement.withUnsafeBytes { advertisementBuffer in
                            metadata.manufacturerData.withUnsafeBytes { manufacturerBuffer in
                                let recipientCString = event.recipientPeerId.flatMap { $0.cString(using: .utf8) }

                                recipientCString.withOptionalCStringPointer { recipientPtr in
                                    meshx_ble_emit_received_message(
                                        deviceIdPtr,
                                        Int32(event.rssi),
                                        Int64(event.receivedAt),
                                        messageIdBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(event.messageId.count),
                                        senderPtr,
                                        recipientPtr,
                                        messagePayloadBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(metadata.messagePayload.count),
                                        advertisementBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(metadata.advertisement.count),
                                        messagePayloadBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(metadata.messagePayload.count),
                                        manufacturerBuffer.bindMemory(to: UInt8.self).baseAddress,
                                        UInt32(metadata.manufacturerData.count),
                                        UInt32(metadata.companyIdentifier)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func meshxDidObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int) {
        emitError("message_advertisement_decode_error[\(deviceId)@\(rssi)]: \(reason)")
    }

    func meshxMessageObserverDidStartScan() {}

    func meshxMessageObserverDidUpdateState(_ state: String) {
        emitStatus("MessageObserver state: \(state)")
    }

    func meshxMessageObserverDidError(_ error: Error) {
        emitError(String(describing: error))
    }

    func meshxMessageObserverDidFetchEnvelope(
        envelope: Data,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement,
        rssi: Int
    ) {
        // Synthesize a ReceivedMessageEvent from the fetched MX bytes so
        // we can reuse the existing meshx_ble_emit_received_message NIF
        // path. `MessageAdvertisement.decode` rejects bytes that aren't
        // wrapped in a manufacturer-data envelope, so parse the raw MX
        // envelope directly and build the event here.
        switch MessageEnvelope.parse(envelope) {
        case .success(let parsed):
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            let event = ReceivedMessageEvent(
                messageId: parsed.messageId,
                senderPeerId: parsed.senderPeerId,
                recipientPeerId: parsed.recipientPeerId,
                receivedDeviceId: fromDeviceId,
                receivedAt: now,
                rssi: rssi,
                envelope: parsed,
                rawTransportMetadata: .init(
                    transport: "ble_ios_gatt_fetch",
                    sourceEvent: "gatt_fetch_response",
                    receivedDeviceId: fromDeviceId,
                    advertisement: beacon.advertisement,
                    messagePayload: envelope,
                    manufacturerData: beacon.manufacturerData,
                    companyIdentifier: MeshxLegacyBeaconAdvertisement.manufacturerCompanyIdentifier,
                    adType: MeshxLegacyBeaconAdvertisement.manufacturerDataAdType
                )
            )
            meshxDidObserveReceivedMessage(event)
        case .failure(let reason):
            emitError("gatt_fetch_decode_error: \(reason)")
        }
    }

    func meshxMessageObserverDidFailFetch(
        reason: String,
        detail: String?,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement
    ) {
        emitStatus("Fetch failed [\(fromDeviceId)]: \(reason)\(detail.map { " (\($0))" } ?? "")")
    }
}

private extension Optional where Wrapped == [CChar] {
    func withOptionalCStringPointer<R>(_ body: (UnsafePointer<CChar>?) -> R) -> R {
        switch self {
        case .some(let chars):
            return chars.withUnsafeBufferPointer { buffer in
                body(buffer.baseAddress)
            }
        case .none:
            return body(nil)
        }
    }
}

@_cdecl("meshx_ble_start_scan")
public func meshx_ble_start_scan() {
    DispatchQueue.main.async {
        MeshxNativeBLEBridge.shared.startScan()
    }
}

@_cdecl("meshx_ble_start_advertising")
public func meshx_ble_start_advertising(_ localNamePtr: UnsafePointer<CChar>) {
    let localName = String(cString: localNamePtr)
    DispatchQueue.main.async {
        MeshxNativeBLEBridge.shared.startAdvertising(localName: localName)
    }
}

@_cdecl("meshx_ble_stop")
public func meshx_ble_stop() {
    DispatchQueue.main.async {
        MeshxNativeBLEBridge.shared.stop()
    }
}

@_cdecl("meshx_ble_send_ping")
public func meshx_ble_send_ping(
    _ peerIdPtr: UnsafePointer<CChar>,
    _ payloadPtr: UnsafePointer<UInt8>,
    _ payloadLength: Int32
) {
    let peerId = String(cString: peerIdPtr)
    let payload = Data(bytes: payloadPtr, count: Int(payloadLength))

    DispatchQueue.main.async {
        MeshxNativeBLEBridge.shared.sendPing(peerId: peerId, payload: payload)
    }
}

@_silgen_name("meshx_ble_emit_status")
func meshx_ble_emit_status(_ status: UnsafePointer<CChar>)

@_silgen_name("meshx_ble_emit_connected")
func meshx_ble_emit_connected(_ peerId: UnsafePointer<CChar>)

@_silgen_name("meshx_ble_emit_disconnected")
func meshx_ble_emit_disconnected(_ peerId: UnsafePointer<CChar>)

@_silgen_name("meshx_ble_emit_received")
func meshx_ble_emit_received(
    _ peerId: UnsafePointer<CChar>,
    _ packetType: Int32,
    _ msgId: UInt32,
    _ byteCount: UInt32
)

@_silgen_name("meshx_ble_emit_received_message_beacon")
func meshx_ble_emit_received_message_beacon(
    _ deviceId: UnsafePointer<CChar>,
    _ rssi: Int32,
    _ beaconVersion: Int32,
    _ envelopeVersion: Int32,
    _ payloadKind: UnsafePointer<CChar>,
    _ messageIdHash: UnsafePointer<UInt8>?,
    _ senderPeerIdHash: UnsafePointer<UInt8>?,
    _ advertisement: UnsafePointer<UInt8>?,
    _ advertisementLength: UInt32,
    _ beaconPayload: UnsafePointer<UInt8>?,
    _ beaconPayloadLength: UInt32,
    _ manufacturerData: UnsafePointer<UInt8>?,
    _ manufacturerDataLength: UInt32,
    _ companyIdentifier: UInt32
)

@_silgen_name("meshx_ble_emit_received_message")
func meshx_ble_emit_received_message(
    _ deviceId: UnsafePointer<CChar>,
    _ rssi: Int32,
    _ receivedAtMs: Int64,
    _ messageId: UnsafePointer<UInt8>?,
    _ messageIdLength: UInt32,
    _ senderPeerId: UnsafePointer<CChar>,
    _ recipientPeerId: UnsafePointer<CChar>?,
    _ envelope: UnsafePointer<UInt8>?,
    _ envelopeLength: UInt32,
    _ advertisement: UnsafePointer<UInt8>?,
    _ advertisementLength: UInt32,
    _ messagePayload: UnsafePointer<UInt8>?,
    _ messagePayloadLength: UInt32,
    _ manufacturerData: UnsafePointer<UInt8>?,
    _ manufacturerDataLength: UInt32,
    _ companyIdentifier: UInt32
)

@_silgen_name("meshx_ble_emit_error")
func meshx_ble_emit_error(_ message: UnsafePointer<CChar>)
