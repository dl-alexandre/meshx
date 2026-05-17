package dev.meshx.mob.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.SystemClock
import android.util.Log
import java.util.Base64
import java.util.concurrent.ConcurrentHashMap

/**
 * Thin wrapper around `BluetoothLeScanner`. Transport-only: classifies
 * scan results as either `DeviceDiscovered` (first sight) or
 * `AdvertisementReceived` (subsequent sights for the same device_id).
 *
 * No mesh routing, no peer graph, no persistence. The seen-set is
 * in-memory and cleared on `stop()`.
 */
class BleScanner(
    private val adapter: BluetoothAdapter?,
    private val sink: BleEventSink,
    private val fetchCoordinator: MeshxBeaconFetchCoordinatorHook? = null
) {

    private val rawLogged = ConcurrentHashMap.newKeySet<String>()
    private val seen = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var running = false

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handle(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach(::handle)
        }

        override fun onScanFailed(errorCode: Int) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.SCAN_FAILED,
                    detail = "scan failed (code=$errorCode)"
                )
            )
        }
    }

    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        if (running) return true
        val scanner = adapter?.bluetoothLeScanner
        if (scanner == null) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.BLUETOOTH_OFF,
                    detail = "no BluetoothLeScanner (adapter null or BT off)"
                )
            )
            return false
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .build()

        try {
            scanner.startScan(null, settings, callback)
            running = true
            return true
        } catch (e: SecurityException) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.UNAUTHORIZED,
                    detail = e.message ?: "BLUETOOTH_SCAN denied"
                )
            )
            return false
        }
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        if (!running) return
        running = false
        val scanner = adapter?.bluetoothLeScanner ?: return
        try {
            scanner.stopScan(callback)
        } catch (_: SecurityException) {
            // Permission revoked while scanning — already stopped from
            // the platform's perspective. Nothing to surface.
        }
        seen.clear()
    }

    private fun handle(result: ScanResult) {
        val deviceId = result.device?.address ?: return
        val rssi = result.rssi
        val advertisement = result.scanRecord?.bytes ?: ByteArray(0)
        val observedAtMs = SystemClock.elapsedRealtime()

        handleScanFields(
            deviceId = deviceId,
            rssi = rssi,
            advertisement = advertisement,
            observedAtMs = observedAtMs,
            manufacturerIds = result.scanRecord?.manufacturerSpecificDataIds().orEmpty(),
            serviceUuids = result.scanRecord?.serviceUuids?.map { it.uuid.toString() }.orEmpty()
        )
    }

    internal fun handleScanFields(
        deviceId: String,
        rssi: Int,
        advertisement: ByteArray,
        observedAtMs: Long,
        manufacturerIds: List<Int> = emptyList(),
        serviceUuids: List<String> = emptyList()
    ) {
        maybeLogRawScanRecord(deviceId, rssi, advertisement, manufacturerIds, serviceUuids)

        val sourceEvent: String
        val advertisementEvent = if (seen.add(deviceId)) {
            sourceEvent = "device_discovered"
            BleEvent.DeviceDiscovered(
                deviceId = deviceId,
                rssi = rssi,
                advertisement = advertisement,
                observedAtMs = observedAtMs
            )
        } else {
            sourceEvent = "advertisement_received"
            BleEvent.AdvertisementReceived(
                deviceId = deviceId,
                rssi = rssi,
                advertisement = advertisement,
                observedAtMs = observedAtMs
            )
        }

        when (val decoded = MeshxMessageAdvertisement.decodeScanRecord(
            advertisement = advertisement,
            deviceId = deviceId,
            rssi = rssi,
            observedAtMs = observedAtMs,
            sourceEvent = sourceEvent
        )) {
            is MeshxMessageAdvertisement.DecodeResult.Received -> sink.accept(decoded.event)
            is MeshxMessageAdvertisement.DecodeResult.ReceivedBeacon -> {
                sink.accept(decoded.event)
                fetchCoordinator?.onLegacyBeacon(decoded.event)
            }
            is MeshxMessageAdvertisement.DecodeResult.Error -> sink.accept(decoded.event)
            MeshxMessageAdvertisement.DecodeResult.NotMessageAdvertisement -> {
                sink.accept(advertisementEvent)
                if (serviceUuids.any { it.equals(MeshxFetchGatt.SERVICE_UUID.toString(), ignoreCase = true) }) {
                    fetchCoordinator?.onFetchServiceAdvertisement(
                        deviceId = deviceId,
                        messageIdHash = fetchMessageHashFromLocalName(advertisement),
                        rssi = rssi,
                        advertisement = advertisement
                    )
                }
            }
        }
    }

    private fun maybeLogRawScanRecord(
        deviceId: String,
        rssi: Int,
        advertisement: ByteArray,
        manufacturerIds: List<Int>,
        serviceUuids: List<String>
    ) {
        val hasManufacturerData = manufacturerIds.isNotEmpty()
        val hasServiceUuids = serviceUuids.isNotEmpty()
        val key = if (hasManufacturerData || hasServiceUuids) {
            "$deviceId:${manufacturerIds.joinToString(",")}:${serviceUuids.joinToString(",")}:${advertisement.contentHashCode()}"
        } else {
            deviceId
        }

        if (!hasManufacturerData && !hasServiceUuids && rawLogged.size >= MAX_RAW_SCAN_DEVICE_LOGS) return
        if (!rawLogged.add(key)) return

        val payload = buildString {
            append("device_id=").append(deviceId)
            append(" rssi=").append(rssi)
            append(" advertisement_b64=")
            append(Base64.getEncoder().encodeToString(advertisement))
            append(" manufacturer_ids=")
            append(manufacturerIds.joinToString(prefix = "[", postfix = "]"))
            append(" service_uuids=")
            append(serviceUuids.joinToString(prefix = "[", postfix = "]"))
        }

        Log.i(RAW_SCAN_TAG, payload)
    }

    companion object {
        private const val RAW_SCAN_TAG = "MeshxBleScanRaw"
        private const val MAX_RAW_SCAN_DEVICE_LOGS = 200
    }
}

private fun android.bluetooth.le.ScanRecord.manufacturerSpecificDataIds(): List<Int> {
    val data = manufacturerSpecificData ?: return emptyList()
    return (0 until data.size()).map { index -> data.keyAt(index) }
}

private fun fetchMessageHashFromLocalName(advertisement: ByteArray): ByteArray? {
    var offset = 0
    while (offset < advertisement.size) {
        val length = advertisement[offset].toInt() and 0xFF
        if (length == 0) return null
        val structureStart = offset + 1
        val structureEnd = structureStart + length
        if (structureEnd > advertisement.size) return null
        val type = advertisement[structureStart].toInt() and 0xFF
        if (type == 0x08 || type == 0x09) {
            val value = advertisement.copyOfRange(structureStart + 1, structureEnd).toString(Charsets.UTF_8)
            if (value.length == 18 && value.startsWith("mx")) {
                return value.substring(2).decodeHexOrNull()
            }
        }
        offset = structureEnd
    }
    return null
}

private fun String.decodeHexOrNull(): ByteArray? {
    if (length % 2 != 0) return null
    val out = ByteArray(length / 2)
    for (i in out.indices) {
        val hi = this[i * 2].digitToIntOrNull(16) ?: return null
        val lo = this[i * 2 + 1].digitToIntOrNull(16) ?: return null
        out[i] = ((hi shl 4) or lo).toByte()
    }
    return out
}
