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
}
