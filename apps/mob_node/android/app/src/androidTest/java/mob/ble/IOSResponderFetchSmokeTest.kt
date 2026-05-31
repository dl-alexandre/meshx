package mob.ble

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Hardware integration test for the inverse full-envelope path:
 * an iOS harness publishes an MB legacy beacon and serves the matching
 * MX envelope through `MobFetchGattResponder`; Android scans the cue,
 * connects to the iOS fetch service, writes MFQ, and reads MFR.
 *
 * Before running, launch the iOS Mob.NodeHarness on the peer device
 * with `--mob-auto-beacon` so it continuously publishes responder
 * envelopes.
 *
 * Permission shim: the version-aware `permissions` rule (API 31+ vs. pre-31)
 * ensures GrantPermissionRule succeeds on SM-T390 (Android 9/API 28) using
 * the legacy BT + location perms. This resolves the previous blocker so the
 * test reaches BLE on the full fleet. T390 coverage for production MB+GATT
 * still uses the main-app selftest (see `docs/ble-lab-cheat-sheet.md`).
 */
@RunWith(AndroidJUnit4::class)
class IOSResponderFetchSmokeTest {

    private data class RecentBeacon(
        val beacon: BleEvent.ReceivedMessageBeacon,
        val observedAtMs: Long
    )

    private fun hashKey(bytes: ByteArray): String =
        bytes.joinToString(separator = "") { "%02x".format(it) }

    private fun hexToBytes(hex: String): ByteArray? {
        if (hex.length % 2 != 0) return null
        return try {
            ByteArray(hex.length / 2) { index ->
                hex.substring(index * 2, index * 2 + 2).toInt(16).toByte()
            }
        } catch (_: NumberFormatException) {
            null
        }
    }

    @get:Rule
    val permissions: GrantPermissionRule =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // API 31+ (Android 12+): the split runtime BT perms are required and grantable.
            GrantPermissionRule.grant(
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            // API 28 (SM-T390 / Android 9) and 29-30: legacy BT perms (capped in manifest)
            // + FINE_LOCATION (needed for scan results on pre-31). This shim lets the
            // instrumented tests reach BLE logic on the full minSdk=28 fleet.
            GrantPermissionRule.grant(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }

    @Test
    fun androidFetchesEnvelopeServedByIOSResponder() {
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        assertTrue("Bluetooth must be enabled", adapter!!.isEnabled)

        val scanner = adapter.bluetoothLeScanner
        assertNotNull("BluetoothLeScanner must be available", scanner)

        val recentBeaconsBySenderHash = ConcurrentHashMap<String, RecentBeacon>()
        val fetchStarted = AtomicBoolean(false)
        val fetcher = MobFetchGatt(context, adapter)

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val record = result.scanRecord ?: return
                val bytes = record.bytes ?: return

                when (val decoded = MobMessageAdvertisement.decodeScanRecord(
                    advertisement = bytes,
                    deviceId = result.device.address,
                    rssi = result.rssi,
                    observedAtMs = System.currentTimeMillis(),
                    sourceEvent = "ios_responder_fetch_smoke"
                )) {
                    is MobMessageAdvertisement.DecodeResult.ReceivedBeacon ->
                        recentBeaconsBySenderHash[hashKey(decoded.event.senderPeerIdHash)] = RecentBeacon(
                            beacon = decoded.event,
                            observedAtMs = System.currentTimeMillis()
                        )

                    else -> Unit
                }

                val advertisesFetchService =
                    record.serviceUuids?.contains(ParcelUuid(MobFetchGatt.SERVICE_UUID)) == true
                // Use only the local name carried in this advertisement.
                // BluetoothDevice.name is cached by Android and can point at
                // a previous iOS responder hash after CoreBluetooth restarts
                // advertising with a new `mx<message_hash>` name.
                val localName = record.deviceName
                val advertisedMessageHash = localName
                    ?.removePrefix("mx")
                    ?.takeIf { it.length == 16 }
                    ?.let(::hexToBytes)
                val senderHash = localName
                    ?.takeIf { it.startsWith("ios-harness-") && advertisedMessageHash == null }
                    ?.let { MobFetchGatt.messageIdHash(it.toByteArray(Charsets.UTF_8)) }
                val recentBeacon = senderHash?.let { recentBeaconsBySenderHash[hashKey(it)] }
                val beaconIsFresh = recentBeacon != null &&
                    System.currentTimeMillis() - recentBeacon.observedAtMs <= 15_000L
                val messageHash = advertisedMessageHash ?: recentBeacon?.beacon?.messageIdHash
                if (
                    advertisesFetchService &&
                    (advertisedMessageHash != null || beaconIsFresh) &&
                    messageHash != null &&
                    fetchStarted.compareAndSet(false, true)
                ) {
                    val request = MobFetchProtocol.Request(
                        requestId = UUID.randomUUID().toString(),
                        messageIdHash = messageHash,
                        requesterPeerId = "android-ios-responder-smoke"
                    )
                    fetcher.fetchOnce(result.device.address, request)
                }
            }
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner!!.startScan(null, settings, callback)

            val deadline = System.currentTimeMillis() + 45_000L
            while (System.currentTimeMillis() < deadline) {
                if (fetcher.lastClientTerminalEvent() == "complete") break
                Thread.sleep(500L)
            }

            assertTrue(
                "Expected Android to observe iOS MB beacon and start a fetch",
                fetchStarted.get()
            )
            assertEquals("complete", fetcher.lastClientTerminalEvent())
            assertEquals("complete", fetcher.lastClientReason())
            assertEquals("ok", fetcher.lastClientResponseStatus())

            val envelope = fetcher.lastClientEnvelope()
            assertNotNull("Expected iOS responder to return an MX envelope", envelope)
            val parsed = MobMessageEnvelope.parse(requireNotNull(envelope))
            assertTrue("Expected fetched envelope to parse, got $parsed", parsed is MobMessageEnvelope.ParseResult.Ok)
        } finally {
            scanner?.stopScan(callback)
            fetcher.stopClient()
        }
    }
}
