import Foundation
import MeshxMobile

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

        guard arguments.contains("--meshx-auto-scan") else {
            return
        }

        mode = .scan
        startMessageObserverOnly()
    }

    func stop() {
        client.stopScan()
        messageObserver.stopScan()
        peripheral.stopAdvertising()
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
}

extension BLEHarnessModel: MeshxBLEPeripheralDelegate {
    func meshxPeripheralDidStartAdvertising() {
        updateStatus("Advertising")
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
        record("Error", detail: String(describing: error))
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
        let isCandidate = serviceUUIDs.contains { $0.caseInsensitiveCompare("8F4F1201-6F3D-4F9C-9E3B-7F4A4F0F1000") == .orderedSame }
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
}
