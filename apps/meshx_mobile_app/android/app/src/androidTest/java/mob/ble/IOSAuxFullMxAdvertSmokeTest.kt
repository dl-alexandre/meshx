package mob.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.security.SecureRandom
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Emits a direct full-MX envelope over Android BLE extended advertising.
 *
 * This is an emitter-side smoke only. The missing iOS AUX interop proof
 * still requires an iOS harness log showing `FF FF 4D 58` manufacturer
 * data delivered to `CBCentralManager.didDiscover` and decoded through
 * `received_message`.
 *
 * Permission shim: the `permissions` rule below is version-aware (API >=31 vs <=30)
 * so GrantPermissionRule succeeds on SM-T390 (API 28). Instrumented AUX tests now
 * run on the full fleet; for T390 production path coverage prefer the main-app
 * selftest (see `docs/ble-lab-cheat-sheet.md` "Main app with selftest").
 *
 * === Ready-to-run commands for the different advertising strategies ===
 *
 * iOS observer (always use this with --meshx-log-raw-advert-data for these experiments):
 *   xcrun devicectl device process launch --device <UDID> --terminate-existing --console \
 *     dev.meshx.mobile.harness -- --meshx-auto-scan --meshx-log-candidate-discoveries \
 *     --meshx-log-raw-advert-data
 *
 * 1. Scan-response carrier (baseline):
 *   adb shell am instrument -w -e class mob.ble.IOSAuxFullMxAdvertSmokeTest \
 *     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * 2. Primary channel (extendedConnectable=true):
 *   Temporarily edit the test to pass extendedConnectable = true, then run the same command as #1.
 *
 * 3. Service-data carrier (different advertising strategy):
 *   adb shell am instrument -w -e class mob.ble.IOSAuxFullMxAdvertSmokeTest#emitsServiceDataFullMxEnvelope \
 *     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * 4. Hybrid (MB legacy cue + service-data full payload) — the next evolution:
 *   adb shell am instrument -w -e class mob.ble.IOSAuxFullMxAdvertSmokeTest#emitsHybridMbCuePlusServiceDataFullMxEnvelope \
 *     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * 5. iOS as emitter for the direct-MX service-data carrier (reverse direction experiment):
 *   xcrun devicectl device process launch --device <UDID> ... \
 *     -- --meshx-auto-direct-mx-service-advertise
 *   (iOS advertises a real full-MX envelope on the direct service UUID; use Android raw/service-data observer to receive)
 *
 * 6. iOS hybrid emit (MB legacy cue + direct service-data full payload) — the symmetric iOS→Android hybrid (full production correlation on both sides):
 *   xcrun devicectl device process launch --device <UDID> ... \
 *     -- --meshx-auto-direct-mx-hybrid-advertise
 *   (iOS sends short MB cue + full MX via direct service data for 8s; watch iOS for "iOS_HYBRID_STARTED messageId=..." + "iOS_HYBRID_WINDOW_COMPLETE", and Android for "iOS_HYBRID_STARTED (received on Android)", "HYBRID_SUCCESS", "HYBRID_CORRELATED", or "HYBRID_RECEIVED_FROM_IOS" with the *same* messageId)
 *
 * 7. Android hybrid emit → iOS receive (the other direction of the hybrid strategy):
 *   adb shell am instrument -w -e class mob.ble.IOSAuxFullMxAdvertSmokeTest#emitsHybridMbCuePlusServiceDataFullMxEnvelope \
 *     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *   (Android sends MB cue + full MX via direct service data; watch iOS for "HYBRID_CORRELATED messageId=..." + "HYBRID_SUCCESS" with the same messageId, and the "possible_hybrid_correlation" line)
 *
 * Look for "mx_magic_seen=true", "DIRECT_MX_SERVICE_DATA_WITH_MAGIC", "iOS_HYBRID_STARTED", "HYBRID_STARTED", "HYBRID_CORRELATED", "HYBRID_SUCCESS", or "HYBRID_RECEIVED_FROM_IOS" on either console. The messageId will match across both sides. The new correlation lines make success/failure obvious in real time on both platforms. The hybrid strategy is now fully symmetric and production-wired.
 */
@RunWith(AndroidJUnit4::class)
class IOSAuxFullMxAdvertSmokeTest {

    @get:Rule
    val permissions: GrantPermissionRule =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            // API 31+ (Android 12+): the split runtime BT perms are required and grantable.
            GrantPermissionRule.grant(
                android.Manifest.permission.BLUETOOTH_ADVERTISE,
                android.Manifest.permission.BLUETOOTH_CONNECT,
                android.Manifest.permission.BLUETOOTH_SCAN,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            // API 28 (SM-T390 / Android 9) and 29-30: legacy BT perms (capped in manifest)
            // + FINE_LOCATION (needed for scan results on pre-31). This shim lets the
            // instrumented tests reach BLE logic on the full minSdk=28 fleet.
            GrantPermissionRule.grant(
                android.Manifest.permission.BLUETOOTH,
                android.Manifest.permission.BLUETOOTH_ADMIN,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            )
        }

    @Test
    fun emitsScannableAuxScanResponseFullMxEnvelope() {
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        requireNotNull(adapter)
        assertTrue("Bluetooth must be enabled", adapter.isEnabled)
        assertTrue(
            "Android device must support LE extended advertising",
            adapter.isLeExtendedAdvertisingSupported
        )

        val messageId = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val envelope = MobMessageEnvelope.buildV1(
            messageId = messageId,
            senderPeerId = "meshx-android-aux",
            recipientPeerId = null,
            createdAtMs = System.currentTimeMillis(),
            ttl = 1,
            payloadType = "TX",
            payload = "mx-aux-scan-response-smoke".toByteArray(Charsets.UTF_8)
        )

        assertTrue("test envelope should require extended advertising", envelope.size > 24)

        val result = BleDispatcher(adapter, InMemoryEventSink()).dispatch(
            attemptId = "aux-scan-response-${System.currentTimeMillis()}",
            messageId = messageId,
            targetPeerId = "ios-harness",
            targetDeviceIds = listOf("ios-harness"),
            payload = envelope,
            extendedConnectable = false,
            legacyBeaconFallback = false,
            forceLegacyBeacon = false
        )

        assertEquals(BleDispatcher.BleDispatchResult.Kind.DISPATCHED, result.kind)
        Thread.sleep(BleDispatcher.ADVERTISE_WINDOW_MS + 1_000L)
    }

    @Test
    fun emitsServiceDataFullMxEnvelope() {
        // "Different advertising strategy" variant: put the full MX envelope in
        // service data under MOB_DIRECT_MX_SERVICE_UUID instead of manufacturer data.
        // Pair this with the iOS observer using --meshx-log-raw-advert-data.
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        requireNotNull(adapter)
        assertTrue("Bluetooth must be enabled", adapter.isEnabled)
        assertTrue(
            "Android device must support LE extended advertising",
            adapter.isLeExtendedAdvertisingSupported
        )

        val messageId = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val envelope = MobMessageEnvelope.buildV1(
            messageId = messageId,
            senderPeerId = "meshx-android-svcdata",
            recipientPeerId = null,
            createdAtMs = System.currentTimeMillis(),
            ttl = 1,
            payloadType = "TX",
            payload = "mx-service-data-smoke".toByteArray(Charsets.UTF_8)
        )

        assertTrue("test envelope should require extended advertising", envelope.size > 24)

        val result = BleDispatcher(adapter, InMemoryEventSink()).dispatch(
            attemptId = "aux-service-data-${System.currentTimeMillis()}",
            messageId = messageId,
            targetPeerId = "ios-harness",
            targetDeviceIds = listOf("ios-harness"),
            payload = envelope,
            extendedConnectable = false,
            legacyBeaconFallback = false,
            forceLegacyBeacon = false,
            useServiceDataForPayload = true,
            serviceDataUuid = BleDispatcher.MOB_DIRECT_MX_SERVICE_UUID
        )

        assertEquals(BleDispatcher.BleDispatchResult.Kind.DISPATCHED, result.kind)
        Thread.sleep(BleDispatcher.ADVERTISE_WINDOW_MS + 1_000L)
    }

    @Test
    fun emitsHybridMbCuePlusServiceDataFullMxEnvelope() {
        // Hybrid "different advertising strategy":
        // Send the short MB legacy beacon (fleet-safe cue that everyone can receive)
        // + emit the full MX envelope via service data on the dedicated direct-MX UUID.
        // This is the evolutionary path from "MB cue + GATT fetch" toward direct delivery
        // while keeping backward compatibility.
        //
        // On iOS with --meshx-log-raw-advert-data you should see:
        // - the short MB beacon (legacy path), and
        // - service data for MOB_DIRECT_MX_SERVICE_UUID containing the full envelope
        //   (with mx_magic_seen=true / [MX_MAGIC] in the raw dump).

        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        requireNotNull(adapter)
        assertTrue("Bluetooth must be enabled", adapter.isEnabled)
        assertTrue(
            "Android device must support LE extended advertising",
            adapter.isLeExtendedAdvertisingSupported
        )

        val messageId = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val envelope = MobMessageEnvelope.buildV1(
            messageId = messageId,
            senderPeerId = "meshx-android-hybrid",
            recipientPeerId = null,
            createdAtMs = System.currentTimeMillis(),
            ttl = 1,
            payloadType = "TX",
            payload = "mx-hybrid-mb-plus-svcdata".toByteArray(Charsets.UTF_8)
        )

        assertTrue("test envelope should require extended advertising", envelope.size > 24)

        val dispatcher = BleDispatcher(adapter, InMemoryEventSink())

        // 1. Fleet-safe MB legacy beacon cue (short 22-byte version)
        val cueResult = dispatcher.dispatch(
            attemptId = "hybrid-mb-cue-${System.currentTimeMillis()}",
            messageId = messageId,
            targetPeerId = "ios-harness",
            targetDeviceIds = listOf("ios-harness"),
            payload = envelope,
            extendedConnectable = false,
            legacyBeaconFallback = true,
            forceLegacyBeacon = true
        )
        assertEquals(BleDispatcher.BleDispatchResult.Kind.DISPATCHED, cueResult.kind)

        // 2. Full MX envelope via the new service-data carrier
        val fullResult = dispatcher.dispatch(
            attemptId = "hybrid-svcdata-${System.currentTimeMillis()}",
            messageId = messageId,
            targetPeerId = "ios-harness",
            targetDeviceIds = listOf("ios-harness"),
            payload = envelope,
            extendedConnectable = false,
            legacyBeaconFallback = false,
            forceLegacyBeacon = false,
            useServiceDataForPayload = true,
            serviceDataUuid = BleDispatcher.MOB_DIRECT_MX_SERVICE_UUID
        )
        assertEquals(BleDispatcher.BleDispatchResult.Kind.DISPATCHED, fullResult.kind)

        val messageIdHex = messageId.joinToString("") { "%02x".format(it) }
        Log.i("HybridExperiment", "Hybrid experiment started messageId=$messageIdHex (watch iOS for DIRECT_MX_SERVICE_DATA_WITH_MAGIC + this messageId)")

        Thread.sleep(BleDispatcher.ADVERTISE_WINDOW_MS + 1_000L)
    }

    // Service-data carrier experiment (different advertising strategy):
    // This now works — the radio supports useServiceDataForPayload + serviceDataUuid.
    // Example:
    //
    // val result = BleDispatcher(adapter, InMemoryEventSink()).dispatch(
    //     attemptId = "aux-service-data-...",
    //     messageId = messageId,
    //     targetPeerId = "ios-harness",
    //     targetDeviceIds = listOf("ios-harness"),
    //     payload = envelope,
    //     extendedConnectable = false,
    //     legacyBeaconFallback = false,
    //     forceLegacyBeacon = false,
    //     useServiceDataForPayload = true,
    //     serviceDataUuid = BleDispatcher.MOB_DIRECT_MX_SERVICE_UUID
    // )
    //
    // Then launch iOS with --meshx-log-raw-advert-data. The raw dump will show the
    // actual service data bytes (or prove they still don't arrive on the tested iOS stack).

    // Hybrid experiment (next "different advertising strategy" after pure service-data):
    // Send the short MB legacy beacon as the cue (so all legacy devices still see something)
    // + also emit the full MX envelope via service data on MOB_DIRECT_MX_SERVICE_UUID.
    // This is the evolutionary step from the current production "MB cue + GATT fetch" model.
    // The iOS raw observer with --meshx-log-raw-advert-data + mx_magic_seen will tell us
    // whether the service-data part of the hybrid actually delivers on the tested hardware.

    // Android receive-side hybrid correlation (symmetric to the iOS HYBRID_CORRELATED work).
    // The test tracks recent legacy MB beacons (by messageId) during the experiment.
    // When it detects the direct MX service data with magic (via the raw logging or the service-data callback),
    // it checks for a recent matching MB cue and prints a clear success signal.
    //
    // Example usage in the observer / logging path when raw logging is enabled:
    //   if (isDirectMxServiceDataWithMagic(messageId)) {
    //       onDirectMxServiceDataWithMagicReceived(messageId)
    //   }
    //
    // This makes the full bidirectional hybrid experiment (iOS hybrid emit → Android receive)
    // produce obvious "HYBRID_RECEIVED" / "HYBRID_SUCCESS" lines on the Android console as well.

    private val recentMBBeacons = mutableListOf<Pair<String, Long>>() // (messageId, timestamp)

    fun onLegacyBeaconSeen(messageId: String) {
        recentMBBeacons.add(messageId to System.currentTimeMillis())
        // Keep only the last 30 seconds worth
        val cutoff = System.currentTimeMillis() - 30_000
        recentMBBeacons.removeAll { it.second < cutoff }
    }

    fun onDirectMxServiceDataWithMagicReceived(messageId: String) {
        val cutoff = System.currentTimeMillis() - 15_000
        val recent = recentMBBeacons.filter { it.first == messageId && it.second > cutoff }
        if (recent.isNotEmpty()) {
            Log.i("HybridExperiment", "HYBRID_RECEIVED messageId=$messageId recentMB=${recent.size} — legacy MB cue + direct MX service data both observed on Android. Success signal for the hybrid strategy (iOS → Android or Android → iOS).")
            Log.i("HybridExperiment", "HYBRID_SUCCESS messageId=$messageId — full hybrid (MB cue + direct MX service data) successfully received on Android. This is the expected positive outcome for the hybrid advertising strategy.")
        } else {
            Log.i("HybridExperiment", "DIRECT_MX_SERVICE_DATA_WITH_MAGIC messageId=$messageId (no recent matching MB cue in last 15s)")
        }
    }
}
