package dev.meshx.mob.ble

import android.os.SystemClock

/**
 * Hardware-free `BleBridge` for tests and offline bring-up.
 *
 * `emitDiscovery` / `emitAdvertisement` / `emitError` let a test drive
 * the same sink the real bridge feeds, so assertions about wire-map
 * shape don't require a phone. The `running*` flags exist purely for
 * lifecycle assertions in unit tests.
 */
class FakeBleBridge(private val sink: BleEventSink) : BleBridge {

    @Volatile var runningScan: Boolean = false
        private set

    @Volatile var runningAdvertise: Boolean = false
        private set

    var lastLocalName: String? = null
        private set

    override fun startScan(): Boolean {
        runningScan = true
        return true
    }

    override fun stopScan() {
        runningScan = false
    }

    override fun startAdvertising(localName: String): Boolean {
        runningAdvertise = true
        lastLocalName = localName
        return true
    }

    override fun stopAdvertising() {
        runningAdvertise = false
    }

    fun emitDiscovery(deviceId: String, rssi: Int = -55, advertisement: ByteArray = ByteArray(0)) {
        sink.accept(
            BleEvent.DeviceDiscovered(
                deviceId = deviceId,
                rssi = rssi,
                advertisement = advertisement,
                observedAtMs = SystemClock.elapsedRealtime()
            )
        )
    }

    fun emitAdvertisement(deviceId: String, rssi: Int = -60, advertisement: ByteArray = ByteArray(0)) {
        sink.accept(
            BleEvent.AdvertisementReceived(
                deviceId = deviceId,
                rssi = rssi,
                advertisement = advertisement,
                observedAtMs = SystemClock.elapsedRealtime()
            )
        )
    }

    fun emitError(kind: String, detail: String, deviceId: String? = null) {
        sink.accept(BleEvent.Error(kind = kind, detail = detail, deviceId = deviceId))
    }
}
