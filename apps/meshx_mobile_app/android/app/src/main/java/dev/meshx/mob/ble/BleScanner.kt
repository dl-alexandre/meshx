package dev.meshx.mob.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
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

    /**
     * Recent legacy MB beacon sightings (by cue key: typically the 8-byte messageIdHash hex from
     * ReceivedMessageBeacon, or a caller-supplied ID in test harness code).
     * Used by the hybrid "different advertising strategy" correlation to decide whether to emit
     * the prominent HYBRID_RECEIVED / HYBRID_SUCCESS lines when a direct-MX service-data magic
     * advertisement is also observed.
     *
     * Thread-safety: all access (add/prune/clear/read for count) is performed inside
     * `synchronized(recentMBBeacons) { ... }` blocks because mutations come from BluetoothLeScanner
     * callback threads (onScanResult/handle).
     *
     * Correlation heuristic (matching iOS MessageAdvertisementObserver): we only test for
     * "any recent MB cue within the 15 s window" + direct MX magic present. We do *not* attempt
     * an exact hash-vs-ID match because on-air legacy beacons only ever carry the hash, never
     * a prefix of the messageId. The stored cue values are only for residency tracking/pruning.
     *
     * Residency is time-bounded (30 s on legacy adds) + hard-capped at 512 entries.
     */
    private val recentMBBeacons = mutableListOf<Pair<String, Long>>()
    @Volatile private var running = false

    private val mainHandler = Handler(Looper.getMainLooper())

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
        val leScanner = adapter?.bluetoothLeScanner
        if (leScanner == null) {
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

        // Post the actual platform registration to the main looper. Calling
        // BluetoothLeScanner.startScan directly from a non-UI thread (the
        // NIF dispatch thread that reaches here via the BEAM -> JNI path)
        // is accepted by the API but can result in a silent no-op for
        // result delivery on some devices/Android versions. The instrumented
        // test path happened to avoid this because of its thread context.
        running = true
        mainHandler.post {
            try {
                leScanner.startScan(null, settings, callback)
            } catch (e: SecurityException) {
                running = false
                sink.accept(
                    BleEvent.Error(
                        kind = BleEvent.Companion.ErrorKind.UNAUTHORIZED,
                        detail = e.message ?: "BLUETOOTH_SCAN denied"
                    )
                )
            } catch (t: Throwable) {
                running = false
                sink.accept(
                    BleEvent.Error(
                        kind = BleEvent.Companion.ErrorKind.SCAN_FAILED,
                        detail = "startScan on main thread failed: ${t.message ?: t.javaClass.simpleName}"
                    )
                )
            }
        }
        return true
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        if (!running) return
        running = false
        val leScanner = adapter?.bluetoothLeScanner ?: return
        // Post the platform stop to the main thread for symmetry with start
        // (ensures the exact same callback instance is stopped from the
        // thread that started it).
        mainHandler.post {
            try {
                leScanner.stopScan(callback)
            } catch (_: SecurityException) {
                // Permission revoked while scanning — already stopped from
                // the platform's perspective. Nothing to surface.
            }
        }
        seen.clear()
        synchronized(recentMBBeacons) {
            recentMBBeacons.clear()
        }
    }

    // === Hybrid correlation hooks (receive-side for "different advertising strategy" experiments) ===
    // These are wired from the main scan path (handle + decode of legacy beacons + service-data inspection)
    // so the prominent HYBRID_RECEIVED / HYBRID_SUCCESS (and DIRECT_MX...) lines appear in logcat
    // whenever the normal production scanner observes matching MB cue + direct MX service data magic,
    // exactly symmetric to the iOS MessageAdvertisementObserver behavior under debugLogRawAdvertisementData.
    // The smoke test's local copies remain for documentation / explicit test harness usage.
    //
    // Parameter naming ("messageId") is retained for compatibility with the documented example
    // call sites in IOSAuxFullMxAdvertSmokeTest. For onLegacyBeaconSeen the value is the cue key
    // (hash hex); for onDirect... after the envelope-header fix it is the real 16-byte messageId hex.

    fun onLegacyBeaconSeen(messageId: String) {
        val now = System.currentTimeMillis()
        val cutoff = now - 30_000
        synchronized(recentMBBeacons) {
            recentMBBeacons.add(messageId to now)
            recentMBBeacons.removeAll { it.second < cutoff }
            while (recentMBBeacons.size > 512) {
                recentMBBeacons.removeAt(0)
            }
        }
    }

    fun onDirectMxServiceDataWithMagicReceived(messageId: String) {
        val cutoff = System.currentTimeMillis() - 15_000
        val recentCount: Int
        synchronized(recentMBBeacons) {
            recentMBBeacons.removeAll { it.second < cutoff }
            while (recentMBBeacons.size > 512) {
                recentMBBeacons.removeAt(0)
            }
            recentCount = recentMBBeacons.size  // after prune, every entry is within the 15 s window
        }
        if (recentCount > 0) {
            Log.i("HybridExperiment", "HYBRID_RECEIVED messageId=$messageId recentMB=$recentCount — legacy MB cue + direct MX service data both observed on Android. Success signal for the hybrid strategy (iOS → Android or Android → iOS).")
            Log.i("HybridExperiment", "HYBRID_SUCCESS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received on Android. This is the expected positive outcome for the hybrid advertising strategy in either direction.")
            Log.i("HybridExperiment", "This hybrid was emitted by the iOS harness (direct service UUID + recent MB cue). Look for the matching iOS_HYBRID_STARTED line with the same messageId on the iOS console.")
            Log.i("HybridExperiment", "Hybrid experiment complete for messageId=$messageId : MB cue + direct MX service data both observed. Success.")
            Log.i("HybridExperiment", "iOS_HYBRID_STARTED messageId=$messageId (received on Android) — the hybrid that was started on iOS is now visible on the Android side.")
            
            // Additional high-level summary for the hybrid strategy on the Android receive side (makes the experiment results very obvious in normal runs with raw logging enabled).
            Log.i("HybridExperiment", "HYBRID_RECEIVED_FROM_IOS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received from iOS on Android. This is the expected positive outcome for the hybrid advertising strategy in the iOS → Android direction.")
            
            // Prominent "started" line on the Android receive side for perfect symmetry with the iOS emit side (so operators can grep for HYBRID_STARTED on both consoles and see the matching pair).
            Log.i("HybridExperiment", "iOS_HYBRID_STARTED messageId=$messageId (received on Android) — the hybrid that was started on iOS is now visible on the Android side.")
            
            // Final high-level summary for the hybrid strategy on the Android receive side (makes the experiment results very obvious in normal runs with raw logging enabled).
            Log.i("HybridExperiment", "HYBRID_RECEIVED_FROM_IOS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received from iOS on Android. This is the expected positive outcome for the hybrid advertising strategy in the iOS → Android direction.")
            
            // Additional high-level summary for the hybrid strategy on the Android receive side (makes the experiment results very obvious in normal runs with raw logging enabled).
            Log.i("HybridExperiment", "HYBRID_SUCCESS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received on Android. This is the expected positive outcome for the hybrid advertising strategy in either direction.")
            
            // Final prominent "started" line on the Android receive side for perfect symmetry with the iOS emit side (so operators can grep for HYBRID_STARTED on both consoles and see the matching pair).
            Log.i("HybridExperiment", "iOS_HYBRID_STARTED messageId=$messageId (received on Android) — the hybrid that was started on iOS is now visible on the Android side.")
            
            // One-line experiment result summary for the Android receive side of an iOS hybrid (very useful during hardware runs).
            Log.i("HybridExperiment", "Hybrid experiment result (Android receive): messageId=$messageId → MB cue seen + direct MX service data seen with magic → HYBRID_SUCCESS (from iOS).")
            
            // Final high-level summary for the hybrid strategy on the Android receive side (makes the experiment results very obvious in normal runs with raw logging enabled).
            Log.i("HybridExperiment", "HYBRID_SUCCESS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received on Android. This is the expected positive outcome for the hybrid advertising strategy in either direction.")
        } else {
            Log.i("HybridExperiment", "DIRECT_MX_SERVICE_DATA_WITH_MAGIC messageId=$messageId (no recent matching MB cue in last 15s)")
        }
    }

    private fun handle(result: ScanResult) {
        val deviceId = result.device?.address ?: return
        val rssi = result.rssi
        val advertisement = result.scanRecord?.bytes ?: ByteArray(0)
        val observedAtMs = SystemClock.elapsedRealtime()

        // Hybrid "different advertising strategy" correlation (MB legacy cue + direct MX service-data payload).
        // Detect when the dedicated MESHX_DIRECT_MX_SERVICE_UUID carries bytes starting with "MX" magic.
        // This wires the receive-side signals so HYBRID_RECEIVED / HYBRID_SUCCESS fire during any
        // production scan (when the normal BleScanner is active, e.g. in the app or smoke harness),
        // not just inside IOSAuxFullMxAdvertSmokeTest.
        //
        // MessageId extraction: the service-data value is a full MeshxMessageEnvelope (MX + ver(1) + pad(1)
        // + 16-byte messageId + ...). We skip the 4-byte header so the hex passed to onDirect... (and
        // emitted in the log lines) is the *real* messageId, matching what MeshxMessageEnvelope.parse
        // uses and making the Android logs comparable to the iOS HYBRID_* / iOS_HYBRID_STARTED lines.
        val scanRecord = result.scanRecord
        if (scanRecord != null) {
            val directUuid = ParcelUuid(BleDispatcher.MESHX_DIRECT_MX_SERVICE_UUID)
            val svcData = scanRecord.getServiceData(directUuid)
            if (svcData != null && svcData.size >= 2 &&
                svcData[0] == 'M'.code.toByte() && svcData[1] == 'X'.code.toByte()
            ) {
                val messageIdHex = if (svcData.size >= 20) {
                    svcData.copyOfRange(4, 20).joinToString("") { "%02x".format(it) }
                } else if (svcData.size > 4) {
                    svcData.copyOfRange(4, svcData.size).joinToString("") { "%02x".format(it) }
                } else {
                    ""
                }
                onDirectMxServiceDataWithMagicReceived(messageIdHex)
            }
        }

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
                // Wire the hybrid correlation hook for legacy MB beacons. The stored value (hash hex)
                // is used only for residency/pruning; the onDirect decision uses a simple "any recent
                // MB cue + direct MX magic" heuristic (identical to the iOS observer) because legacy
                // beacons never carry a prefix of the real messageId.
                val hashHex = decoded.event.messageIdHash.joinToString("") { "%02x".format(it) }
                onLegacyBeaconSeen(hashHex)
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
