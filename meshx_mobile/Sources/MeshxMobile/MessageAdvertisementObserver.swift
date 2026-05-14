#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth

public protocol MessageAdvertisementObserverDelegate: AnyObject {
    func meshxDidObserveReceivedMessage(_ event: ReceivedMessageEvent)
    func meshxDidObserveMessageDecodeError(_ reason: String, deviceId: String, rssi: Int)
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
}

public extension MessageAdvertisementObserverDelegate {
    func meshxMessageObserverDidObserveAdvertisement(
        deviceId: String,
        rssi: Int,
        localName: String?,
        serviceUUIDs: [String],
        manufacturerDataLength: Int
    ) {}
}

public final class MessageAdvertisementObserver: NSObject {
    public weak var delegate: MessageAdvertisementObserverDelegate?

    private let central: CBCentralManager
    private var shouldScan = false

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
            break
        }
    }
}
#endif
