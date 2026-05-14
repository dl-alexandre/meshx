package dev.meshx.mob

import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ActivityCompat
import dev.meshx.mob.ble.BleBridge
import dev.meshx.mob.ble.BleAdvertGossipDispatcher
import dev.meshx.mob.ble.BleDispatcher
import dev.meshx.mob.ble.BleEvent
import dev.meshx.mob.ble.BleEventSink
import dev.meshx.mob.ble.BlePermissions
import dev.meshx.mob.ble.LogcatEventSink
import dev.meshx.mob.ble.MeshxFetchGatt
import dev.meshx.mob.ble.MeshxFetchProtocol
import dev.meshx.mob.ble.MeshxMessageEnvelope
import dev.meshx.mob.ble.PlainGattInteropHarness
import dev.meshx.mob.ble.RealBleBridge
import java.util.Base64

/**
 * Bring-up Activity. Wires two buttons (Scan / Advertise) to the BLE
 * transport so events can be observed in `adb logcat -s MeshxBle` and
 * (compactly) on-screen.
 *
 * The real BEAM-on-Android wiring lands in a later PR; until then this
 * Activity is the manual harness that proves Kotlin emits v1 wire-format
 * events on real hardware.
 */
class MainActivity : Activity() {

    private lateinit var status: TextView
    private lateinit var bridge: BleBridge
    private var fetchGatt: MeshxFetchGatt? = null
    private var interopGatt: PlainGattInteropHarness? = null
    private val handler = Handler(Looper.getMainLooper())

    private val onScreenSink = BleEventSink { event ->
        runOnUiThread {
            status.append("\n" + event.toJsonObject().toString())
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        status = TextView(this).apply {
            text = "MeshxMobileApp — Android shell"
            gravity = Gravity.START
        }

        val scanBtn = Button(this).apply {
            text = "Start scan"
            setOnClickListener { startScanWithControlLog() }
        }
        val stopScanBtn = Button(this).apply {
            text = "Stop scan"
            setOnClickListener { bridge.stopScan() }
        }
        val advBtn = Button(this).apply {
            text = "Start advertising"
            setOnClickListener { bridge.startAdvertising("meshx-mob") }
        }
        val stopAdvBtn = Button(this).apply {
            text = "Stop advertising"
            setOnClickListener { bridge.stopAdvertising() }
        }

        // Feed a hardcoded M14 envelope attempt into the BleDispatcher
        // path and surface the result on screen.
        // Stand-in for the future Elixir → NIF → Kotlin call.
        val dispatchTestBtn = Button(this).apply {
            text = "Dispatch test attempt"
            setOnClickListener { dispatchTestAttempt() }
        }
        val gossipTestBtn = Button(this).apply {
            text = "Gossip legacy beacon"
            setOnClickListener { gossipLegacyBeaconTest() }
        }
        val interopAdvertiseBtn = Button(this).apply {
            text = "Start GATT interop advertise"
            setOnClickListener { startInteropAdvertise() }
        }
        val interopConnectBtn = Button(this).apply {
            text = "Connect GATT interop"
            setOnClickListener { startInteropConnect() }
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(scanBtn)
            addView(stopScanBtn)
            addView(advBtn)
            addView(stopAdvBtn)
            addView(dispatchTestBtn)
            addView(gossipTestBtn)
            addView(interopAdvertiseBtn)
            addView(interopConnectBtn)
            addView(status)
        }
        setContentView(root)

        val combined = BleEventSink { event ->
            LogcatEventSink().accept(event)
            onScreenSink.accept(event)
        }
        bridge = RealBleBridge(this, combined)
        fetchGatt = MeshxFetchGatt(
            this,
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        )
        interopGatt = PlainGattInteropHarness(
            this,
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        )

        BlePermissions.firstMissing(this)?.let {
            ActivityCompat.requestPermissions(this, BlePermissions.required(), REQ_PERMS)
        }

        if (intent.getBooleanExtra(EXTRA_DISPATCH_TEST, false)) {
            dispatchTestAttempt(
                extendedConnectable = intent.getBooleanExtra(EXTRA_DISPATCH_CONNECTABLE, false),
                forceLegacyBeacon = intent.getBooleanExtra(EXTRA_DISPATCH_LEGACY_BEACON, false)
            )
        }
        if (intent.getBooleanExtra(EXTRA_GOSSIP_LEGACY_BEACON_TEST, false)) {
            gossipLegacyBeaconTest()
        }
        if (intent.getBooleanExtra(EXTRA_START_SCAN, false)) {
            startScanWithControlLog()
        }
        if (intent.getBooleanExtra(EXTRA_START_ADVERTISE, false)) {
            startAdvertiseWithControlLog(
                intent.getStringExtra(EXTRA_ADVERTISE_NAME) ?: "meshx-mob"
            )
        }
        if (intent.getBooleanExtra(EXTRA_FETCH_SERVER, false)) {
            startFetchServer()
        }
        if (intent.getBooleanExtra(EXTRA_FETCH_CLIENT, false)) {
            startFetchClient()
        }
        if (intent.getBooleanExtra(EXTRA_INTEROP_ADVERTISE, false)) {
            startInteropAdvertise()
        }
        if (intent.getBooleanExtra(EXTRA_INTEROP_CONNECT, false)) {
            startInteropConnect()
        }
    }

    override fun onDestroy() {
        bridge.stopScan()
        bridge.stopAdvertising()
        fetchGatt?.stopClient()
        fetchGatt?.stopResponder()
        interopGatt?.closeClient()
        interopGatt?.stopAdvertise()
        super.onDestroy()
    }

    companion object {
        private const val REQ_PERMS = 1001
        private const val CONTROL_LOGCAT_TAG = "MeshxBleControl"
        const val EXTRA_DISPATCH_TEST = "meshx_dispatch_test"
        const val EXTRA_DISPATCH_CONNECTABLE = "meshx_dispatch_connectable"
        const val EXTRA_DISPATCH_LEGACY_BEACON = "meshx_dispatch_legacy_beacon"
        const val EXTRA_GOSSIP_LEGACY_BEACON_TEST = "meshx_gossip_legacy_beacon_test"
        const val EXTRA_START_SCAN = "meshx_start_scan"
        const val EXTRA_START_ADVERTISE = "meshx_start_advertise"
        const val EXTRA_ADVERTISE_NAME = "meshx_advertise_name"
        const val EXTRA_FETCH_SERVER = "meshx_fetch_server"
        const val EXTRA_FETCH_CLIENT = "meshx_fetch_client"
        const val EXTRA_FETCH_DEVICE_ID = "meshx_fetch_device_id"
        const val EXTRA_FETCH_REQUEST_ID = "meshx_fetch_request_id"
        const val EXTRA_FETCH_MESSAGE_HASH = "meshx_fetch_message_id_hash"
        const val EXTRA_FETCH_VALIDATION_RETRIES = "meshx_fetch_validation_retries"
        const val EXTRA_INTEROP_ADVERTISE = "meshx_interop_advertise"
        const val EXTRA_INTEROP_CONNECT = "meshx_interop_connect"
        const val EXTRA_INTEROP_DEVICE_ID = "meshx_interop_device_id"
    }

    private fun startScanWithControlLog(): Boolean {
        val accepted = bridge.startScan()
        Log.i(
            CONTROL_LOGCAT_TAG,
            """{"v":1,"event":"scan_start_result","accepted":$accepted}"""
        )
        return accepted
    }

    private fun startAdvertiseWithControlLog(localName: String): Boolean {
        val accepted = bridge.startAdvertising(localName)
        Log.i(
            CONTROL_LOGCAT_TAG,
            """{"v":1,"event":"advertise_start_result","accepted":$accepted,"local_name":"$localName"}"""
        )
        return accepted
    }

    private fun dispatchTestAttempt(
        extendedConnectable: Boolean = false,
        forceLegacyBeacon: Boolean = false
    ) {
        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE)
            as? BluetoothManager)?.adapter
        val dispatcher = BleDispatcher(adapter, onScreenSink)
        val messageId = ByteArray(16) { it.toByte() }
        val envelope = MeshxMessageEnvelope.buildV1(
            messageId = messageId,
            senderPeerId = "meshx-alpha",
            recipientPeerId = "meshx-beta",
            createdAtMs = 1_700_000_000_000L,
            ttl = 1,
            payloadType = "TX",
            payload = "hi".toByteArray()
        )
        val result = dispatcher.dispatch(
            attemptId = "spike-att-0",
            messageId = messageId,
            targetPeerId = "meshx-beta",
            targetDeviceIds = listOf("AA:BB:CC:DD:EE:FF"),
            payload = envelope,
            extendedConnectable = extendedConnectable,
            forceLegacyBeacon = forceLegacyBeacon
        )
        runOnUiThread {
            status.append("\n[dispatch] kind=${result.kind} reason=${result.reason}")
        }
    }

    private fun gossipLegacyBeaconTest() {
        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE)
            as? BluetoothManager)?.adapter
        val dispatcher = BleAdvertGossipDispatcher(adapter, onScreenSink)
        val beacon = BleDispatcher.legacyBeaconPayload(
            MeshxMessageEnvelope.parse(fixtureEnvelope())
                .let { parsed ->
                    require(parsed is MeshxMessageEnvelope.ParseResult.Ok)
                    parsed.envelope
                }
        )
        val result = dispatcher.dispatchLegacyBeacon(
            gossipIntentId = "gossip-spike-0",
            messageIdHash = beacon.copyOfRange(6, 14),
            senderPeerIdHash = beacon.copyOfRange(14, 22),
            payloadKind = "TX",
            envelopeVersion = MeshxMessageEnvelope.CURRENT_VERSION
        )
        runOnUiThread {
            status.append("\n[gossip] kind=${result.kind} reason=${result.reason}")
        }
    }

    private fun startFetchServer() {
        val accepted = fetchGatt?.startResponder(
            envelope = fixtureEnvelope(),
            responderPeerId = "meshx-alpha"
        ) == true
        runOnUiThread {
            status.append("\n[fetch-server] accepted=$accepted")
        }
    }

    private fun startFetchClient() {
        bridge.stopScan()
        bridge.stopAdvertising()
        fetchGatt?.stopResponder()
        val deviceId = intent.getStringExtra(EXTRA_FETCH_DEVICE_ID)
        if (deviceId.isNullOrBlank()) {
            runOnUiThread { status.append("\n[fetch-client] missing target device") }
            return
        }

        val messageHash = intent.getStringExtra(EXTRA_FETCH_MESSAGE_HASH)
            ?.let { Base64.getDecoder().decode(it) }
            ?: MeshxFetchGatt.messageIdHash(ByteArray(16) { it.toByte() })
        val request = MeshxFetchProtocol.Request(
            requestId = intent.getStringExtra(EXTRA_FETCH_REQUEST_ID) ?: "fetch-android-1",
            messageIdHash = messageHash,
            requesterPeerId = "meshx-beta"
        )
        val accepted = fetchGatt?.fetchOnce(deviceId, request) == true
        runOnUiThread {
            status.append("\n[fetch-client] accepted=$accepted target=$deviceId")
        }
        if (!accepted) scheduleFetchValidationRetry(deviceId)
    }

    private fun scheduleFetchValidationRetry(deviceId: String) {
        val remaining = intent.getIntExtra(EXTRA_FETCH_VALIDATION_RETRIES, 0)
        if (remaining <= 0) return
        intent.putExtra(EXTRA_FETCH_VALIDATION_RETRIES, remaining - 1)
        handler.postDelayed({
            runOnUiThread {
                status.append("\n[fetch-client] validation retry remaining=${remaining - 1} target=$deviceId")
            }
            startFetchClient()
        }, 1_500L)
    }

    private fun startInteropAdvertise() {
        bridge.stopScan()
        bridge.stopAdvertising()
        fetchGatt?.stopClient()
        fetchGatt?.stopResponder()
        interopGatt?.closeClient()
        val accepted = interopGatt?.startAdvertise() == true
        runOnUiThread {
            status.append("\n[interop-advertise] accepted=$accepted")
        }
    }

    private fun startInteropConnect() {
        bridge.stopScan()
        bridge.stopAdvertising()
        fetchGatt?.stopClient()
        fetchGatt?.stopResponder()
        interopGatt?.stopAdvertise()
        val deviceId = intent.getStringExtra(EXTRA_INTEROP_DEVICE_ID)
        if (deviceId.isNullOrBlank()) {
            runOnUiThread { status.append("\n[interop-connect] missing target device") }
            return
        }
        val accepted = interopGatt?.connect(deviceId) == true
        runOnUiThread {
            status.append("\n[interop-connect] accepted=$accepted target=$deviceId")
        }
    }

    private fun fixtureEnvelope(): ByteArray {
        return MeshxMessageEnvelope.buildV1(
            messageId = ByteArray(16) { it.toByte() },
            senderPeerId = "meshx-alpha",
            recipientPeerId = "meshx-beta",
            createdAtMs = 1_700_000_000_000L,
            ttl = 1,
            payloadType = "TX",
            payload = "hi".toByteArray()
        )
    }

    // Suppresses an unused-import-style warning on Kotlin compilers that
    // don't see BleEvent referenced anywhere in this file — the sink
    // lambda takes BleEvent positionally, but some static analyzers miss
    // that. Touching the type here keeps the import honest.
    @Suppress("unused")
    private val keep: Class<BleEvent> = BleEvent::class.java
}
