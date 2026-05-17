import XCTest
@testable import MeshxMobile

/// Pure-protocol round-trip tests for the MFQ/MFR wire format —
/// no CoreBluetooth, no devices required.
///
/// These prove the encode/decode pairs in `MeshxFetchProtocol` are
/// inverses of each other and that the responder's
/// `MeshxFetchGattResponder` (when given a parsed request) prepares
/// bytes the client's `MeshxFetchGattClient` can correctly decode.
///
/// Hardware-level GATT delivery is exercised by the Android
/// `MXFullEnvelopeSmokeTest`; these JVM-free unit tests catch
/// protocol drift between the two Swift types (client + responder)
/// before it surfaces on real radio.
final class FetchProtocolRoundTripTests: XCTestCase {
    func testMessageEnvelopeBuildV1RoundTripsThroughParser() throws {
        let messageId = Data(hex: "000102030405060708090a0b0c0d0e0f")!
        let envelope = try MessageEnvelope.buildV1(
            messageId: messageId,
            senderPeerId: "ios-responder",
            recipientPeerId: nil,
            createdAt: 1_771_234_567_000,
            ttl: 1,
            payloadType: "TX",
            payload: Data("hello-full-envelope".utf8)
        )

        guard case .success(let parsed) = MessageEnvelope.parse(envelope) else {
            XCTFail("expected built envelope to parse")
            return
        }

        XCTAssertEqual(parsed.messageId, messageId)
        XCTAssertEqual(parsed.senderPeerId, "ios-responder")
        XCTAssertNil(parsed.recipientPeerId)
        XCTAssertEqual(parsed.createdAt, 1_771_234_567_000)
        XCTAssertEqual(parsed.ttl, 1)
        XCTAssertEqual(parsed.payloadType, "TX")
        XCTAssertEqual(parsed.payload, Data("hello-full-envelope".utf8))
    }

    func testRequestEncodeDecodeRoundTrip() {
        let original = MeshxFetchProtocol.Request(
            requestId: "abc-123",
            messageIdHash: Data([0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6, 0x07, 0x18]),
            requesterPeerId: "meshx-ios-test"
        )

        let encoded = MeshxFetchProtocol.encodeRequest(original)
        XCTAssertNotNil(encoded)
        let decoded = MeshxFetchProtocol.decodeRequest(encoded!)
        XCTAssertEqual(decoded, original)
    }

    func testRequestEncodeRoundTripWithNoRequesterPeerId() {
        let original = MeshxFetchProtocol.Request(
            requestId: "x",
            messageIdHash: Data(repeating: 0, count: 8),
            requesterPeerId: nil
        )

        let encoded = MeshxFetchProtocol.encodeRequest(original)
        XCTAssertNotNil(encoded)
        let decoded = MeshxFetchProtocol.decodeRequest(encoded!)
        XCTAssertEqual(decoded, original)
    }

    func testResponseOkEncodeDecodeRoundTrip() {
        let envelope = Data(repeating: 0xEE, count: 82)
        let original = MeshxFetchProtocol.Response(
            requestId: "req-1",
            messageIdHash: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]),
            status: MeshxFetchProtocol.statusOK,
            envelope: envelope,
            reason: nil
        )

        let encoded = MeshxFetchProtocol.encodeResponse(original)
        let decoded = MeshxFetchProtocol.decodeResponse(encoded)
        XCTAssertEqual(decoded?.requestId, original.requestId)
        XCTAssertEqual(decoded?.messageIdHash, original.messageIdHash)
        XCTAssertEqual(decoded?.status, MeshxFetchProtocol.statusOK)
        XCTAssertEqual(decoded?.envelope, envelope)
    }

    func testResponseNotFoundEncodeDecodeRoundTrip() {
        let original = MeshxFetchProtocol.Response(
            requestId: "req-2",
            messageIdHash: Data(repeating: 0xAA, count: 8),
            status: MeshxFetchProtocol.statusNotFound,
            envelope: nil,
            reason: "not_found"
        )

        let encoded = MeshxFetchProtocol.encodeResponse(original)
        let decoded = MeshxFetchProtocol.decodeResponse(encoded)
        XCTAssertEqual(decoded?.requestId, original.requestId)
        XCTAssertEqual(decoded?.messageIdHash, original.messageIdHash)
        XCTAssertEqual(decoded?.status, MeshxFetchProtocol.statusNotFound)
        XCTAssertNil(decoded?.envelope)
        XCTAssertEqual(decoded?.reason, "not_found")
    }

    func testDecodeRequestRejectsTruncatedInput() {
        XCTAssertNil(MeshxFetchProtocol.decodeRequest(Data()))
        XCTAssertNil(MeshxFetchProtocol.decodeRequest(Data([0x4D, 0x46])))
        // Wrong magic
        XCTAssertNil(MeshxFetchProtocol.decodeRequest(
            Data([0xFF, 0xFF, 0xFF, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        ))
    }

    func testDecodeResponseRejectsTruncatedInput() {
        XCTAssertNil(MeshxFetchProtocol.decodeResponse(Data()))
        XCTAssertNil(MeshxFetchProtocol.decodeResponse(Data([0x4D, 0x46, 0x52])))
    }

    func testResponderRefusesInvalidEnvelopeAtInit() {
        XCTAssertThrowsError(
            try MeshxFetchGattResponder(
                envelope: Data([0xFF, 0xFF, 0xFF]),  // not "MX..."
                responderPeerId: "test"
            )
        ) { error in
            guard case MeshxFetchGattResponder.ResponderError.invalidEnvelope = error else {
                XCTFail("expected ResponderError.invalidEnvelope, got \(error)")
                return
            }
        }
    }

    func testResponderPreparesOkResponseForMatchingRequest() throws {
        let messageId = Data(hex: "101112131415161718191a1b1c1d1e1f")!
        let envelope = try MessageEnvelope.buildV1(
            messageId: messageId,
            senderPeerId: "ios-responder",
            createdAt: 42,
            payload: Data("served-over-gatt".utf8)
        )
        let beacon = MeshxLegacyBeaconAdvertisement.build(
            messageId: messageId,
            senderPeerId: "ios-responder"
        )
        let responder = try MeshxFetchGattResponder(
            envelope: envelope,
            responderPeerId: "ios-responder"
        )
        let request = MeshxFetchProtocol.Request(
            requestId: "req-ok",
            messageIdHash: beacon.messageIdHash,
            requesterPeerId: "android-client"
        )

        let prepared = responder.prepareResponse(for: try XCTUnwrap(MeshxFetchProtocol.encodeRequest(request)))
        let decoded = MeshxFetchProtocol.decodeResponse(prepared.encoded)

        XCTAssertEqual(prepared.request, request)
        XCTAssertEqual(prepared.response.status, MeshxFetchProtocol.statusOK)
        XCTAssertEqual(decoded?.status, MeshxFetchProtocol.statusOK)
        XCTAssertEqual(decoded?.envelope, envelope)
    }

    func testResponderPreparesNotFoundAndInvalidRequestResponses() throws {
        let messageId = Data(hex: "202122232425262728292a2b2c2d2e2f")!
        let envelope = try MessageEnvelope.buildV1(
            messageId: messageId,
            senderPeerId: "ios-responder",
            createdAt: 42,
            payload: Data("served-over-gatt".utf8)
        )
        let responder = try MeshxFetchGattResponder(
            envelope: envelope,
            responderPeerId: "ios-responder"
        )
        let missing = MeshxFetchProtocol.Request(
            requestId: "req-missing",
            messageIdHash: Data(repeating: 0xAA, count: 8),
            requesterPeerId: nil
        )

        let notFound = responder.prepareResponse(for: try XCTUnwrap(MeshxFetchProtocol.encodeRequest(missing)))
        XCTAssertEqual(notFound.response.status, MeshxFetchProtocol.statusNotFound)
        XCTAssertEqual(MeshxFetchProtocol.decodeResponse(notFound.encoded)?.reason, "not_found")

        let invalid = responder.prepareResponse(for: Data([0x00, 0x01]))
        XCTAssertEqual(invalid.response.status, MeshxFetchProtocol.statusInvalidRequest)
        XCTAssertEqual(invalid.response.requestId, "invalid")
        XCTAssertEqual(MeshxFetchProtocol.decodeResponse(invalid.encoded)?.reason, "invalid_request")
    }
}
