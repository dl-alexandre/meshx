package dev.meshx.mob.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings

/**
 * Thin wrapper around `BluetoothLeAdvertiser`. Transport-only: starts
 * and stops broadcasting a local name. Failures surface as `Error`
 * events through the same sink the scanner uses.
 */
class BleAdvertiser(
    private val adapter: BluetoothAdapter?,
    private val sink: BleEventSink
) {

    @Volatile private var running = false

    private val callback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            running = false
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.ADVERTISE_FAILED,
                    detail = "advertise start failed (code=$errorCode)"
                )
            )
        }

        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            // Intentionally silent: lifecycle state is owned by the
            // Elixir runtime, not surfaced via events here.
        }
    }

    @SuppressLint("MissingPermission")
    fun start(localName: String): Boolean {
        if (running) return true
        val advertiser = adapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.PERIPHERAL_UNSUPPORTED,
                    detail = "no BluetoothLeAdvertiser (BT off or no peripheral support)"
                )
            )
            return false
        }

        // Setting the device name is what surfaces `localName` in scan
        // results. The advertising payload itself uses the include flag.
        // `adapter` was already null-checked via `?.bluetoothLeAdvertiser`
        // above; the `!!` is safe here and lets Kotlin's flow analysis
        // see the receiver as non-null.
        try {
            adapter!!.name = localName
        } catch (_: SecurityException) {
            // Setting name requires BLUETOOTH_CONNECT on API 31+. The
            // advertisement can still proceed without the rename.
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()

        try {
            advertiser.startAdvertising(settings, data, callback)
            running = true
            return true
        } catch (e: SecurityException) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.UNAUTHORIZED,
                    detail = e.message ?: "BLUETOOTH_ADVERTISE denied"
                )
            )
            return false
        }
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        if (!running) return
        running = false
        val advertiser = adapter?.bluetoothLeAdvertiser ?: return
        try {
            advertiser.stopAdvertising(callback)
        } catch (_: SecurityException) {
            // Already torn down from the platform's perspective.
        }
    }
}
