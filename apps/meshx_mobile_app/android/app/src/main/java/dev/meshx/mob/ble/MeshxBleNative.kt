package dev.meshx.mob.ble

import android.bluetooth.BluetoothManager
import android.content.Context
import android.util.Log
import java.security.SecureRandom

/**
 * JNI bridge between the statically-linked `meshx_ble_nif` (c_src/meshx_ble_nif.c)
 * and the Kotlin BLE transport (`RealBleBridge` + `BleDispatcher`).
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
 * application Context — `RealBleBridge` / `BleDispatcher` are created lazily
 * on first use so a BLE-less host/unit context never touches the adapter.
 */
object MeshxBleNative {
    private const val TAG = "MeshxBleNative"

    @Volatile private var appContext: Context? = null
    @Volatile private var bridge: RealBleBridge? = null
    @Volatile private var dispatcher: BleDispatcher? = null
    private val random = SecureRandom()

    /** Kotlin → NIF. Implemented in c_src/meshx_ble_nif.c. */
    @JvmStatic
    private external fun nativeDeliverEvent(json: String)

    /** Called once from MainActivity.onCreate, before the BEAM starts. */
    fun init(context: Context) {
        appContext = context.applicationContext
        Log.i(TAG, "init: application context set")
    }

    // Every BleEvent the scanner/advertiser/dispatcher emits is forwarded
    // to the BEAM as its canonical v1 wire JSON — the same shape the Elixir
    // BridgeProtocol decoder already understands.
    private val sink = BleEventSink { event ->
        try {
            nativeDeliverEvent(event.toJsonObject().toString())
        } catch (t: Throwable) {
            Log.e(TAG, "nativeDeliverEvent failed", t)
        }
    }

    private fun requireContext(): Context =
        appContext ?: error("MeshxBleNative.init(context) was not called before a BLE command")

    @Synchronized
    private fun ensureBridge(): RealBleBridge {
        bridge?.let { return it }
        return RealBleBridge(requireContext(), sink).also { bridge = it }
    }

    @Synchronized
    private fun ensureDispatcher(): BleDispatcher {
        dispatcher?.let { return it }
        val adapter = (requireContext().getSystemService(Context.BLUETOOTH_SERVICE)
            as? BluetoothManager)?.adapter
        return BleDispatcher(adapter, sink).also { dispatcher = it }
    }

    // The MeshX peer id this device advertises under — derived from the
    // MOB_NODE_SUFFIX the launcher set, matching the local name fed to
    // start_advertising. Used as the envelope sender_peer_id.
    private fun localName(): String =
        "meshx-" + (System.getenv("MOB_NODE_SUFFIX")?.takeIf { it.isNotBlank() } ?: "dev")

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
     * Real directed send: wrap `payload` in a v1 `MeshxMessageEnvelope`
     * (broadcast — `recipientPeerId = null`, so any MeshX scanner ingests
     * it) and dispatch it through `BleDispatcher` as a legacy beacon.
     *
     * `forceLegacyBeacon = true` is deliberate: the full envelope only
     * fits in BLE 5 extended advertising, which older peers (e.g. API 28
     * hardware) cannot *scan*. The 22-byte legacy beacon carries a MeshX
     * message reference (message-id + sender hashes) in a legacy
     * manufacturer-data advertisement every device can both send and
     * receive — so the exchange is symmetric across the fleet. Peers
     * decode it via `MeshxMessageAdvertisement.decodeScanRecord` into a
     * `received_message_beacon` event. Full-payload retrieval is a
     * separate GATT-fetch concern.
     */
    @JvmStatic
    fun sendToPeer(peerId: String, payload: ByteArray): Boolean = try {
        val messageId = ByteArray(16).also { random.nextBytes(it) }
        val envelope = MeshxMessageEnvelope.buildV1(
            messageId = messageId,
            senderPeerId = localName(),
            recipientPeerId = null,
            createdAtMs = System.currentTimeMillis(),
            ttl = 1,
            payloadType = "TX",
            payload = payload
        )
        val target = peerId.ifBlank { "broadcast" }
        val result = ensureDispatcher().dispatch(
            attemptId = "selftest-${System.currentTimeMillis()}",
            messageId = messageId,
            targetPeerId = target,
            targetDeviceIds = listOf(target),
            payload = envelope,
            forceLegacyBeacon = true
        )
        Log.i(TAG, "sendToPeer($target, ${payload.size}B) -> ${result.kind} reason=${result.reason}")
        result.kind == BleDispatcher.BleDispatchResult.Kind.DISPATCHED
    } catch (t: Throwable) {
        Log.e(TAG, "sendToPeer", t)
        false
    }
}
