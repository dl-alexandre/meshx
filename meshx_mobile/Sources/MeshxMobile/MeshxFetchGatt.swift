#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth

/// Swift mirror of Android's `MeshxFetchGatt` *client* (requester) path.
/// iOS's role for MX full-envelope delivery is to receive an MB legacy
/// beacon (already working via `MessageAdvertisementObserver`), then open
/// a GATT connection to the same peer and pull the full envelope using
/// the MFQ/MFR protocol. The responder lives on the Android side.
///
/// Service / characteristic UUIDs match `MeshxFetchGatt.kt:741-743`.
public enum MeshxFetchGattUUID {
    public static let service = CBUUID(string: "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f2000")
    public static let request = CBUUID(string: "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f2001")
    public static let response = CBUUID(string: "8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f2002")
}

public protocol MeshxFetchGattClientDelegate: AnyObject {
    /// Called on the main queue when the fetch completes successfully.
    func meshxFetchDidComplete(envelope: Data, peripheral: CBPeripheral, request: MeshxFetchProtocol.Request)
    /// Called on the main queue when the fetch fails. `reason` is one of
    /// the same phase strings the Android implementation logs.
    func meshxFetchDidFail(reason: String, detail: String?, request: MeshxFetchProtocol.Request)
}

/// One-shot GATT client. Create one per fetch attempt; the instance owns
/// the connection and tears it down after success or failure.
///
/// Mirrors the Android `clientCallback` state machine in `MeshxFetchGatt.kt`:
/// connect → MTU request → service discovery → write request →
/// read response → decode → deliver to delegate.
public final class MeshxFetchGattClient: NSObject {
    public weak var delegate: MeshxFetchGattClientDelegate?
    public let request: MeshxFetchProtocol.Request
    private let central: CBCentralManager
    private let peripheral: CBPeripheral
    private let phaseTimeout: TimeInterval
    private var requestCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?
    private var phase: Phase = .idle
    private var timeoutWork: DispatchWorkItem?
    private var finished = false

    private enum Phase: String {
        case idle
        case connect
        case discoverServices
        case discoverCharacteristics
        case writeRequest
        case readResponse
        case done
    }

    public init(
        central: CBCentralManager,
        peripheral: CBPeripheral,
        request: MeshxFetchProtocol.Request,
        phaseTimeout: TimeInterval = 5.0
    ) {
        self.central = central
        self.peripheral = peripheral
        self.request = request
        self.phaseTimeout = phaseTimeout
        super.init()
        peripheral.delegate = self
    }

    public func start() {
        phase = .connect
        scheduleTimeout(.connect)
        central.connect(peripheral, options: nil)
    }

    /// Public so the owning observer can route `centralManager(_:didConnect:)`
    /// and the disconnect callback here without inheriting from CBCentralManagerDelegate.
    public func handleConnected() {
        clearTimeout()
        phase = .discoverServices
        scheduleTimeout(.discoverServices)
        peripheral.discoverServices([MeshxFetchGattUUID.service])
    }

    public func handleDisconnected(error: Error?) {
        guard !finished else { return }
        finish(reason: "disconnected", detail: error.map { String(describing: $0) } ?? "remote_disconnected")
    }

    public func handleFailedToConnect(error: Error?) {
        finish(reason: "connect_failed", detail: error.map { String(describing: $0) })
    }

    private func scheduleTimeout(_ p: Phase) {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.finished, self.phase == p else { return }
            self.finish(reason: "\(p.rawValue)_timeout", detail: nil)
        }
        timeoutWork?.cancel()
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + phaseTimeout, execute: work)
    }

    private func clearTimeout() {
        timeoutWork?.cancel()
        timeoutWork = nil
    }

    private func finish(envelope: Data) {
        guard !finished else { return }
        finished = true
        clearTimeout()
        phase = .done
        central.cancelPeripheralConnection(peripheral)
        delegate?.meshxFetchDidComplete(envelope: envelope, peripheral: peripheral, request: request)
    }

    private func finish(reason: String, detail: String?) {
        guard !finished else { return }
        finished = true
        clearTimeout()
        phase = .done
        if peripheral.state != .disconnected {
            central.cancelPeripheralConnection(peripheral)
        }
        delegate?.meshxFetchDidFail(reason: reason, detail: detail, request: request)
    }
}

extension MeshxFetchGattClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        clearTimeout()
        if let error = error {
            finish(reason: "service_discovery_failed", detail: String(describing: error))
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == MeshxFetchGattUUID.service }) else {
            finish(reason: "service_discovery_failed", detail: "service_not_found")
            return
        }
        phase = .discoverCharacteristics
        scheduleTimeout(.discoverCharacteristics)
        peripheral.discoverCharacteristics(
            [MeshxFetchGattUUID.request, MeshxFetchGattUUID.response],
            for: service
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        clearTimeout()
        if let error = error {
            finish(reason: "characteristic_discovery_failed", detail: String(describing: error))
            return
        }
        requestCharacteristic = service.characteristics?.first { $0.uuid == MeshxFetchGattUUID.request }
        responseCharacteristic = service.characteristics?.first { $0.uuid == MeshxFetchGattUUID.response }

        guard let reqChar = requestCharacteristic else {
            finish(reason: "characteristic_discovery_failed", detail: "missing_request_characteristic")
            return
        }
        guard responseCharacteristic != nil else {
            finish(reason: "characteristic_discovery_failed", detail: "missing_response_characteristic")
            return
        }
        guard let bytes = MeshxFetchProtocol.encodeRequest(request) else {
            finish(reason: "encode_request_failed", detail: nil)
            return
        }

        phase = .writeRequest
        scheduleTimeout(.writeRequest)
        peripheral.writeValue(bytes, for: reqChar, type: .withResponse)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        clearTimeout()
        if let error = error {
            finish(reason: "characteristic_write_failed", detail: String(describing: error))
            return
        }
        guard let respChar = responseCharacteristic else {
            finish(reason: "characteristic_read_failed", detail: "missing_response_characteristic")
            return
        }
        phase = .readResponse
        scheduleTimeout(.readResponse)
        peripheral.readValue(for: respChar)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        clearTimeout()
        if let error = error {
            finish(reason: "characteristic_read_failed", detail: String(describing: error))
            return
        }
        guard characteristic.uuid == MeshxFetchGattUUID.response else { return }
        guard let bytes = characteristic.value else {
            finish(reason: "characteristic_read_failed", detail: "empty_response")
            return
        }
        guard let response = MeshxFetchProtocol.decodeResponse(bytes) else {
            finish(reason: "decode_response_failed", detail: nil)
            return
        }
        guard response.status == MeshxFetchProtocol.statusOK,
              let envelope = response.envelope else {
            finish(
                reason: "fetch_status_\(response.status)",
                detail: response.reason
            )
            return
        }
        finish(envelope: envelope)
    }
}
#endif
