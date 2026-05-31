import Foundation
import Mob.Node
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

    private let client = BLEClient()
    private let peripheral = BLEPeripheral()
    private let messageObserver = MessageAdvertisementObserver()
    private var nextMsgId: UInt32 = 1
    private var didHandleLaunchArguments = false
    private var logMessageObserverDiscoveries = false
    private var logMessageObserverCandidateDiscoveries = false
    private var beaconDispatchTimer: Timer?
    private var beaconDispatchCount: UInt32 = 0
    private var fetchResponder: FetchGattResponder?

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
            print("MessageObserver: scan_requested")
            updateStatus("Scanning")
            record("Scan started", detail: BLEUUID.service.uuidString)

        case .advertise:
            client.stopScan()
            messageObserver.stopScan()
            peripheral.startAdvertising(localName: "ipad")
            updateStatus("Advertising")
            record("Advertising started", detail: BLEUUID.service.uuidString)
        }
    }

    func startFromLaunchArgumentsIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !didHandleLaunchArguments else {
            return
        }
        didHandleLaunchArguments = true

        logMessageObserverDiscoveries = arguments.contains("--mob-log-discoveries")
        logMessageObserverCandidateDiscoveries = arguments.contains("--mob-log-candidate-discoveries")
        messageObserver.debugLogRawAdvertisementData = arguments.contains("--mob-log-raw-advert-data")
        if messageObserver.debugLogRawAdvertisementData {
            print("MessageObserver: raw_advert_logging_enabled")
        }

        let autoScan = arguments.contains("--mob-auto-scan")
        let autoBeacon = arguments.contains("--mob-auto-beacon")
        let autoBeaconBasic = arguments.contains("--mob-auto-beacon-basic")
        let autoServiceAdvertise = arguments.contains("--mob-auto-service-advertise")
        let autoDirectMxServiceAdvertise = arguments.contains("--mob-auto-direct-mx-service-advertise")
        let autoDirectMxHybridAdvertise = arguments.contains("--mob-auto-direct-mx-hybrid-advertise")

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
        print("MessageObserver: beacon_dispatch_started sender_peer_id=\(senderPeerId)")
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
                print("MessageObserver: fetch_responder_envelope_failed error=\(String(describing: error))")
                return
            }
            let beacon = LegacyBeaconAdvertisement.build(messageId: messageId, senderPeerId: senderPeerId)
            let messageHashHex = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
            let responderPeerId = "mx\(messageHashHex)"
            do {
                self.fetchResponder?.stop()
                let responder = try FetchGattResponder(envelope: envelope, responderPeerId: responderPeerId)
                responder.delegate = self
                self.fetchResponder = responder
                responder.start()
                self.peripheral.startBeaconAdvertising(beacon)
            } catch {
                print("MessageObserver: fetch_responder_start_failed error=\(String(describing: error))")
                return
            }
            self.beaconDispatchCount &+= 1
            let hex = messageId.map { String(format: "%02x", $0) }.joined()
            let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
            print("MessageObserver: beacon_dispatched seq=\(self.beaconDispatchCount) message_id=\(hex) message_id_hash=\(messageHashHex) sender_peer_id=\(senderPeerId) sender_peer_id_hash=\(shash)")
        }
    }

    private func startBasicAutoBeaconDispatch() {
        let senderPeerId = "ios-harness-\(UUID().uuidString.prefix(8))"
        print("MessageObserver: basic_beacon_dispatch_started sender_peer_id=\(senderPeerId)")
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
            print("MessageObserver: beacon_dispatched seq=\(self.beaconDispatchCount) message_id=\(hex) message_id_hash=\(mhash) sender_peer_id=\(senderPeerId) sender_peer_id_hash=\(shash)")
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
        print("MessageObserver: scan_requested")
        updateStatus("Message observer")
        record("Message observer started", detail: "Manufacturer data scan")
    }

    private func startServiceAdvertiseOnly() {
        print("MessageObserver: service_advertise_requested service_uuid=\(BLEUUID.service.uuidString) local_name=ipad")
        client.stopScan()
        messageObserver.stopScan()
        peripheral.startAdvertising(localName: "ipad")
        updateStatus("Service advertising")
        record("Service advertising", detail: BLEUUID.service.uuidString)
    }

    private func startDirectMxServiceAdvertiseOnly() {
        // "Different advertising strategy" experiment: iOS as emitter for the direct full-MX path.
        // Advertises on the dedicated direct-MX service UUID (`BLEUUID.directMxService`)
        // carrying a real `MessageEnvelope` v1 in service data.
        //
        // This is the iOS-side counterpart to the Android `emitsServiceDataFullMxEnvelope()` /
        // hybrid tests. When run together with the Android raw/service-data observer, it lets
        // us test the new carrier in the iOS → Android direction with fully parseable envelopes.
        print("MessageObserver: direct_mx_service_advertise_requested service_uuid=\(BLEUUID.directMxService.uuidString) local_name=ipad-direct")
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
            print("MessageObserver: direct_mx_envelope_build_failed error=\(String(describing: error))")
            return
        }

        let messageIdHex = messageId.map { String(format: "%02x", $0) }.joined()
        print("MessageObserver: direct_mx_envelope_built messageId=\(messageIdHex) size=\(envelope.count)")

        peripheral.startDirectMxServiceDataAdvertising(localName: "ipad-direct", payload: envelope)
        updateStatus("Direct MX service-data advertising (experimental)")
        record("Direct MX service advertising", detail: BLEUUID.directMxService.uuidString)
    }

    private func startDirectMxHybridAdvertiseOnly() {
        // Full "different advertising strategy" from iOS: send the short MB legacy beacon (fleet-safe cue)
        // + the full MX envelope via the dedicated direct-MX service data UUID.
        //
        // This is the iOS-side equivalent of the Android `emitsHybridMbCuePlusServiceDataFullMxEnvelope()`.
        // Run this on iOS + the Android raw/service-data observer (or the hybrid test) to validate
        // the complete hybrid carrier in the iOS → Android direction.
        print("MessageObserver: direct_mx_hybrid_advertise_requested")
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
            print("MessageObserver: direct_mx_hybrid_envelope_build_failed error=\(String(describing: error))")
            return
        }

        let messageIdHex = messageId.map { String(format: "%02x", $0) }.joined()
        print("MessageObserver: direct_mx_hybrid_envelope_built messageId=\(messageIdHex)")

        // 1. Send the short MB legacy beacon cue (fleet-safe, everyone can receive this).
        // Use the peripheral's legacy beacon advertising support for a short window.
        let beacon = LegacyBeaconAdvertisement.build(messageId: messageId, senderPeerId: "ios-direct-hybrid")
        print("MessageObserver: direct_mx_hybrid_sending_mb_cue")
        peripheral.startLegacyBeaconAdvertising(beacon: beacon, duration: 4.0) // short cue window

        // Small delay so the cue is on air first
        Thread.sleep(forTimeInterval: 1.0)

        // 2. Advertise the full envelope via the direct service-data carrier.
        peripheral.startDirectMxServiceDataAdvertising(localName: "ipad-hybrid", payload: envelope)

        // Clear one-line summary for easy correlation on both sides (grep for this on iOS console).
        print("MessageObserver: iOS_HYBRID_STARTED messageId=\(messageIdHex) MB_cue_sent=true direct_mx_service_data_started=true uuid=\(BLEUUID.directMxService.uuidString)")

        updateStatus("Direct MX hybrid advertising (MB cue + service-data)")
        record("Direct MX hybrid advertising", detail: BLEUUID.directMxService.uuidString)

        // Fixed window for the experiment (matches Android test behavior of ~5-8s send window).
        // This makes the iOS hybrid transmit a clean, time-bounded experiment just like the Android smoke tests.
        let hybridWindow: TimeInterval = 8.0
        print("MessageObserver: iOS hybrid experiment will run for \(hybridWindow)s then stop automatically")
        Thread.sleep(forTimeInterval: hybridWindow)

        peripheral.stopAdvertising()
        print("MessageObserver: iOS_HYBRID_WINDOW_COMPLETE messageId=\(messageIdHex) — hybrid transmit window finished. Check Android logs for HYBRID_SUCCESS with the same messageId.")
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

extension BLEHarnessModel: BLEClientDelegate {
    func didConnect(peerId: String) {
        onMain {
            self.peerId = peerId
            self.status = "Secure peer connected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Connected", detail: peerId), at: 0)
        }
    }

    func didDisconnect(peerId: String) {
        onMain {
            if self.peerId == peerId {
                self.peerId = nil
            }
            self.status = "Disconnected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Disconnected", detail: peerId), at: 0)
        }
    }

    func didReceive(frame: Data, from peerId: String) {
        let detail: String
        if let decoded = try? Frame.decode(frame), decoded.1.isEmpty {
            detail = "\(decoded.0.type) #\(decoded.0.msgId), \(decoded.0.payload.count) bytes"
        } else {
            detail = "\(frame.count) raw bytes"
        }
        record("Frame received", detail: "\(peerId): \(detail)")
    }

    func didError(_ error: Error) {
        record("Error", detail: String(describing: error))
    }

    func didObserveLegacyBeacon(
        _ beacon: LegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
        let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
        print("MessageObserver: legacy_beacon_received device_id=\(deviceId) rssi=\(rssi) message_id_hash=\(mhash) sender_peer_id_hash=\(shash) payload_kind=\(beacon.payloadKind) beacon_version=\(beacon.beaconVersion) envelope_version=\(beacon.envelopeVersion)")
        record("Legacy beacon", detail: "\(deviceId) rssi=\(rssi) mhash=\(mhash.prefix(16))")
    }
}

extension BLEHarnessModel: BLEPeripheralDelegate {
    func peripheralDidStartAdvertising() {
        updateStatus("Advertising")
        print("MessageObserver: peripheral_advertising_started")
        record("Advertising", detail: BLEUUID.service.uuidString)
    }

    func peripheralDidStopAdvertising() {
        record("Advertising stopped", detail: BLEUUID.service.uuidString)
    }

    func peripheralDidConnect(peerId: String) {
        onMain {
            self.peerId = peerId
            self.status = "Secure peer connected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Connected", detail: peerId), at: 0)
        }
    }

    func peripheralDidDisconnect(peerId: String) {
        onMain {
            if self.peerId == peerId {
                self.peerId = nil
            }
            self.status = "Disconnected"
            self.events.insert(HarnessEvent(timestamp: Date(), title: "Disconnected", detail: peerId), at: 0)
        }
    }

    func peripheralDidReceive(frame: Data, from peerId: String) {
        let detail: String
        if let decoded = try? Frame.decode(frame), decoded.1.isEmpty {
            detail = "\(decoded.0.type) #\(decoded.0.msgId), \(decoded.0.payload.count) bytes"
        } else {
            detail = "\(frame.count) raw bytes"
        }
        record("Frame received", detail: "\(peerId): \(detail)")
    }

    func peripheralDidError(_ error: Error) {
        print("MessageObserver: peripheral_error \(String(describing: error))")
        record("Error", detail: String(describing: error))
    }
}

extension BLEHarnessModel: FetchGattResponderDelegate {
    func fetchResponderDidStart() {
        print("MessageObserver: fetch_responder_advertising_started")
        record("Fetch responder", detail: FetchGattUUID.service.uuidString)
    }

    func fetchResponderDidFail(reason: String) {
        print("MessageObserver: fetch_responder_failed reason=\(reason)")
        record("Fetch responder failed", detail: reason)
    }

    func fetchResponderDidServeRequest(
        request: MobFetchProtocol.Request,
        status: UInt8
    ) {
        let requestHash = request.messageIdHash.map { String(format: "%02x", $0) }.joined()
        print("MessageObserver: fetch_responder_served request_id=\(request.requestId) message_id_hash=\(requestHash) status=\(status)")
        record("Fetch served", detail: "\(request.requestId) status=\(status)")
    }
}

extension BLEHarnessModel: MessageAdvertisementObserverDelegate {
    func didObserveReceivedMessage(_ event: ReceivedMessageEvent) {
        let detail = "\(event.senderPeerId) -> \(event.recipientPeerId ?? "broadcast"), \(event.envelope.payload.count) bytes"
        print("MessageObserver: \(event.jsonLine())")
        record("Message advertisement", detail: detail)
    }

    func didObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int) {
        let event = MessageAdvertisementDecodeErrorEvent(reason: reason, deviceId: deviceId, rssi: rssi)
        print("MessageObserver: \(event.jsonLine())")
        record("Message advert error", detail: "\(deviceId): \(reason)")
    }

    func messageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    ) {
        let isCandidate = serviceUUIDs.contains { $0.caseInsensitiveCompare(BLEUUID.service.uuidString) == .orderedSame }
            || serviceUUIDs.contains { $0.caseInsensitiveCompare(BLEUUID.directMxService.uuidString) == .orderedSame }
            || manufacturerDataLength >= 60
            || (localName?.localizedCaseInsensitiveContains("mob") ?? false)

        guard logMessageObserverDiscoveries || (logMessageObserverCandidateDiscoveries && isCandidate) else {
            return
        }

        let localNameValue = localName ?? "nil"
        let prefix = isCandidate ? "candidate_discovery" : "discovery"
        print("MessageObserver: \(prefix) device_id=\(deviceId) rssi=\(rssi) local_name=\(localNameValue) service_uuids=\(serviceUUIDs.joined(separator: ",")) manufacturer_data_len=\(manufacturerDataLength)")
    }

    func messageObserverDidStartScan() {
        print("MessageObserver: scan_started")
    }

    func messageObserverDidUpdateState(_ state: String) {
        print("MessageObserver: state \(state)")
    }

    func mobMessageObserverDidError(_ error: Error) {
        print("MessageObserver: error \(String(describing: error))")
        record("Message observer error", detail: String(describing: error))
    }

    func mobMessageObserverDidObserveLegacyBeacon(
        _ beacon: LegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
        let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
        print("MessageObserver: legacy_beacon_received device_id=\(deviceId) rssi=\(rssi) message_id_hash=\(mhash) sender_peer_id_hash=\(shash) payload_kind=\(beacon.payloadKind) beacon_version=\(beacon.beaconVersion) envelope_version=\(beacon.envelopeVersion)")
        record("Legacy beacon RX", detail: "\(deviceId) rssi=\(rssi) mhash=\(mhash.prefix(16))")
    }
}
