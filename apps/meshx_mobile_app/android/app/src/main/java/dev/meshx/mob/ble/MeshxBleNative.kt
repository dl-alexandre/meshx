package dev.meshx.mob.ble

import android.content.Context
import android.util.Log

/**
 * JNI bridge between the statically-linked `meshx_ble_nif` (c_src/meshx_ble_nif.c)
 * and the Kotlin BLE transport (`RealBleBridge`).
 *
 * Direction of calls:
 *
 *   NIF  → Kotlin : `startScan` / `startAdvertising` / `stop` / `sendToPeer`
 *                   (the NIF resolves these via GetStaticMethodID and
 *                   invokes them with CallStaticBooleanMethod).
 *   Kotlin → NIF  : `nativeDeliverEvent` — the BeamEventSink forwards each
 *                   `BleEvent` as its v1 wire-format JSON; the NIF wraps it
 *                   in `{MeshxMobileApp.NativeBridge, :bridge_event, json}`
 *                   and sends it to the owner pid.
 *
 * `init/1` must be called once (from MainActivity.onCreate) to supply an
 * application Context — `RealBleBridge` is created lazily on the first
 * command so a BLE-less host/unit context never touches the adapter.
 */
object MeshxBleNative {
    private const val TAG = "MeshxBleNative"

    @Volatile private var appContext: Context? = null
    @Volatile private var bridge: RealBleBridge? = null

    /** Kotlin → NIF. Implemented in c_src/meshx_ble_nif.c. */
    @JvmStatic
    private external fun nativeDeliverEvent(json: String)

    /** Called once from MainActivity.onCreate, before the BEAM starts. */
    fun init(context: Context) {
        appContext = context.applicationContext
        Log.i(TAG, "init: application context set")
    }

    @Synchronized
    private fun ensureBridge(): RealBleBridge {
        bridge?.let { return it }
        val ctx = appContext
            ?: error("MeshxBleNative.init(context) was not called before a BLE command")
        // Every BleEvent the scanner/advertiser emits is forwarded to the
        // BEAM as its canonical v1 wire JSON — the same shape the Elixir
        // BridgeProtocol decoder already understands.
        val sink = BleEventSink { event ->
            try {
                nativeDeliverEvent(event.toJsonObject().toString())
            } catch (t: Throwable) {
                Log.e(TAG, "nativeDeliverEvent failed", t)
            }
        }
        return RealBleBridge(ctx, sink).also { bridge = it }
    }

    // ── NIF → Kotlin commands. Return true = accepted, false = rejected. ──────

    @JvmStatic
    fun startScan(): Boolean = try {
        ensureBridge().startScan()
    } catch (t: Throwable) {
        Log.e(TAG, "startScan", t)
        false
    }

    @JvmStatic
    fun startAdvertising(localName: String): Boolean = try {
        ensureBridge().startAdvertising(localName)
    } catch (t: Throwable) {
        Log.e(TAG, "startAdvertising", t)
        false
    }

    @JvmStatic
    fun stop(): Boolean = try {
        bridge?.let {
            it.stopScan()
            it.stopAdvertising()
        }
        true
    } catch (t: Throwable) {
        Log.e(TAG, "stop", t)
        false
    }

    /**
     * The mobile-app BLE layer is advert-only — `BleBridge` exposes scan and
     * advertise, not a connection-oriented send. Directed sends are carried
     * by message-bearing advertisements (BleDispatcher / MeshxMessageEnvelope),
     * which the runtime drives separately. Accept the call so
     * `MeshxMobileApp.Session.send_ping/1` does not surface a bridge error;
     * actual directed delivery is wired in a follow-up.
     */
    @JvmStatic
    fun sendToPeer(peerId: String, payload: ByteArray): Boolean {
        Log.i(TAG, "sendToPeer($peerId, ${payload.size}B) — advert-only transport, no-op")
        return true
    }
}
