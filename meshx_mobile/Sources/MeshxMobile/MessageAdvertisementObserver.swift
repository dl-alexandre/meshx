#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth

public protocol MessageAdvertisementObserverDelegate: AnyObject {
    func meshxDidObserveReceivedMessage(_ event: ReceivedMessageEvent)
    func meshxDidObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int)
    func meshxMessageObserverDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    )
    func meshxMessageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    )
    func meshxMessageObserverDidStartScan()
    func meshxMessageObserverDidUpdateState(_ state: String)
    func meshxMessageObserverDidError(_ error: Error)

    /// Optional. Called when the observer's GATT-fetch coordinator
    /// successfully pulled a full MX envelope from a peer that earlier
    /// advertised an MB legacy beacon. The full envelope bytes start
    /// with the "MX" magic and can be parsed via
    /// `MessageEnvelope.parse`.
    func meshxMessageObserverDidFetchEnvelope(
        envelope: Data,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement,
        rssi: Int
    )

    /// Optional. Called when a fetch attempt fails. `reason` is the
    /// phase string ("connect_failed", "service_discovery_failed", ...).
    func meshxMessageObserverDidFailFetch(
        reason: String,
        detail: String?,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement
    )
}

public extension MessageAdvertisementObserverDelegate {
    func meshxMessageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    ) {}
    func meshxMessageObserverDidObserveLegacyBeacon(
        _ beacon: MeshxLegacyBeaconAdvertisement,
        deviceId: String,
        rssi: Int
    ) {}
    func meshxMessageObserverDidFetchEnvelope(
        envelope: Data,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement,
        rssi: Int
    ) {}
    func meshxMessageObserverDidFailFetch(
        reason: String,
        detail: String?,
        fromDeviceId: String,
        beacon: MeshxLegacyBeaconAdvertisement
    ) {}
}

public final class MessageAdvertisementObserver: NSObject {
    public weak var delegate: MessageAdvertisementObserverDelegate?

    private let central: CBCentralManager
    private var shouldScan = false

    /// Requester peer id passed in MFQ Request frames. Optional; the
    /// Android responder treats it as informational.
    public var requesterPeerId: String?

    /// Set to false to disable the GATT-fetch follow-up entirely (so
    /// the observer only reports beacons / decode errors and never opens
    /// a GATT connection). Default: true.
    public var fetchOnBeacon: Bool = true

    /// Skip fetches for a peripheral whose `messageIdHash` matches one
    /// we've successfully fetched (or attempted) within this window.
    public var fetchDedupTTL: TimeInterval = 60.0

    private var fetchInFlight: [UUID: MeshxFetchGattClient] = [:]
    private var fetchedHashes: [Data: Date] = [:]
    private var pendingBeacons: [UUID: (beacon: MeshxLegacyBeaconAdvertisement, rssi: Int)] = [:]
    /// Recent MB legacy beacons keyed by messageIdHash. Used when we
    /// later see a connectable fetch-service advert from a DIFFERENT
    /// MAC than the MB beacon (Android uses two private resolvable
    /// addresses, one per advertise call). We pick the most recent
    /// beacon's hash to populate the MFQ Request.
    private var recentBeacons: [(beacon: MeshxLegacyBeaconAdvertisement, rssi: Int, at: Date)] = []

    public override init() {
        self.central = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        self.central.delegate = self
    }

    public func startScan() {
        shouldScan = true
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                delegate?.meshxMessageObserverDidError(ObserverError.stateNotPoweredOn(central.state))
            }
            return
        }

        // Scan with `withServices: nil` so MB legacy beacons (their
        // primary-channel manufacturer-data advert is the supported path
        // on iOS) reach `didDiscover`. Pinning a service UUID filter
        // was tested and did NOT enable extended-advertising AUX_ADV_IND
        // reception on iPhone 13/iOS 26.4 — see commit notes. Full MX
        // envelopes >31 bytes must arrive via the GATT fetch path.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        delegate?.meshxMessageObserverDidStartScan()
    }

    public func stopScan() {
        shouldScan = false
        central.stopScan()
    }

    public enum ObserverError: Error {
        case stateNotPoweredOn(CBManagerState)
    }
}

extension MessageAdvertisementObserver: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.meshxMessageObserverDidUpdateState(String(describing: central.state))

        if central.state == .poweredOn, shouldScan {
            startScan()
        } else if shouldScan && central.state != .poweredOn && central.state != .unknown && central.state != .resetting {
            delegate?.meshxMessageObserverDidError(ObserverError.stateNotPoweredOn(central.state))
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let fullAdvertisement = manufacturerData ?? Data()
        let receivedAt = UInt64(Date().timeIntervalSince1970 * 1000)
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map(\.uuidString)
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String

        delegate?.meshxMessageObserverDidObserveAdvertisement(
            deviceId: peripheral.identifier.uuidString,
            rssi: RSSI.intValue,
            localName: localName,
            serviceUUIDs: serviceUUIDs,
            manufacturerDataLength: manufacturerData?.count ?? 0
        )

        switch MessageAdvertisement.decode(
            manufacturerData: manufacturerData,
            fullAdvertisement: fullAdvertisement,
            deviceId: peripheral.identifier.uuidString,
            rssi: RSSI.intValue,
            receivedAt: receivedAt
        ) {
        case .received(let event):
            delegate?.meshxDidObserveReceivedMessage(event)

        case .decodeError(let reason):
            delegate?.meshxDidObserveMessageDecodeError(
                reason,
                deviceId: peripheral.identifier.uuidString,
                rssi: RSSI.intValue
            )

        case .notMessageAdvertisement:
            if let manufacturerData,
               let beacon = MeshxLegacyBeaconAdvertisement.parse(manufacturerData: manufacturerData) {
                delegate?.meshxMessageObserverDidObserveLegacyBeacon(
                    beacon,
                    deviceId: peripheral.identifier.uuidString,
                    rssi: RSSI.intValue
                )
                rememberBeacon(beacon, rssi: RSSI.intValue)
            }
            // Connectable peripherals advertising the MeshX fetch service
            // are the actual GATT-fetch entry point. The MB beacon's
            // peripheral (different MAC, non-connectable) is just the
            // "I have a message" cue.
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
               serviceUUIDs.contains(MeshxFetchGattUUID.service) {
                maybeStartFetchOnFetchService(
                    for: peripheral,
                    rssi: RSSI.intValue
                )
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        fetchInFlight[peripheral.identifier]?.handleConnected()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        fetchInFlight[peripheral.identifier]?.handleFailedToConnect(error: error)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        fetchInFlight[peripheral.identifier]?.handleDisconnected(error: error)
        fetchInFlight.removeValue(forKey: peripheral.identifier)
    }
}

extension MessageAdvertisementObserver: MeshxFetchGattClientDelegate {
    public func meshxFetchDidComplete(
        envelope: Data,
        peripheral: CBPeripheral,
        request: MeshxFetchProtocol.Request
    ) {
        guard let pending = pendingBeacons.removeValue(forKey: peripheral.identifier) else { return }
        fetchInFlight.removeValue(forKey: peripheral.identifier)
        delegate?.meshxMessageObserverDidFetchEnvelope(
            envelope: envelope,
            fromDeviceId: peripheral.identifier.uuidString,
            beacon: pending.beacon,
            rssi: pending.rssi
        )
    }

    public func meshxFetchDidFail(
        reason: String,
        detail: String?,
        request: MeshxFetchProtocol.Request
    ) {
        // Find the peripheral whose in-flight client matched this request.
        // We key by peripheral.identifier on the dictionary; iterate to find.
        let entry = fetchInFlight.first { _, client in client.matches(request: request) }
        if let (id, _) = entry {
            fetchInFlight.removeValue(forKey: id)
            if let pending = pendingBeacons.removeValue(forKey: id) {
                delegate?.meshxMessageObserverDidFailFetch(
                    reason: reason,
                    detail: detail,
                    fromDeviceId: id.uuidString,
                    beacon: pending.beacon
                )
            }
        }
    }
}

extension MessageAdvertisementObserver {
    fileprivate func rememberBeacon(_ beacon: MeshxLegacyBeaconAdvertisement, rssi: Int) {
        let now = Date()
        recentBeacons.append((beacon, rssi, now))
        // Cheap GC: drop entries older than dedup TTL.
        recentBeacons.removeAll { now.timeIntervalSince($0.at) >= fetchDedupTTL }
    }

    fileprivate func maybeStartFetchOnFetchService(
        for peripheral: CBPeripheral,
        rssi: Int
    ) {
        guard fetchOnBeacon else { return }
        guard fetchInFlight[peripheral.identifier] == nil else { return }
        guard let recent = recentBeacons.max(by: { $0.at < $1.at }) else { return }

        let now = Date()
        fetchedHashes = fetchedHashes.filter { now.timeIntervalSince($0.value) < fetchDedupTTL }
        if let last = fetchedHashes[recent.beacon.messageIdHash],
           now.timeIntervalSince(last) < fetchDedupTTL {
            return
        }
        fetchedHashes[recent.beacon.messageIdHash] = now

        let request = MeshxFetchProtocol.Request(
            requestId: UUID().uuidString,
            messageIdHash: recent.beacon.messageIdHash,
            requesterPeerId: requesterPeerId
        )
        let client = MeshxFetchGattClient(
            central: central,
            peripheral: peripheral,
            request: request
        )
        client.delegate = self
        fetchInFlight[peripheral.identifier] = client
        // Track which MB beacon's metadata to use when emitting the
        // resulting `received_message` event.
        pendingBeacons[peripheral.identifier] = (recent.beacon, recent.rssi)
        client.start()
    }
}

extension MeshxFetchGattClient {
    /// Used by the observer to find which in-flight client a delegate
    /// callback belongs to. Exposed via this extension so we don't have
    /// to add a `request` accessor to the public API.
    fileprivate func matches(request other: MeshxFetchProtocol.Request) -> Bool {
        return request.requestId == other.requestId
    }
}
#endif
