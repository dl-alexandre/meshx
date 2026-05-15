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
 *
 * Error policy: every failure path on this surface surfaces a canonical
 * `BleEvent.Error` through the sink so the BEAM sees
 * `%MeshxMobileApp.BLE.Events.Error{kind, detail}` instead of having the
 * exception swallowed by the Kotlin try/catch. The boolean return value
 * remains the synchronous accept/reject signal for the NIF caller.
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

    private fun emitBridgeError(kind: String, detail: String) {
        Log.w(TAG, "bridge error $kind: $detail")
        try {
            sink.accept(BleEvent.Error(kind = kind, detail = detail))
        } catch (t: Throwable) {
            // Never let the error surface throw — if even the error pipe
            // is broken, log and continue rather than escalate.
            Log.e(TAG, "emitBridgeError failed: $kind", t)
        }
    }

    private fun contextOrNull(): Context? {
        val ctx = appContext
        if (ctx == null) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "MeshxBleNative.init(context) was not called before a BLE command"
            )
        }
        return ctx
    }

    @Synchronized
    private fun ensureBridgeOrNull(): RealBleBridge? {
        bridge?.let { return it }
        val ctx = contextOrNull() ?: return null
        return try {
            RealBleBridge(ctx, sink).also { bridge = it }
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "RealBleBridge construction failed: ${t.message ?: t.javaClass.simpleName}"
            )
            null
        }
    }

    @Synchronized
    private fun ensureDispatcherOrNull(): BleDispatcher? {
        dispatcher?.let { return it }
        val ctx = contextOrNull() ?: return null
        return try {
            val adapter = (ctx.getSystemService(Context.BLUETOOTH_SERVICE)
                as? BluetoothManager)?.adapter
            if (adapter == null) {
                emitBridgeError(
                    BleEvent.Companion.ErrorKind.BLUETOOTH_OFF,
                    "BluetoothManager.adapter is null (BT unsupported or BluetoothManager service unavailable)"
                )
                return null
            }
            BleDispatcher(adapter, sink).also { dispatcher = it }
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "BleDispatcher construction failed: ${t.message ?: t.javaClass.simpleName}"
            )
            null
        }
    }

    // The MeshX peer id this device advertises under — derived from the
    // MOB_NODE_SUFFIX the launcher set, matching the local name fed to
    // start_advertising. Used as the envelope sender_peer_id.
    private fun localName(): String =
        "meshx-" + (System.getenv("MOB_NODE_SUFFIX")?.takeIf { it.isNotBlank() } ?: "dev")

    // ── NIF → Kotlin commands. Return true = accepted, false = rejected. ──────

    @JvmStatic
    fun startScan(): Boolean {
        val b = ensureBridgeOrNull() ?: return false
        return try {
            b.startScan()
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.SCAN_FAILED,
                "startScan threw: ${t.message ?: t.javaClass.simpleName}"
            )
            false
        }
    }

    @JvmStatic
    fun startAdvertising(localName: String): Boolean {
        if (localName.isBlank()) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.ADVERTISE_FAILED,
                "startAdvertising rejected: localName is blank"
            )
            return false
        }
        val b = ensureBridgeOrNull() ?: return false
        return try {
            b.startAdvertising(localName)
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.ADVERTISE_FAILED,
                "startAdvertising threw: ${t.message ?: t.javaClass.simpleName}"
            )
            false
        }
    }

    @JvmStatic
    fun stop(): Boolean {
        return try {
            bridge?.let {
                it.stopScan()
                it.stopAdvertising()
            }
            true
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "stop threw: ${t.message ?: t.javaClass.simpleName}"
            )
            false
        }
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
    fun sendToPeer(peerId: String, payload: ByteArray): Boolean {
        val disp = ensureDispatcherOrNull() ?: return false
        val target = peerId.ifBlank { "broadcast" }

        val envelope = try {
            val messageId = ByteArray(16).also { random.nextBytes(it) }
            MeshxMessageEnvelope.buildV1(
                messageId = messageId,
                senderPeerId = localName(),
                recipientPeerId = null,
                createdAtMs = System.currentTimeMillis(),
                ttl = 1,
                payloadType = "TX",
                payload = payload
            ) to messageId
        } catch (e: IllegalArgumentException) {
            // buildV1's require() preconditions: peer-id / payload-type
            // size limits, ttl range, payload size limit. Surface them
            // as a structured rejection rather than a silent false.
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "envelope build rejected: ${e.message ?: "invalid argument"}"
            )
            return false
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "envelope build threw: ${t.message ?: t.javaClass.simpleName}"
            )
            return false
        }

        val (envelopeBytes, messageId) = envelope

        return try {
            val result = disp.dispatch(
                attemptId = "selftest-${System.currentTimeMillis()}",
                messageId = messageId,
                targetPeerId = target,
                targetDeviceIds = listOf(target),
                payload = envelopeBytes,
                forceLegacyBeacon = true
            )
            Log.i(TAG, "sendToPeer($target, ${payload.size}B) -> ${result.kind} reason=${result.reason}")
            result.kind == BleDispatcher.BleDispatchResult.Kind.DISPATCHED
        } catch (t: Throwable) {
            emitBridgeError(
                BleEvent.Companion.ErrorKind.UNKNOWN,
                "dispatch threw: ${t.message ?: t.javaClass.simpleName}"
            )
            false
        }
    }
}
