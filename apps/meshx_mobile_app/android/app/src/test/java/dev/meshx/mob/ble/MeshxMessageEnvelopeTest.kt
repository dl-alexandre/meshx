package dev.meshx.mob.ble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MeshxMessageEnvelopeTest {

    private fun envelope(
        messageId: ByteArray = ByteArray(16) { if (it == 15) 1 else 0 },
        payload: ByteArray = "hi".toByteArray()
    ): ByteArray = MeshxMessageEnvelope.buildV1(
        messageId = messageId,
        senderPeerId = "meshx-alpha",
        recipientPeerId = "meshx-beta",
        createdAtMs = 1_700_000_000_000L,
        ttl = 1,
        payloadType = "TX",
        payload = payload
    )

    @Test fun `buildV1 emits the documented M14 magic and validates`() {
        val bytes = envelope()

        assertEquals('M'.code.toByte(), bytes[0])
        assertEquals('X'.code.toByte(), bytes[1])
        assertEquals(MeshxMessageEnvelope.CURRENT_VERSION.toByte(), bytes[2])
        assertNull(MeshxMessageEnvelope.validate(bytes))
        assertEquals(60, bytes.size)
    }

    @Test fun `known fixture bytes match Elixir M14 encoding`() {
        val bytes = envelope()
        val b64 = java.util.Base64.getEncoder().encodeToString(bytes)

        assertEquals(
            "TVgBAAAAAAAAAAAAAAAAAAAAAAEAAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp",
            b64
        )
    }

    @Test fun `parse returns the documented M14 fields`() {
        val bytes = envelope()

        val parsed = MeshxMessageEnvelope.parse(bytes)

        assertTrue(parsed is MeshxMessageEnvelope.ParseResult.Ok)
        val envelope = (parsed as MeshxMessageEnvelope.ParseResult.Ok).envelope
        assertEquals(ByteArray(16) { if (it == 15) 1 else 0 }.toList(), envelope.messageId.toList())
        assertEquals("meshx-alpha", envelope.senderPeerId)
        assertEquals("meshx-beta", envelope.recipientPeerId)
        assertEquals(1_700_000_000_000L, envelope.createdAtMs)
        assertEquals(1, envelope.ttl)
        assertEquals("TX", envelope.payloadType)
        assertEquals("hi", String(envelope.payload))
    }

    @Test fun `parse returns an error for malformed envelopes`() {
        val parsed = MeshxMessageEnvelope.parse("hi".toByteArray())

        assertEquals(
            MeshxMessageEnvelope.ParseResult.Error("missing_magic"),
            parsed
        )
    }

    @Test fun `validate rejects malformed envelopes without throwing`() {
        assertEquals("missing_magic", MeshxMessageEnvelope.validate("hi".toByteArray()))
        assertEquals(
            "truncated_envelope",
            MeshxMessageEnvelope.validate(byteArrayOf('M'.code.toByte(), 'X'.code.toByte(), 1, 0, 1))
        )
    }

    @Test fun `minimal valid M14 envelope still exceeds legacy manufacturer payload budget`() {
        val minimal = MeshxMessageEnvelope.buildV1(
            messageId = ByteArray(16),
            senderPeerId = "a",
            recipientPeerId = null,
            createdAtMs = 0L,
            ttl = 1,
            payloadType = "T",
            payload = ByteArray(0)
        )

        assertEquals(37, minimal.size)
        assertTrue(minimal.size > BleDispatcher.MAX_LEGACY_MANUFACTURER_PAYLOAD)
    }
}
