import Foundation
import CoreBluetooth
import Security
// MeshxLegacyBeaconAdvertisement, MeshxBLEClient, MeshxBLEPeripheral,
// Packet, Frame live in the local meshx_mobile Swift package. The
// Xcode project pulls them in via the package product import; this
// declaration is the explicit form when this file is added to the
// project target's Sources list.
import MeshxMobile

final class MeshxNativeBLEBridge: NSObject {
    static let shared = MeshxNativeBLEBridge()

    private var client: MeshxBLEClient?
    private var peripheral: MeshxBLEPeripheral?
    private var centralPeers = Set<String>()
    private var peripheralPeers = Set<String>()
    private var messageId: UInt32 = 1

    func startScan() {
        ensureClient().startScan()
        emitStatus("Scanning")
    }

    func startAdvertising(localName: String) {
        ensurePeripheral().startAdvertising(localName: localName)
        emitStatus("Advertising as \(localName)")
    }

    func stop() {
        client?.stopScan()
        peripheral?.stopAdvertising()
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

@_silgen_name("meshx_ble_emit_error")
func meshx_ble_emit_error(_ message: UnsafePointer<CChar>)
