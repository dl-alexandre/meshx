package dev.meshx.mob.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.security.SecureRandom
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
 */
@RunWith(AndroidJUnit4::class)
class IOSAuxFullMxAdvertSmokeTest {

    @get:Rule
    val permissions: GrantPermissionRule = GrantPermissionRule.grant(
        android.Manifest.permission.BLUETOOTH_ADVERTISE,
        android.Manifest.permission.BLUETOOTH_CONNECT,
        android.Manifest.permission.BLUETOOTH_SCAN
    )

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
        val envelope = MeshxMessageEnvelope.buildV1(
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
}
