package dev.meshx.mob.ble

import android.bluetooth.BluetoothManager
import android.content.Context

/**
 * Facade composing scanner + advertiser behind a single start/stop surface.
 *
 * Counterpart to `MeshxMobileApp.BLE.Adapter` on the Elixir side. The
 * Kotlin code never exposes Android-specific event variants; everything
 * the runtime sees is a v1 wire-format map fed into the sink.
 *
 * No mesh routing, no crypto, no reconnect orchestration — this is the
 * transport layer.
 */
interface BleBridge {
    fun startScan(): Boolean
    fun stopScan()
    fun startAdvertising(localName: String): Boolean
    fun stopAdvertising()
}

class RealBleBridge(
    context: Context,
    private val sink: BleEventSink
) : BleBridge {

    private val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
        ?.adapter

    private val scanner = BleScanner(adapter, sink)
    private val advertiser = BleAdvertiser(adapter, sink)

    override fun startScan(): Boolean {
        if (adapter?.isEnabled != true) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.BLUETOOTH_OFF,
                    detail = "bluetooth adapter disabled or absent"
                )
            )
            return false
        }
        return scanner.start()
    }

    override fun stopScan() = scanner.stop()

    override fun startAdvertising(localName: String): Boolean {
        if (adapter?.isEnabled != true) {
            sink.accept(
                BleEvent.Error(
                    kind = BleEvent.Companion.ErrorKind.BLUETOOTH_OFF,
                    detail = "bluetooth adapter disabled or absent"
                )
            )
            return false
        }
        return advertiser.start(localName)
    }

    override fun stopAdvertising() = advertiser.stop()
}
