import Foundation
import MeshxMobile
import Security

struct HarnessEvent: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let title: String
    let detail: String
}

enum HarnessMode: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case advertise = "Advertise"

    var id: String { rawValue }
}

final class BLEHarnessModel: NSObject, ObservableObject {
    @Published var mode: HarnessMode = .scan
    @Published private(set) var status = "Waiting for Bluetooth"
    @Published private(set) var peerId: String?
    @Published private(set) var events: [HarnessEvent] = []

    private let client = MeshxBLEClient()
    private let peripheral = MeshxBLEPeripheral()
    private let messageObserver = MessageAdvertisementObserver()
    private var nextMsgId: UInt32 = 1
    private var didHandleLaunchArguments = false
    private var logMessageObserverDiscoveries = false
    private var logMessageObserverCandidateDiscoveries = false
    private var beaconDispatchTimer: Timer?
    private var beaconDispatchCount: UInt32 = 0
    private var fetchResponder: MeshxFetchGattResponder?

    override init() {
        super.init()
        client.delegate = self
        peripheral.delegate = self
        messageObserver.delegate = self
        record("Harness ready", detail: "CoreBluetooth client initialized.")
    }

    func start() {
        peerId = nil
        switch mode {
        case .scan:
            peripheral.stopAdvertising()
            client.startScan()
            messageObserver.startScan()
            print("MeshxMessageObserver: scan_requested")
            updateStatus("Scanning")
            record("Scan started", detail: MeshxBLEUUID.service.uuidString)

        case .advertise:
            client.stopScan()
            messageObserver.stopScan()
            peripheral.startAdvertising(localName: "meshx-ipad")
            updateStatus("Advertising")
            record("Advertising started", detail: MeshxBLEUUID.service.uuidString)
        }
    }

    func startFromLaunchArgumentsIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !didHandleLaunchArguments else {
            return
        }
        didHandleLaunchArguments = true

        logMessageObserverDiscoveries = arguments.contains("--meshx-log-discoveries")
        logMessageObserverCandidateDiscoveries = arguments.contains("--meshx-log-candidate-discoveries")
        messageObserver.debugLogRawAdvertisementData = arguments.contains("--meshx-log-raw-advert-data")
        if messageObserver.debugLogRawAdvertisementData {
            print("MeshxMessageObserver: raw_advert_logging_enabled")
        }

        let autoScan = arguments.contains("--meshx-auto-scan")
        let autoBeacon = arguments.contains("--meshx-auto-beacon")
        let autoBeaconBasic = arguments.contains("--meshx-auto-beacon-basic")
        let autoServiceAdvertise = arguments.contains("--meshx-auto-service-advertise")
        let autoDirectMxServiceAdvertise = arguments.contains("--meshx-auto-direct-mx-service-advertise")
        let autoDirectMxHybridAdvertise = arguments.contains("--meshx-auto-direct-mx-hybrid-advertise")

        guard autoScan || autoBeacon || autoBeaconBasic || autoServiceAdvertise || autoDirectMxServiceAdvertise || autoDirectMxHybridAdvertise else {
            return
        }

        mode = .scan
        if autoScan {
            startMessageObserverOnly()
        }
        if autoServiceAdvertise {
            startServiceAdvertiseOnly()
        }
        if autoDirectMxServiceAdvertise {
            startDirectMxServiceAdvertiseOnly()
        }
        if autoDirectMxHybridAdvertise {
            startDirectMxHybridAdvertiseOnly()
        }
        if autoBeaconBasic {
            startBasicAutoBeaconDispatch()
        } else if autoBeacon {
            startAutoBeaconDispatch()
        }
    }

    private func startAutoBeaconDispatch() {
        let senderPeerId = "ios-harness-\(UUID().uuidString.prefix(8))"
        print("MeshxMessageObserver: beacon_dispatch_started sender_peer_id=\(senderPeerId)")
        beaconDispatchTimer?.invalidate()
        beaconDispatchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            var messageId = Data(count: 16)
            _ = messageId.withUnsafeMutableBytes { buf in
                SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
            }
            let payload = Data("ios-full-envelope-smoke-\(self.beaconDispatchCount + 1)".utf8)
            let envelope: Data
            do {
                envelope = try MessageEnvelope.buildV1(
                    messageId: messageId,
                    senderPeerId: senderPeerId,
                    createdAt: UInt64(Date().timeIntervalSince1970 * 1000),
                    payload: payload
                )
            } catch {
                print("MeshxMessageObserver: fetch_responder_envelope_failed error=\(String(describing: error))")
                return
            }
            let beacon = MeshxLegacyBeaconAdvertisement.build(messageId: messageId, senderPeerId: senderPeerId)
            let messageHashHex = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
            let responderPeerId = "mx\(messageHashHex)"
            do {
                self.fetchResponder?.stop()
                let responder = try MeshxFetchGattResponder(envelope: envelope, responderPeerId: responderPeerId)
                responder.delegate = self
                self.fetchResponder = responder
                responder.start()
                self.peripheral.startBeaconAdvertising(beacon)
            } catch {
                print("MeshxMessageObserver: fetch_responder_start_failed error=\(String(describing: error))")
                return
            }
            self.beaconDispatchCount &+= 1
            let hex = messageId.map { String(format: "%02x", $0) }.joined()
            let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
            print("MeshxMessageObserver: beacon_dispatched seq=\(self.beaconDispatchCount) message_id=\(hex) message_id_hash=\(messageHashHex) sender_peer_id=\(senderPeerId) sender_peer_id_hash=\(shash)")
        }
    }

    private func startBasicAutoBeaconDispatch() {
        let senderPeerId = "ios-harness-\(UUID().uuidString.prefix(8))"
        print("MeshxMessageObserver: basic_beacon_dispatch_started sender_peer_id=\(senderPeerId)")
        beaconDispatchTimer?.invalidate()
        beaconDispatchTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            var messageId = Data(count: 16)
            _ = messageId.withUnsafeMutableBytes { buf in
                SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
            }
            let beacon = self.peripheral.advertiseLegacyBeacon(
                messageId: messageId,
                senderPeerId: senderPeerId,
                payloadKind: "TX"
            )
            self.beaconDispatchCount &+= 1
            let hex = messageId.map { String(format: "%02x", $0) }.joined()
            let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
            let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
            print("MeshxMessageObserver: beacon_dispatched seq=\(self.beaconDispatchCount) message_id=\(hex) message_id_hash=\(mhash) sender_peer_id=\(senderPeerId) sender_peer_id_hash=\(shash)")
        }
    }

    func stop() {
        client.stopScan()
        messageObserver.stopScan()
        peripheral.stopAdvertising()
        fetchResponder?.stop()
        fetchResponder = nil
        updateStatus("Stopped")
        record("Stopped", detail: "BLE activity paused.")
    }

    func startMessageObserverOnly() {
        peerId = nil
        client.stopScan()
        peripheral.stopAdvertising()
        messageObserver.startScan()
        print("MeshxMessageObserver: scan_requested")
        updateStatus("Message observer")
        record("Message observer started", detail: "Manufacturer data scan")
    }

    private func startServiceAdvertiseOnly() {
        print("MeshxMessageObserver: service_advertise_requested service_uuid=\(MeshxBLEUUID.service.uuidString) local_name=meshx-ipad")
        client.stopScan()
        messageObserver.stopScan()
        peripheral.startAdvertising(localName: "meshx-ipad")
        updateStatus("Service advertising")
        record("Service advertising", detail: MeshxBLEUUID.service.uuidString)
    }

    private func startDirectMxServiceAdvertiseOnly() {
        // "Different advertising strategy" experiment: iOS as emitter for the direct full-MX path.
        // Advertises on the dedicated direct-MX service UUID (`MeshxBLEUUID.directMxService`)
        // carrying a real `MessageEnvelope` v1 in service data.
        //
        // This is the iOS-side counterpart to the Android `emitsServiceDataFullMxEnvelope()` /
        // hybrid tests. When run together with the Android raw/service-data observer, it lets
        // us test the new carrier in the iOS → Android direction with fully parseable envelopes.
        print("MeshxMessageObserver: direct_mx_service_advertise_requested service_uuid=\(MeshxBLEUUID.directMxService.uuidString) local_name=meshx-ipad-direct")
        client.stopScan()
        messageObserver.stopScan()

        // Build a real small envelope (same pattern used elsewhere in the harness for fetch responders).
        var messageId = Data(count: 16)
        _ = messageId.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
        }
        let payload = Data("ios-direct-mx-service-data-\(self.beaconDispatchCount + 1)".utf8)

        let envelope: Data
        do {
            envelope = try MessageEnvelope.buildV1(
                messageId: messageId,
                senderPeerId: "ios-direct-mx",
                createdAt: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: payload
            )
        } catch {
            print("MeshxMessageObserver: direct_mx_envelope_build_failed error=\(String(describing: error))")
            return
        }

        let messageIdHex = messageId.map { String(format: "%02x", $0) }.joined()
        print("MeshxMessageObserver: direct_mx_envelope_built messageId=\(messageIdHex) size=\(envelope.count)")

        peripheral.startDirectMxServiceDataAdvertising(localName: "meshx-ipad-direct", payload: envelope)
        updateStatus("Direct MX service-data advertising (experimental)")
        record("Direct MX service advertising", detail: MeshxBLEUUID.directMxService.uuidString)
    }

    private func startDirectMxHybridAdvertiseOnly() {
        // Full "different advertising strategy" from iOS: send the short MB legacy beacon (fleet-safe cue)
        // + the full MX envelope via the dedicated direct-MX service data UUID.
        //
        // This is the iOS-side equivalent of the Android `emitsHybridMbCuePlusServiceDataFullMxEnvelope()`.
        // Run this on iOS + the Android raw/service-data observer (or the hybrid test) to validate
        // the complete hybrid carrier in the iOS → Android direction.
        print("MeshxMessageObserver: direct_mx_hybrid_advertise_requested")
        client.stopScan()
        messageObserver.stopScan()

        // Build a real envelope (same as the pure direct-mx mode).
        var messageId = Data(count: 16)
        _ = messageId.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
        }
        let payload = Data("ios-direct-mx-hybrid-\(self.beaconDispatchCount + 1)".utf8)

        let envelope: Data
        do {
            envelope = try MessageEnvelope.buildV1(
                messageId: messageId,
                senderPeerId: "ios-direct-hybrid",
                createdAt: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: payload
            )
        } catch {
            print("MeshxMessageObserver: direct_mx_hybrid_envelope_build_failed error=\(String(describing: error))")
            return
        }

        let messageIdHex = messageId.map { String(format: "%02x", $0) }.joined()
        print("MeshxMessageObserver: direct_mx_hybrid_envelope_built messageId=\(messageIdHex)")

        // 1. Send the short MB legacy beacon cue (fleet-safe, everyone can receive this).
        // Use the peripheral's legacy beacon advertising support for a short window.
        let beacon = MeshxLegacyBeaconAdvertisement.build(messageId: messageId, senderPeerId: "ios-direct-hybrid")
        print("MeshxMessageObserver: direct_mx_hybrid_sending_mb_cue")
        peripheral.startLegacyBeaconAdvertising(beacon: beacon, duration: 4.0) // short cue window

        // Small delay so the cue is on air first
        Thread.sleep(forTimeInterval: 1.0)

        // 2. Advertise the full envelope via the direct service-data carrier.
        peripheral.startDirectMxServiceDataAdvertising(localName: "meshx-ipad-hybrid", payload: envelope)

        // Clear one-line summary for easy correlation on both sides (grep for this on iOS console).
        print("MeshxMessageObserver: iOS_HYBRID_STARTED messageId=\(messageIdHex) MB_cue_sent=true direct_mx_service_data_started=true uuid=\(MeshxBLEUUID.directMxService.uuidString)")

        updateStatus("Direct MX hybrid advertising (MB cue + service-data)")
        record("Direct MX hybrid advertising", detail: MeshxBLEUUID.directMxService.uuidString)

        // Fixed window for the experiment (matches Android test behavior of ~5-8s send window).
        // This makes the iOS hybrid transmit a clean, time-bounded experiment just like the Android smoke tests.
        let hybridWindow: TimeInterval = 8.0
        print("MeshxMessageObserver: iOS hybrid experiment will run for \(hybridWindow)s then stop automatically")
        Thread.sleep(forTimeInterval: hybridWindow)

        peripheral.stopAdvertising()
        print("MeshxMessageObserver: iOS_HYBRID_WINDOW_COMPLETE messageId=\(messageIdHex) — hybrid transmit window finished. Check Android logs for HYBRID_SUCCESS with the same messageId.")
    }

    func sendPing() {
        guard let peerId else {
            record("Send skipped", detail: "No secure peer is connected.")
            return
        }

        do {
            let packet = Packet(
                type: .data,
                flags: [.ackRequested],
                msgId: nextMessageId(),
                payload: Data("ios-harness-ping".utf8)
            )

            switch mode {
            case .scan:
                try client.send(packet: packet, to: peerId)
            case .advertise:
                try peripheral.send(packet: packet, to: peerId)
            }
            record("Ping sent", detail: peerId)
        } catch {
            record("Send failed", detail: String(describing: error))
        }
    }

    private func nextMessageId() -> UInt32 {
        defer { nextMsgId &+= 1 }
        return nextMsgId
    }

    private func updateStatus(_ value: String) {
        onMain {
            self.status = value
        }
    }

    private func record(_ title: String, detail: String) {
        onMain {
            self.events.insert(HarnessEvent(timestamp: Date(), title: title, detail: detail), at: 0)
            if self.events.count > 50 {
                self.events.removeLast()
            }
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

extension BLEHarnessModel: MeshxBLEClientDelegate {
    func meshxDidConnect(peerId: String) {
        onMain {
            self.peerId = peerId
            self.status = "Secure peer connected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Connected", detail: peerId), at: 0)
        }
    }

    func meshxDidDisconnect(peerId: String) {
        onMain {
            if self.peerId == peerId {
                self.peerId = nil
            }
            self.status = "Disconnected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Disconnected", detail: peerId), at: 0)
        }
    }

    func meshxDidReceive(frame: Data, from peerId: String) {
        let detail: String
        if let decoded = try? Frame.decode(frame), decoded.1.isEmpty {
            detail = "\(decoded.0.type) #\(decoded.0.msgId), \(decoded.0.payload.count) bytes"
        } else {
            detail = "\(frame.count) raw bytes"
        }
        record("Frame received", detail: "\(peerId): \(detail)")
    }

    func meshxDidError(_ error: Error) {
        record("Error", detail: String(describing: error))
    }

    func meshxDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
        let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
        print("MeshxMessageObserver: legacy_beacon_received device_id=\(deviceId) rssi=\(rssi) message_id_hash=\(mhash) sender_peer_id_hash=\(shash) payload_kind=\(beacon.payloadKind) beacon_version=\(beacon.beaconVersion) envelope_version=\(beacon.envelopeVersion)")
        record("Legacy beacon", detail: "\(deviceId) rssi=\(rssi) mhash=\(mhash.prefix(16))")
    }
}

extension BLEHarnessModel: MeshxBLEPeripheralDelegate {
    func meshxPeripheralDidStartAdvertising() {
        updateStatus("Advertising")
        print("MeshxMessageObserver: peripheral_advertising_started")
        record("Advertising", detail: MeshxBLEUUID.service.uuidString)
    }

    func meshxPeripheralDidStopAdvertising() {
        record("Advertising stopped", detail: MeshxBLEUUID.service.uuidString)
    }

    func meshxPeripheralDidConnect(peerId: String) {
        onMain {
            self.peerId = peerId
            self.status = "Secure peer connected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Connected", detail: peerId), at: 0)
        }
    }

    func meshxPeripheralDidDisconnect(peerId: String) {
        onMain {
            if self.peerId == peerId {
                self.peerId = nil
            }
            self.status = "Disconnected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Disconnected", detail: peerId), at: 0)
        }
    }

    func meshxPeripheralDidReceive(frame: Data, from peerId: String) {
        let detail: String
        if let decoded = try? Frame.decode(frame), decoded.1.isEmpty {
            detail = "\(decoded.0.type) #\(decoded.0.msgId), \(decoded.0.payload.count) bytes"
        } else {
            detail = "\(frame.count) raw bytes"
        }
        record("Frame received", detail: "\(peerId): \(detail)")
    }

    func meshxPeripheralDidError(_ error: Error) {
        print("MeshxMessageObserver: peripheral_error \(String(describing: error))")
        record("Error", detail: String(describing: error))
    }
}

extension BLEHarnessModel: MeshxFetchGattResponderDelegate {
    func meshxFetchResponderDidStart() {
        print("MeshxMessageObserver: fetch_responder_advertising_started")
        record("Fetch responder", detail: MeshxFetchGattUUID.service.uuidString)
    }

    func meshxFetchResponderDidFail(reason: String) {
        print("MeshxMessageObserver: fetch_responder_failed reason=\(reason)")
        record("Fetch responder failed", detail: reason)
    }

    func meshxFetchResponderDidServeRequest(
        request: MeshxFetchProtocol.Request,
        status: UInt8
    ) {
        let requestHash = request.messageIdHash.map { String(format: "%02x", $0) }.joined()
        print("MeshxMessageObserver: fetch_responder_served request_id=\(request.requestId) message_id_hash=\(requestHash) status=\(status)")
        record("Fetch served", detail: "\(request.requestId) status=\(status)")
    }
}

extension BLEHarnessModel: MessageAdvertisementObserverDelegate {
    func meshxDidObserveReceivedMessage(_ event: ReceivedMessageEvent) {
        let detail = "\(event.senderPeerId) -> \(event.recipientPeerId ?? "broadcast"), \(event.envelope.payload.count) bytes"
        print("MeshxMessageObserver: \(event.jsonLine())")
        record("Message advertisement", detail: detail)
    }

    func meshxDidObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int) {
        let event = MessageAdvertisementDecodeErrorEvent(reason: reason, deviceId: deviceId, rssi: rssi)
        print("MeshxMessageObserver: \(event.jsonLine())")
        record("Message advert error", detail: "\(deviceId): \(reason)")
    }

    func meshxMessageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    ) {
        let isCandidate = serviceUUIDs.contains { $0.caseInsensitiveCompare(MeshxBLEUUID.service.uuidString) == .orderedSame }
            || serviceUUIDs.contains { $0.caseInsensitiveCompare(MeshxBLEUUID.directMxService.uuidString) == .orderedSame }
            || manufacturerDataLength >= 60
            || (localName?.localizedCaseInsensitiveContains("meshx") ?? false)

        guard logMessageObserverDiscoveries || (logMessageObserverCandidateDiscoveries && isCandidate) else {
            return
        }

        let localNameValue = localName ?? "nil"
        let prefix = isCandidate ? "candidate_discovery" : "discovery"
        print("MeshxMessageObserver: \(prefix) device_id=\(deviceId) rssi=\(rssi) local_name=\(localNameValue) service_uuids=\(serviceUUIDs.joined(separator: ",")) manufacturer_data_len=\(manufacturerDataLength)")
    }

    func meshxMessageObserverDidStartScan() {
        print("MeshxMessageObserver: scan_started")
    }

    func meshxMessageObserverDidUpdateState(_ state: String) {
        print("MeshxMessageObserver: state \(state)")
    }

    func meshxMessageObserverDidError(_ error: Error) {
        print("MeshxMessageObserver: error \(String(describing: error))")
        record("Message observer error", detail: String(describing: error))
    }

    func meshxMessageObserverDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
        let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
        print("MeshxMessageObserver: legacy_beacon_received device_id=\(deviceId) rssi=\(rssi) message_id_hash=\(mhash) sender_peer_id_hash=\(shash) payload_kind=\(beacon.payloadKind) beacon_version=\(beacon.beaconVersion) envelope_version=\(beacon.envelopeVersion)")
        record("Legacy beacon RX", detail: "\(deviceId) rssi=\(rssi) mhash=\(mhash.prefix(16))")
    }
}
