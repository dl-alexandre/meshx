package dev.meshx.mob.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.util.Collections
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Receiver-side smoke test for the iOS→Android hybrid direct-MX receive path.
 *
 * When the iOS harness is launched with `--meshx-auto-direct-mx-hybrid-advertise`, it emits:
 *   - a short legacy MB (22-byte manufacturer data) cue (fleet-compatible beacon containing 8-byte hashes)
 *   - the full v1 MeshxMessageEnvelope carried in service data under MESHX_DIRECT_MX_SERVICE_UUID (...1001)
 *
 * This test exercises the production `BleScanner` (so the `HYBRID_*`, `DIRECT_MX_SERVICE_DATA_WITH_MAGIC`,
 * `iOS_HYBRID_STARTED (received on Android)`, and `HYBRID_SUCCESS` / `HYBRID_RECEIVED_FROM_IOS` lines
 * are emitted exactly as they would be in a normal app run) while also performing explicit inspection
 * of scan records to assert:
 *
 *   - MB legacy cue (22-byte manufacturer data beacon) is received and recognized (as ReceivedMessageBeacon)
 *   - Direct-MX service-data advertisement on UUID `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1001` is observed
 *     and its payload is successfully parsed as a full MX envelope via `MeshxMessageEnvelope.parse`
 *   - The extracted 16-byte messageId (or its 8-byte SHA-256 hash / sender hash) from the direct envelope
 *     correlates with (matches) the hash key(s) from at least one observed MB cue — using proper hash
 *     computation, never a naive string-prefix match between hash-hex and full messageId (guards the
 *     exact class of off-by-header / format-mismatch bugs seen in earlier hybrid work)
 *   - No MeshxFetchGatt fetch-service (....2000) advertisements were observed during the window,
 *     proving the message was delivered directly via the service-data carrier with zero GATT round-trip
 *
 * The test is deliberately lightweight: real BluetoothAdapter + real leScanner + `BleScanner` with
 * `InMemoryEventSink` + a minimal `MeshxBeaconFetchCoordinatorHook` recording implementation.
 * No heavy mocks. The same permission set and adapter-guard pattern as `IOSAuxFullMxAdvertSmokeTest`.
 *
 * === Ready-to-run commands (iOS emitter + Android receiver) ===
 *
 * Launch iOS harness (emitter) — run this first on the iOS device (it will emit the hybrid for ~8 s windows
 * and log iOS_HYBRID_STARTED / iOS_HYBRID_WINDOW_COMPLETE):
 *
 *   xcrun devicectl device process launch --device <UDID> --terminate-existing --console \
 *     dev.meshx.mobile.harness -- --meshx-auto-direct-mx-hybrid-advertise
 *
 * (Optional but recommended for deeper radio evidence: add --meshx-log-raw-advert-data to the iOS side.)
 *
 * Then, while iOS is emitting, run this test on the Android device:
 *
 *   adb shell am instrument -w -e class dev.meshx.mob.ble.IOSHybridDirectMxReceiveTest \
 *     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * Success signals (must appear for a passing evidence-grade run):
 *   - Android logcat (from BleScanner + this test): "HYBRID_RECEIVED", "HYBRID_SUCCESS", "HYBRID_RECEIVED_FROM_IOS",
 *     "iOS_HYBRID_STARTED messageId=... (received on Android)", "DIRECT_MX_SERVICE_DATA_WITH_MAGIC",
 *     and the test's own "HYBRID_SUCCESS (test)" (the production heuristic emits on "any recent MB cue + magic"
 *     while this test additionally asserts strict hash correlation on the parsed envelope).
 *   - The exact same messageId (full 16-byte hex) appears on both iOS (iOS_HYBRID_STARTED) and Android
 *   - Test asserts pass: MB cue recognized, direct MX envelope parsed, hash correlation present,
 *     zero fetch-service sightings (direct path only)
 *
 * The instrumentation output + logcat together form the durable release evidence bundle for the
 * iOS→Android hybrid direct-MX receive path.
 */
@RunWith(AndroidJUnit4::class)
class IOSHybridDirectMxReceiveTest {

    @get:Rule
    val permissions: GrantPermissionRule = GrantPermissionRule.grant(
        android.Manifest.permission.BLUETOOTH_ADVERTISE,
        android.Manifest.permission.BLUETOOTH_CONNECT,
        android.Manifest.permission.BLUETOOTH_SCAN
    )

    @Test
    fun receivesHybridDirectMxFromIOS() {
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        requireNotNull(adapter)
        assertTrue("Bluetooth must be enabled", adapter.isEnabled)

        // Production path under test: BleScanner + InMemoryEventSink + hook.
        // This causes the real hybrid correlation logic (recentMBBeacons, onLegacyBeaconSeen,
        // onDirectMxServiceDataWithMagicReceived, and all the HYBRID_* / iOS_HYBRID_* log lines)
        // to execute exactly as it does in RealBleBridge / normal app scanning.
        val sink = InMemoryEventSink()
        val fetchHook = object : MeshxBeaconFetchCoordinatorHook {
            val legacyBeacons = Collections.synchronizedList(mutableListOf<BleEvent.ReceivedMessageBeacon>())
            val fetchAdverts = Collections.synchronizedList(mutableListOf<String>())

            override fun onLegacyBeacon(beacon: BleEvent.ReceivedMessageBeacon) {
                legacyBeacons.add(beacon)
            }

            override fun onFetchServiceAdvertisement(
                deviceId: String,
                messageIdHash: ByteArray?,
                rssi: Int,
                advertisement: ByteArray
            ) {
                fetchAdverts.add(deviceId)
            }
        }
        val bleScanner = BleScanner(adapter, sink, fetchHook)

        // Detailed observer for explicit asserts (MB cue decode + full MX envelope parse from
        // direct service data + fetch-service sighting counter). Runs in parallel with the
        // production BleScanner so we get both the nice log evidence and deterministic JUnit asserts.
        val detailedBeacons = Collections.synchronizedList(mutableListOf<BleEvent.ReceivedMessageBeacon>())
        val detailedDirects = Collections.synchronizedList(mutableListOf<MeshxMessageEnvelope.Decoded>())
        val fetchSvcCount = AtomicInteger(0)

        val directUuid = ParcelUuid(BleDispatcher.MESHX_DIRECT_MX_SERVICE_UUID)

        val callback = object : ScanCallback() {
            private fun handleResult(result: ScanResult) {
                val record = result.scanRecord ?: return
                val bytes = record.bytes ?: return
                val deviceId = result.device?.address ?: "unknown"
                val now = System.currentTimeMillis()

                // MB legacy cue recognition (22-byte manufacturer beacon path)
                when (val decoded = MeshxMessageAdvertisement.decodeScanRecord(
                    advertisement = bytes,
                    deviceId = deviceId,
                    rssi = result.rssi,
                    observedAtMs = now,
                    sourceEvent = "ios_hybrid_direct_mx_receive"
                )) {
                    is MeshxMessageAdvertisement.DecodeResult.ReceivedBeacon ->
                        detailedBeacons.add(decoded.event)
                    else -> Unit
                }

                // Direct-MX service-data carrier with full envelope payload
                val svcData = record.getServiceData(directUuid)
                if (svcData != null && svcData.size >= 2 &&
                    svcData[0] == 'M'.code.toByte() && svcData[1] == 'X'.code.toByte()
                ) {
                    when (val pr = MeshxMessageEnvelope.parse(svcData)) {
                        is MeshxMessageEnvelope.ParseResult.Ok -> {
                            detailedDirects.add(pr.envelope)
                            val idHex = pr.envelope.messageId.joinToString("") { "%02x".format(it) }
                            Log.i(
                                "IOSHybridDirectMxReceiveTest",
                                "DIRECT_MX_SERVICE_DATA_WITH_MAGIC_PARSED messageId=$idHex bytes=${svcData.size}"
                            )
                        }
                        else -> Unit
                    }
                }

                // Fetch service sighting (should be absent for a pure direct-MX hybrid emit)
                val hasFetchSvc = record.serviceUuids?.any {
                    it.uuid == MeshxFetchGatt.SERVICE_UUID
                } == true
                if (hasFetchSvc) {
                    fetchSvcCount.incrementAndGet()
                }
            }

            override fun onScanResult(callbackType: Int, result: ScanResult) {
                handleResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach { handleResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e("IOSHybridDirectMxReceiveTest", "scan_failed code=$errorCode")
            }
        }

        val leScanner = adapter.bluetoothLeScanner
        assertNotNull("BluetoothLeScanner must be available", leScanner)

        try {
            bleScanner.start()
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
                .build()
            leScanner.startScan(null, settings, callback)

            // Wait for hybrid evidence (iOS emits ~8 s windows; 45 s gives comfortable margin
            // for harness launch, first advert, and radio propagation).
            val deadline = System.currentTimeMillis() + 45_000L
            while (System.currentTimeMillis() < deadline) {
                val haveBoth = synchronized(detailedBeacons) { detailedBeacons.isNotEmpty() } &&
                    synchronized(detailedDirects) { detailedDirects.isNotEmpty() }
                if (haveBoth) break
                Thread.sleep(500L)
            }

            // Allow a little extra settle time for any trailing packets / log lines
            Thread.sleep(2_000L)
        } finally {
            try {
                leScanner.stopScan(callback)
            } catch (_: SecurityException) {
                // Permission edge during shutdown — harmless
            }
            bleScanner.stop()
        }

        val beacons = synchronized(detailedBeacons) { detailedBeacons.toList() }
        val directs = synchronized(detailedDirects) { detailedDirects.toList() }
        val productionBeacons = synchronized(fetchHook.legacyBeacons) { fetchHook.legacyBeacons.toList() }
        val hookFetchAdverts = synchronized(fetchHook.fetchAdverts) { fetchHook.fetchAdverts.toList() }
        val totalFetchSvcSightings = fetchSvcCount.get() + hookFetchAdverts.size

        Log.i(
            "IOSHybridDirectMxReceiveTest",
            "Evidence bundle: MB_cues=${beacons.size + productionBeacons.size} " +
                "direct_MX_envelopes=${directs.size} fetch_svc_sightings=$totalFetchSvcSightings " +
                "production_sink_events=${sink.events.size}"
        )

        // === Core asserts (the contract of the hybrid direct-MX receive path) ===

        assertTrue(
            "MB legacy cue (22-byte manufacturer data beacon) must have been received and recognized " +
                "as a ReceivedMessageBeacon (via MeshxMessageAdvertisement.decodeScanRecord)",
            beacons.isNotEmpty() || productionBeacons.isNotEmpty()
        )

        assertTrue(
            "Direct-MX service-data advertisement on MESHX_DIRECT_MX_SERVICE_UUID must have been " +
                "observed and its payload successfully parsed as a full v1 MeshxMessageEnvelope " +
                "(via MeshxMessageEnvelope.parse on the raw service data bytes)",
            directs.isNotEmpty()
        )

        // Correlation using proper 8-byte hashes (never a string prefix of the 16-byte ID).
        // This guards against the exact historical bugs: off-by-MX-header extraction and
        // "hash hex looks like it matches messageId prefix" false assumptions.
        val allBeaconsForMatch = beacons + productionBeacons
        var correlationMatch = false
        for (env in directs) {
            val envMsgHash = sha256(env.messageId).copyOfRange(0, 8)
            val envSenderHash = sha256(env.senderPeerId.toByteArray(Charsets.UTF_8)).copyOfRange(0, 8)
            for (b in allBeaconsForMatch) {
                if (b.messageIdHash.contentEquals(envMsgHash) ||
                    b.senderPeerIdHash.contentEquals(envSenderHash)
                ) {
                    correlationMatch = true
                    break
                }
            }
            if (correlationMatch) break
        }
        assertTrue(
            "Extracted messageId (via SHA-256 8-byte hash) or senderPeerId from the direct-MX " +
                "full envelope must correlate with (hash-match) at least one MB legacy cue. " +
                "This uses the same hash derivation as legacyBeaconPayload and ReceivedMessageBeacon.",
            correlationMatch
        )

        assertTrue(
            "Expected zero MeshxFetchGatt SERVICE_UUID (....2000) sightings during the direct-MX hybrid " +
                "receive window. Any sighting would indicate the legacy fetch path was exercised; " +
                "zero sightings proves pure service-data direct delivery with no GATT round-trip for the message.",
            totalFetchSvcSightings == 0
        )

        // Final high-signal line for operators grepping the test run
        Log.i(
            "IOSHybridDirectMxReceiveTest",
            "HYBRID_SUCCESS (test) — MB cue + direct MX service data with parseable full envelope " +
                "both observed on Android with hash correlation and zero fetch activity. " +
                "iOS→Android hybrid direct-MX path validated."
        )
    }

    private fun sha256(bytes: ByteArray): ByteArray =
        java.security.MessageDigest.getInstance("SHA-256").digest(bytes)
}