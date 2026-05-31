import Foundation
import Mob.Node

final class LineOutput {
    private let file: FileHandle?

    init(logFilePath: String?) {
        guard let logFilePath else {
            self.file = nil
            return
        }

        FileManager.default.createFile(atPath: logFilePath, contents: nil)
        self.file = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath))
    }

    func write(_ line: String) {
        print(line)
        fflush(stdout)

        guard let data = "\(line)\n".data(using: .utf8) else {
            return
        }
        try? file?.write(contentsOf: data)
    }
}

struct CLIOptions {
    let exitAfterFirst: Bool
    let timeoutSeconds: TimeInterval
    let logFilePath: String?
    let logDiscoveries: Bool

    init(arguments: [String], environment: [String: String]) {
        var exitAfterFirst = environment["MESHX_OBSERVER_EXIT_AFTER_FIRST"] == "1"
        var timeoutSeconds = TimeInterval(environment["MESHX_OBSERVER_TIMEOUT"] ?? "0") ?? 0
        var logFilePath = environment["MESHX_OBSERVER_LOG_FILE"]
        var logDiscoveries = environment["MESHX_OBSERVER_LOG_DISCOVERIES"] == "1"

        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--exit-after-first":
                exitAfterFirst = true

            case "--timeout":
                if index + 1 < arguments.count {
                    timeoutSeconds = TimeInterval(arguments[index + 1]) ?? timeoutSeconds
                    index += 1
                }

            case "--log-file":
                if index + 1 < arguments.count {
                    logFilePath = arguments[index + 1]
                    index += 1
                }

            case "--log-discoveries":
                logDiscoveries = true

            default:
                break
            }

            index += 1
        }

        self.exitAfterFirst = exitAfterFirst
        self.timeoutSeconds = timeoutSeconds
        self.logFilePath = logFilePath
        self.logDiscoveries = logDiscoveries
    }
}

final class ObserverCLI: NSObject, MessageAdvertisementObserverDelegate {
    private let observer = MessageAdvertisementObserver()
    private let exitAfterFirst: Bool
    private let output: LineOutput
    private let logDiscoveries: Bool
    private var seen = 0

    init(exitAfterFirst: Bool, logDiscoveries: Bool, output: LineOutput) {
        self.exitAfterFirst = exitAfterFirst
        self.logDiscoveries = logDiscoveries
        self.output = output
        super.init()
        observer.delegate = self
    }

    func start() {
        observer.startScan()
        output.write("MobMessageObserverCLI: scanning")
    }

    func didObserveReceivedMessage(_ event: ReceivedMessageEvent) {
        seen += 1
        output.write("MobMessageObserverCLI: \(event.jsonLine())")

        if exitAfterFirst {
            observer.stopScan()
            Foundation.exit(0)
        }
    }

    func didObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int) {
        let event = MessageAdvertisementDecodeErrorEvent(
            reason: reason,
            deviceId: deviceId,
            rssi: rssi
        )
        output.write("MobMessageObserverCLI: \(event.jsonLine())")
    }

    func messageObserverDidObserveLegacyBeacon(
        _ beacon: MobLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {
        seen += 1
        let mhash = beacon.messageIdHash.map { String(format: "%02x", $0) }.joined()
        let shash = beacon.senderPeerIdHash.map { String(format: "%02x", $0) }.joined()
        output.write("MobMessageObserverCLI: legacy_beacon_received device_id=\(deviceId) rssi=\(rssi) message_id_hash=\(mhash) sender_peer_id_hash=\(shash) payload_kind=\(beacon.payloadKind) beacon_version=\(beacon.beaconVersion) envelope_version=\(beacon.envelopeVersion)")

        if exitAfterFirst {
            observer.stopScan()
            Foundation.exit(0)
        }
    }

    func messageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    ) {
        guard logDiscoveries else {
            return
        }

        let localNameValue = localName ?? ""
        output.write("MobMessageObserverCLI: discovery device_id=\(deviceId) rssi=\(rssi) local_name=\(localNameValue) service_uuids=\(serviceUUIDs.joined(separator: ",")) manufacturer_data_len=\(manufacturerDataLength)")
    }

    func mobMessageObserverDidStartScan() {
        output.write("MobMessageObserverCLI: scan_started")
    }

    func mobMessageObserverDidUpdateState(_ state: String) {
        output.write("MobMessageObserverCLI: state \(state)")
    }

    func mobMessageObserverDidError(_ error: Error) {
        output.write("MobMessageObserverCLI: error \(String(describing: error))")
    }
}

let options = CLIOptions(
    arguments: ProcessInfo.processInfo.arguments,
    environment: ProcessInfo.processInfo.environment
)
let output = LineOutput(logFilePath: options.logFilePath)
let cli = ObserverCLI(
    exitAfterFirst: options.exitAfterFirst,
    logDiscoveries: options.logDiscoveries,
    output: output
)

if options.timeoutSeconds > 0 {
    Timer.scheduledTimer(withTimeInterval: options.timeoutSeconds, repeats: false) { _ in
        output.write("MobMessageObserverCLI: timeout")
        Foundation.exit(2)
    }
}

cli.start()
RunLoop.main.run()
