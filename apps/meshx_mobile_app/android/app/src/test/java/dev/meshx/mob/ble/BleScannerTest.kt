package dev.meshx.mob.ble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BleScannerTest {

    private fun envelope(): ByteArray = MeshxMessageEnvelope.buildV1(
        messageId = ByteArray(16) { it.toByte() },
        senderPeerId = "meshx-alpha",
        recipientPeerId = "meshx-beta",
        createdAtMs = 1_700_000_000_000L,
        ttl = 1,
        payloadType = "TX",
        payload = "hi".toByteArray()
    )

    private fun scanRecord(payload: ByteArray): ByteArray {
        val manufacturerLength = payload.size + 3
        return byteArrayOf(
            2,
            0x01,
            0x06,
            manufacturerLength.toByte(),
            0xFF.toByte(),
            0xFF.toByte(),
            0xFF.toByte()
        ) + payload
    }

    @Test fun `message advertisement scan result emits canonical ReceivedMessage`() {
        val sink = InMemoryEventSink()
        val scanner = BleScanner(adapter = null, sink = sink)
        val envelope = envelope()

        scanner.handleScanFields(
            deviceId = "AA:BB:CC:DD:EE:01",
            rssi = -61,
            advertisement = scanRecord(envelope),
            observedAtMs = 12_345L
        )

        assertEquals(1, sink.events.size)
        val event = sink.events.single()
        assertTrue(event is BleEvent.ReceivedMessage)

        val received = event as BleEvent.ReceivedMessage
        assertEquals(ByteArray(16) { it.toByte() }.toList(), received.messageId.toList())
        assertEquals("meshx-alpha", received.senderPeerId)
        assertEquals("meshx-beta", received.recipientPeerId)
        assertEquals("AA:BB:CC:DD:EE:01", received.receivedDeviceId)
        assertEquals("device_discovered", received.rawTransportMetadata.sourceEvent)
        assertEquals(envelope.toList(), received.envelope.toList())
    }

    @Test fun `ordinary advertisements keep sighting classification`() {
        val sink = InMemoryEventSink()
        val scanner = BleScanner(adapter = null, sink = sink)
        val advertisement = byteArrayOf(2, 0x01, 0x06)

        scanner.handleScanFields("AA:BB", -70, advertisement, 1L)
        scanner.handleScanFields("AA:BB", -71, advertisement, 2L)

        assertTrue(sink.events[0] is BleEvent.DeviceDiscovered)
        assertTrue(sink.events[1] is BleEvent.AdvertisementReceived)
    }

    @Test fun `malformed tagged message advertisement emits decode error`() {
        val sink = InMemoryEventSink()
        val scanner = BleScanner(adapter = null, sink = sink)
        val badPayload = byteArrayOf('M'.code.toByte(), 'X'.code.toByte(), 1, 0, 1, 2, 3)

        scanner.handleScanFields("AA:BB", -70, scanRecord(badPayload), 1L)

        assertEquals(1, sink.events.size)
        val event = sink.events.single()
        assertTrue(event is BleEvent.Error)
        assertTrue((event as BleEvent.Error).detail.contains("message_advertisement_decode_error"))
    }
}
