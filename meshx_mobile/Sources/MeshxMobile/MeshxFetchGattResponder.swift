#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth

/// Swift mirror of `MeshxFetchGatt.kt`'s *responder* (server) path —
/// the iOS-side GATT service that serves a full MX envelope to peer
/// requesters via the MFQ/MFR protocol.
///
/// This is the symmetric counterpart to `MeshxFetchGattClient`: that
/// type pulls full envelopes from a peer; this type serves them. With
/// both types, an iOS device can play either side of the MX
/// full-envelope fetch path that the Android-side `MeshxFetchGatt`
/// already supports.
///
/// Service / characteristic UUIDs match `MeshxFetchGattUUID` (defined
/// in `MeshxFetchGatt.swift`) which in turn matches
/// `MeshxFetchGatt.kt:741-743` — required for cross-platform GATT
/// service discovery.

public protocol MeshxFetchGattResponderDelegate: AnyObject {
    func meshxFetchResponderDidStart()
    func meshxFetchResponderDidFail(reason: String)
    /// Fires after each successful MFQ Request decode — even
    /// `STATUS_NOT_FOUND` and `STATUS_INVALID_REQUEST` count, so the
    /// delegate sees every protocol-level event for observability.
    func meshxFetchResponderDidServeRequest(
        request: MeshxFetchProtocol.Request,
        status: UInt8
    )
}

public extension MeshxFetchGattResponderDelegate {
    func meshxFetchResponderDidStart() {}
    func meshxFetchResponderDidFail(reason: String) {}
    func meshxFetchResponderDidServeRequest(
        request: MeshxFetchProtocol.Request,
        status: UInt8
    ) {}
}

/// One-envelope GATT fetch responder.
///
/// Lifecycle mirrors `MeshxFetchGatt.kt::startResponder` /
/// `stopResponder`:
///
/// ```swift
/// let responder = MeshxFetchGattResponder(
///     envelope: envelope,
///     responderPeerId: "meshx-ios-smoke"
/// )
/// responder.start()
/// // ... peer connects, writes MFQ Request, reads MFR Response ...
/// responder.stop()
/// ```
///
/// Call `start()` to add the GATT service + begin advertising the
/// connectable fetch-service UUID. Call `stop()` to remove the
/// service + stop advertising. `start()` is idempotent across
/// `CBPeripheralManager` state changes — if Bluetooth is not yet
/// poweredOn, the responder waits for the state callback and starts
/// then.
///
/// Counters (`preparedOkCount`, `servedReadCount`) expose
/// success-observation metrics symmetric to the Android side, so
/// instrumented smoke tests can assert end-to-end success.
public final class MeshxFetchGattResponder: NSObject {
    public weak var delegate: MeshxFetchGattResponderDelegate?

    private let manager: CBPeripheralManager
    private let envelope: Data
    private let messageIdHash: Data
    private let responderPeerId: String

    private var requestCharacteristic: CBMutableCharacteristic?
    private var responseCharacteristic: CBMutableCharacteristic?
    private var service: CBMutableService?
    private var serviceAdded = false
    private var shouldServe = false

    /// Bytes of the most recently prepared MFR Response (encoded form).
    /// Returned on every read of the response characteristic. Nil
    /// before any request has been processed.
    private var preparedResponseBytes: Data?

    private var _preparedOkCount = 0
    private var _servedReadCount = 0

    /// Number of MFQ Requests received that matched the served envelope's
    /// `messageIdHash` (i.e. the requester asked for the right envelope
    /// and the responder prepared a STATUS_OK response).
    public var preparedOkCount: Int { _preparedOkCount }

    /// Number of times a peer central read the response characteristic
    /// AFTER a non-empty response had been prepared.
    public var servedReadCount: Int { _servedReadCount }

    /// Initializes a responder serving `envelope`.
    ///
    /// `envelope` must be a v1 `MeshxMessageEnvelope` (starts with the
    /// `MX` magic). The hash served is `sha256(envelope.messageId)[0..8]`,
    /// matching the Android `MeshxFetchGatt`'s `messageIdHash`
    /// computation.
    ///
    /// Throws if the envelope can't be parsed — refuses to start
    /// rather than silently serving garbage.
    public init(
        envelope: Data,
        responderPeerId: String,
        queue: DispatchQueue? = nil
    ) throws {
        guard case .success(let parsed) = MessageEnvelope.parse(envelope) else {
            throw ResponderError.invalidEnvelope
        }
        self.envelope = envelope
        self.responderPeerId = responderPeerId
        self.messageIdHash = MeshxFetchGattResponder.messageIdHash(of: parsed.messageId)
        self.manager = CBPeripheralManager(delegate: nil, queue: queue)
        super.init()
        self.manager.delegate = self
    }

    public func start() {
        shouldServe = true
        guard manager.state == .poweredOn else {
            // peripheralManagerDidUpdateState will resume start once
            // BT comes up.
            return
        }
        configureServiceIfNeeded()
        startAdvertisingIfReady()
    }

    public func stop() {
        shouldServe = false
        if manager.isAdvertising {
            manager.stopAdvertising()
        }
        if let svc = service, serviceAdded {
            manager.remove(svc)
            serviceAdded = false
        }
        service = nil
        requestCharacteristic = nil
        responseCharacteristic = nil
        preparedResponseBytes = nil
    }

    public enum ResponderError: Error {
        case invalidEnvelope
        case stateNotPoweredOn(CBManagerState)
    }

    // MARK: - Internals

    private static func messageIdHash(of messageId: Data) -> Data {
        // SHA-256(messageId)[0..8] — matches MeshxFetchGatt.kt
        // (`MessageDigest.getInstance("SHA-256").digest(...).copyOfRange(0, 8)`)
        // and MeshxLegacyBeaconAdvertisement's beacon hash. We use
        // CryptoKit for the hash to avoid pulling in a separate SHA
        // dependency.
        #if canImport(CryptoKit)
        return Data(SHA256.hash(data: messageId)).prefix(8)
        #else
        // Fallback for hosts without CryptoKit — should not be hit on
        // iOS/macOS targets. Fail loudly so this surfaces at runtime
        // rather than silently producing a wrong hash.
        fatalError("MeshxFetchGattResponder requires CryptoKit for SHA-256")
        #endif
    }

    private func configureServiceIfNeeded() {
        guard service == nil else { return }

        let req = CBMutableCharacteristic(
            type: MeshxFetchGattUUID.request,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let resp = CBMutableCharacteristic(
            type: MeshxFetchGattUUID.response,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let svc = CBMutableService(type: MeshxFetchGattUUID.service, primary: true)
        svc.characteristics = [req, resp]

        requestCharacteristic = req
        responseCharacteristic = resp
        service = svc
        manager.add(svc)
    }

    private func startAdvertisingIfReady() {
        guard shouldServe, serviceAdded, !manager.isAdvertising else { return }
        var advertisement: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [MeshxFetchGattUUID.service]
        ]
        if !responderPeerId.isEmpty {
            advertisement[CBAdvertisementDataLocalNameKey] = responderPeerId
        }
        manager.startAdvertising(advertisement)
    }

    public struct PreparedResponse: Equatable {
        public var request: MeshxFetchProtocol.Request
        public var response: MeshxFetchProtocol.Response
        public var encoded: Data
    }

    public func prepareResponse(for requestBytes: Data) -> PreparedResponse {
        let request: MeshxFetchProtocol.Request
        let status: UInt8
        let envelopeBytes: Data?
        let reason: String?

        if let decoded = MeshxFetchProtocol.decodeRequest(requestBytes) {
            request = decoded
            if decoded.messageIdHash == self.messageIdHash {
                status = MeshxFetchProtocol.statusOK
                envelopeBytes = envelope
                reason = nil
            } else {
                status = MeshxFetchProtocol.statusNotFound
                envelopeBytes = nil
                reason = "not_found"
            }
        } else {
            request = MeshxFetchProtocol.Request(
                requestId: "invalid",
                messageIdHash: Data(repeating: 0, count: 8),
                requesterPeerId: nil
            )
            status = MeshxFetchProtocol.statusInvalidRequest
            envelopeBytes = nil
            reason = "invalid_request"
        }

        let response = MeshxFetchProtocol.Response(
            requestId: request.requestId,
            messageIdHash: request.messageIdHash,
            status: status,
            envelope: envelopeBytes,
            reason: reason
        )

        return PreparedResponse(
            request: request,
            response: response,
            encoded: MeshxFetchProtocol.encodeResponse(response)
        )
    }
}

#if canImport(CryptoKit)
import CryptoKit
#endif

extension MeshxFetchGattResponder: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if shouldServe {
                configureServiceIfNeeded()
                startAdvertisingIfReady()
            }
        case .unknown, .resetting:
            // Transient — wait for the next state update.
            break
        default:
            delegate?.meshxFetchResponderDidFail(
                reason: "bluetooth state not poweredOn: \(peripheral.state.rawValue)"
            )
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error = error {
            delegate?.meshxFetchResponderDidFail(reason: "add service failed: \(error)")
            return
        }
        guard service.uuid == MeshxFetchGattUUID.service else { return }
        serviceAdded = true
        startAdvertisingIfReady()
    }

    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error = error {
            delegate?.meshxFetchResponderDidFail(reason: "start advertising failed: \(error)")
            return
        }
        delegate?.meshxFetchResponderDidStart()
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            handleWrite(peripheral: peripheral, attRequest: request)
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        guard request.characteristic.uuid == MeshxFetchGattUUID.response else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        guard request.offset == 0 else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        let bytes = preparedResponseBytes ?? Data()
        request.value = bytes
        peripheral.respond(to: request, withResult: .success)

        // Count only reads that actually carried response bytes — a
        // zero-length read means no prior write prepared one, which the
        // smoke test should not interpret as success.
        if !bytes.isEmpty {
            _servedReadCount += 1
        }
    }

    private func handleWrite(peripheral: CBPeripheralManager, attRequest: CBATTRequest) {
        guard attRequest.characteristic.uuid == MeshxFetchGattUUID.request else {
            peripheral.respond(to: attRequest, withResult: .attributeNotFound)
            return
        }
        guard attRequest.offset == 0 else {
            peripheral.respond(to: attRequest, withResult: .invalidOffset)
            return
        }
        guard let value = attRequest.value, !value.isEmpty else {
            // Empty write — reply success but don't prepare anything.
            // Mirrors Android's onCharacteristicWriteRequest behavior.
            peripheral.respond(to: attRequest, withResult: .success)
            return
        }

        let prepared = prepareResponse(for: value)
        if prepared.response.status == MeshxFetchProtocol.statusOK {
            _preparedOkCount += 1
        }
        preparedResponseBytes = prepared.encoded
        peripheral.respond(to: attRequest, withResult: .success)
        delegate?.meshxFetchResponderDidServeRequest(
            request: prepared.request,
            status: prepared.response.status
        )
    }
}
#endif
