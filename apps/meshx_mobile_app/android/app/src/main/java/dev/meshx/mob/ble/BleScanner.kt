package dev.meshx.mob.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.SystemClock
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
    private val sink: BleEventSink
) {

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

        handleScanFields(deviceId, rssi, advertisement, observedAtMs)
    }

    internal fun handleScanFields(
        deviceId: String,
        rssi: Int,
        advertisement: ByteArray,
        observedAtMs: Long
    ) {
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
            is MeshxMessageAdvertisement.DecodeResult.ReceivedBeacon -> sink.accept(decoded.event)
            is MeshxMessageAdvertisement.DecodeResult.Error -> sink.accept(decoded.event)
            MeshxMessageAdvertisement.DecodeResult.NotMessageAdvertisement -> sink.accept(advertisementEvent)
        }
    }
}
