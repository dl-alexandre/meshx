package dev.meshx.mob.ble

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MeshxFetchProtocolTest {
    @Test
    fun requestRoundTripPreservesCanonicalFields() {
        val request = MeshxFetchProtocol.Request(
            requestId = "fetch-1",
            messageIdHash = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8),
            requesterPeerId = "meshx-beta"
        )

        val decoded = MeshxFetchProtocol.decodeRequest(MeshxFetchProtocol.encodeRequest(request))!!

        assertEquals("fetch-1", decoded.requestId)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8), decoded.messageIdHash)
        assertEquals("meshx-beta", decoded.requesterPeerId)
    }

    @Test
    fun responseRoundTripPreservesEnvelope() {
        val envelope = MeshxMessageEnvelope.buildV1(
            messageId = ByteArray(16) { it.toByte() },
            senderPeerId = "meshx-alpha",
            recipientPeerId = "meshx-beta",
            createdAtMs = 1_700_000_000_000L,
            ttl = 1,
            payloadType = "TX",
            payload = "hi".toByteArray()
        )
        val response = MeshxFetchProtocol.Response(
            requestId = "fetch-1",
            messageIdHash = MeshxFetchGatt.messageIdHash(ByteArray(16) { it.toByte() }),
            status = MeshxFetchProtocol.STATUS_OK,
            envelope = envelope,
            reason = null
        )

        val decoded = MeshxFetchProtocol.decodeResponse(MeshxFetchProtocol.encodeResponse(response))!!

        assertEquals("fetch-1", decoded.requestId)
        assertEquals(MeshxFetchProtocol.STATUS_OK, decoded.status)
        assertArrayEquals(response.messageIdHash, decoded.messageIdHash)
        assertArrayEquals(envelope, decoded.envelope)
        assertNull(decoded.reason)
    }

    @Test
    fun responseRoundTripPreservesFailureReason() {
        val response = MeshxFetchProtocol.Response(
            requestId = "fetch-1",
            messageIdHash = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8),
            status = MeshxFetchProtocol.STATUS_NOT_FOUND,
            envelope = null,
            reason = "not_found"
        )

        val decoded = MeshxFetchProtocol.decodeResponse(MeshxFetchProtocol.encodeResponse(response))!!

        assertEquals(MeshxFetchProtocol.STATUS_NOT_FOUND, decoded.status)
        assertEquals("not_found", decoded.reason)
        assertNull(decoded.envelope)
    }

    @Test
    fun malformedMessagesAreRejected() {
        assertNull(MeshxFetchProtocol.decodeRequest(byteArrayOf('M'.code.toByte())))
        assertNull(MeshxFetchProtocol.decodeResponse(byteArrayOf('M'.code.toByte())))
    }
}
