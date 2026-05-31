package mob.ble

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
 * RT-01 harness driver — NOT an assertion smoke test.
 *
 * Emits a full MX envelope via `MobBleNative.sendFullMxEnvelope` and holds the
 * GATT-fetch responder + MB legacy beacon up for a fixed window so a *locked*
 * receiver has time to fetch it. Uses only the PUBLIC `MobBleNative` surface
 * (no `activeResponder`/internal accessors), so it builds without widening the
 * published `mob_ble` API — that's the whole point of this driver vs.
 * `MXFullEnvelopeSmokeTest`, which asserts via the module-internal counters.
 *
 * `scripts/android/rt01-sustained.sh` invokes this once per burst across the
 * locked hold:
 *
 *     adb -s <udid> shell am instrument -w \
 *       -e class mob.ble.SustainedAdvertiseDriver \
 *       [-e hold_ms 28000] \
 *       dev.mob.mob.test/androidx.test.runner.AndroidJUnitRunner
 *
 * Each burst carries a timestamped payload so the analyzer sees distinct
 * messages (not one deduped id) across the window.
 */
@RunWith(AndroidJUnit4::class)
class SustainedAdvertiseDriver {

    @get:Rule
    val permissions: GrantPermissionRule =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            GrantPermissionRule.grant(
                android.Manifest.permission.BLUETOOTH_ADVERTISE,
                android.Manifest.permission.BLUETOOTH_CONNECT,
                android.Manifest.permission.BLUETOOTH_SCAN,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            )
        } else {
            GrantPermissionRule.grant(
                android.Manifest.permission.BLUETOOTH,
                android.Manifest.permission.BLUETOOTH_ADMIN,
                android.Manifest.permission.ACCESS_FINE_LOCATION
            )
        }

    @Test
    fun advertiseFullMxEnvelopeForWindow() {
        val context: Context = InstrumentationRegistry.getInstrumentation().targetContext
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        assertNotNull("BluetoothAdapter must be available on this device", adapter)
        assertTrue("Bluetooth must be enabled", adapter!!.isEnabled)

        MobBleNative.init(context)

        val holdMs =
            InstrumentationRegistry.getArguments().getString("hold_ms")?.toLongOrNull() ?: 28_000L
        val payload = ("rt01-sustained-" + System.currentTimeMillis()).toByteArray(Charsets.UTF_8)

        try {
            val accepted = MobBleNative.sendFullMxEnvelope("mob-android-sustained", payload)
            assertTrue("sendFullMxEnvelope must accept the envelope", accepted)
            // Keep the responder + beacon advertising so the locked receiver can
            // observe the cue and complete a GATT fetch within this window.
            Thread.sleep(holdMs)
        } finally {
            MobBleNative.stopFullMxResponder()
        }
    }
}
