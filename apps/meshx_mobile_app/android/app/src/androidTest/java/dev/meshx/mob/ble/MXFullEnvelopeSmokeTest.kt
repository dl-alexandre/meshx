package dev.meshx.mob.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Hardware integration test for `MeshxBleNative.sendFullMxEnvelope/2` —
 * the dev-mode opt-in path that emits a full MX envelope (via GATT fetch
 * responder + MB legacy beacon cue) for cross-platform validation builds.
 *
 * The default `MeshxBleNative.sendToPeer/2` remains MB-only because
 * extended advertising is not universally receivable across the fleet.
 * This test exercises the deliberate full-MX path and asserts the
 * Android responder observed a successful end-to-end GATT round-trip
 * with the iOS requester (the iPad's `MeshxFetchGattClient`).
 *
 * Drive from the host with:
 *
 *     adb -s <android-udid> shell am instrument -w \
 *       -e class dev.meshx.mob.ble.MXFullEnvelopeSmokeTest \
 *       dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * Success criteria (asserted by polling the responder's counters):
 *   - `preparedOkCount() >= 1` — the iOS client wrote a valid MFQ
 *     Request matching the served envelope's `messageIdHash`.
 *   - `servedReadCount() >= 1` — the iOS client read back the response
 *     bytes after the OK was prepared.
 *
 * Polls every 500ms with a 30s deadline; exits as soon as both
 * counters tick over.
 */
@RunWith(AndroidJUnit4::class)
class MXFullEnvelopeSmokeTest {

    @get:Rule
    val permissions: GrantPermissionRule = GrantPermissionRule.grant(
        android.Manifest.permission.BLUETOOTH_ADVERTISE,
        android.Manifest.permission.BLUETOOTH_CONNECT,
        android.Manifest.permission.BLUETOOTH_SCAN
    )

    @Test
    fun sendFullMxEnvelopeIsServedToRemotePeer() {
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = manager.adapter

        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        assertTrue("Bluetooth must be enabled", adapter!!.isEnabled)

        // MeshxBleNative.init is the production entry point — exercising
        // it via the same lifecycle the real app uses keeps the test
        // honest about the surface under test.
        MeshxBleNative.init(context)

        try {
            val payload = "mx-full-envelope-smoke-001".toByteArray(Charsets.UTF_8)
            val accepted = MeshxBleNative.sendFullMxEnvelope("meshx-android-smoke", payload)
            assertTrue("sendFullMxEnvelope must accept", accepted)

            val responder = MeshxBleNative.activeResponder()
            assertNotNull(
                "sendFullMxEnvelope must leave a MeshxFetchGatt responder running",
                responder
            )
            requireNotNull(responder)

            val deadline = System.currentTimeMillis() + 30_000L
            while (System.currentTimeMillis() < deadline) {
                if (responder.preparedOkCount() > 0 && responder.servedReadCount() > 0) break
                Thread.sleep(500L)
            }

            val prepared = responder.preparedOkCount()
            val served = responder.servedReadCount()
            assertTrue(
                "Expected ≥1 STATUS_OK MFQ Request (got $prepared) — no iOS client " +
                    "paired the MB beacon with the connectable fetch-service advert. " +
                    "Likely cause: iOS MessageAdvertisementObserver did not start a fetch " +
                    "when it observed the fetch service UUID.",
                prepared >= 1
            )
            assertTrue(
                "Expected ≥1 response-characteristic read (got $served) — the iOS client " +
                    "wrote the request but did not read back the response. Likely cause: " +
                    "GATT disconnect between write and read, or characteristic discovery " +
                    "dropped the response characteristic.",
                served >= 1
            )
        } finally {
            MeshxBleNative.stopFullMxResponder()
        }
    }
}
