package dev.meshx.mob.ble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FakeBleBridgeTest {

    @Test fun `lifecycle flags track start and stop`() {
        val sink = InMemoryEventSink()
        val bridge = FakeBleBridge(sink)

        assertFalse(bridge.runningScan)
        bridge.startScan()
        assertTrue(bridge.runningScan)
        bridge.stopScan()
        assertFalse(bridge.runningScan)

        bridge.startAdvertising("meshx-mob")
        assertTrue(bridge.runningAdvertise)
        assertEquals("meshx-mob", bridge.lastLocalName)
    }

    @Test fun `emit helpers feed the configured sink`() {
        val sink = InMemoryEventSink()
        val bridge = FakeBleBridge(sink)

        bridge.emitDiscovery("AA:BB:CC:DD:EE:01")
        bridge.emitAdvertisement("AA:BB:CC:DD:EE:01")
        bridge.emitError(
            BleEvent.Companion.ErrorKind.SCAN_FAILED,
            detail = "boom"
        )

        val events = sink.events
        assertEquals(3, events.size)
        assertTrue(events[0] is BleEvent.DeviceDiscovered)
        assertTrue(events[1] is BleEvent.AdvertisementReceived)
        assertTrue(events[2] is BleEvent.Error)
    }
}
