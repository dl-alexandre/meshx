import XCTest
@testable import MeshxMobile

final class MessageAdvertisementTests: XCTestCase {
    private let envelopeBase64 = "TVgBAAAAAAAAAAAAAAAAAAAAAAEAAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp"

    func testLegacyBeaconManufacturerPayloadParsesCanonicalReferenceFields() throws {
        let payload = Data([
            0x4D, 0x42, // MB
            0x01,       // beacon version
            0x01,       // envelope version
            0x01,       // payload kind TX
            0x00        // flags
        ]) + Data([1, 2, 3, 4, 5, 6, 7, 8]) + Data([8, 7, 6, 5, 4, 3, 2, 1])
        let manufacturerData = Data([0xFF, 0xFF]) + payload

        let beacon = try XCTUnwrap(
            MeshxLegacyBeaconAdvertisement.parse(manufacturerData: manufacturerData)
        )

        XCTAssertEqual(beacon.beaconVersion, 1)
        XCTAssertEqual(beacon.envelopeVersion, 1)
        XCTAssertEqual(beacon.payloadKind, "TX")
        XCTAssertEqual(beacon.messageIdHash, Data([1, 2, 3, 4, 5, 6, 7, 8]))
        XCTAssertEqual(beacon.senderPeerIdHash, Data([8, 7, 6, 5, 4, 3, 2, 1]))
        XCTAssertEqual(beacon.beaconPayload, payload)
        XCTAssertEqual(beacon.manufacturerData, manufacturerData)
        XCTAssertEqual(beacon.advertisement, Data([UInt8(manufacturerData.count + 1), 0xFF]) + manufacturerData)
    }

    func testLegacyBeaconParserRejectsWrongCompanyOrTruncatedPayload() {
        let validPayload = Data([
            0x4D, 0x42, 0x01, 0x01, 0x01, 0x00,
            1, 2, 3, 4, 5, 6, 7, 8,
            8, 7, 6, 5, 4, 3, 2, 1
        ])

        XCTAssertNil(MeshxLegacyBeaconAdvertisement.parse(manufacturerData: Data([0x4C, 0x00]) + validPayload))
        XCTAssertNil(MeshxLegacyBeaconAdvertisement.parse(manufacturerData: Data([0xFF, 0xFF]) + validPayload.dropLast()))
        XCTAssertNil(MeshxLegacyBeaconAdvertisement.parse(manufacturerData: Data([0xFF, 0xFF, 0x4D, 0x58]) + validPayload.dropFirst(2)))
    }

    func testParsesM14EnvelopeFixture() throws {
        let bytes = try XCTUnwrap(Data(base64Encoded: envelopeBase64))

        guard case .success(let envelope) = MessageEnvelope.parse(bytes) else {
            XCTFail("expected valid M14 envelope")
            return
        }

        XCTAssertEqual(envelope.messageId, Data(repeating: 0, count: 15) + Data([1]))
        XCTAssertEqual(envelope.senderPeerId, "meshx-alpha")
        XCTAssertEqual(envelope.recipientPeerId, "meshx-beta")
        XCTAssertEqual(envelope.createdAt, 1_700_000_000_000)
        XCTAssertEqual(envelope.ttl, 1)
        XCTAssertEqual(envelope.payloadType, "TX")
        XCTAssertEqual(envelope.payload, Data("hi".utf8))
    }

    func testMessageAdvertisementBecomesReceivedMessageEvent() throws {
        let envelope = try XCTUnwrap(Data(base64Encoded: envelopeBase64))
        let manufacturerData = Data([0xFF, 0xFF]) + envelope

        let result = MessageAdvertisement.decode(
            manufacturerData: manufacturerData,
            fullAdvertisement: manufacturerData,
            deviceId: "observer-device",
            rssi: -61,
            receivedAt: 12_345
        )

        guard case .received(let event) = result else {
            XCTFail("expected received event")
            return
        }

        XCTAssertEqual(event.messageId, Data(repeating: 0, count: 15) + Data([1]))
        XCTAssertEqual(event.senderPeerId, "meshx-alpha")
        XCTAssertEqual(event.recipientPeerId, "meshx-beta")
        XCTAssertEqual(event.receivedDeviceId, "observer-device")
        XCTAssertEqual(event.receivedAt, 12_345)
        XCTAssertEqual(event.rssi, -61)
        XCTAssertEqual(event.envelope, try XCTUnwrap(MessageEnvelope.parse(envelope).get()))
        XCTAssertEqual(event.rawTransportMetadata.transport, "ble_advertisement")
        XCTAssertEqual(event.rawTransportMetadata.sourceEvent, "advertisement_received")
        XCTAssertEqual(event.rawTransportMetadata.receivedDeviceId, "observer-device")
        XCTAssertEqual(event.rawTransportMetadata.advertisement, manufacturerData)
        XCTAssertEqual(event.rawTransportMetadata.messagePayload, envelope)
        XCTAssertEqual(event.rawTransportMetadata.manufacturerData, manufacturerData)
        XCTAssertEqual(event.rawTransportMetadata.companyIdentifier, 0xFFFF)
        XCTAssertEqual(event.rawTransportMetadata.adType, 0xFF)
        XCTAssertTrue(event.jsonLine().contains("\"event\":\"received_message\""))
    }

    func testReceivedMessageJsonLineEscapesAndParsesStringFields() throws {
        let envelopeBytes = try XCTUnwrap(Data(base64Encoded: envelopeBase64))
        guard case .success(let envelope) = MessageEnvelope.parse(envelopeBytes) else {
            XCTFail("expected valid M14 envelope")
            return
        }
        let event = ReceivedMessageEvent(
            messageId: Data(repeating: 7, count: 16),
            senderPeerId: "meshx-\"alpha\\one",
            recipientPeerId: "meshx\nbeta",
            receivedDeviceId: "observer\"device",
            receivedAt: 42,
            rssi: -1,
            envelope: envelope,
            rawTransportMetadata: .init(
                transport: "ble_\"advertisement",
                sourceEvent: "advertisement_received",
                receivedDeviceId: "observer\"device",
                advertisement: Data([0x00, 0x01]),
                messagePayload: envelopeBytes,
                manufacturerData: Data([0xFF, 0xFF]) + envelopeBytes,
                companyIdentifier: 0xFFFF,
                adType: 0xFF
            )
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(event.jsonLine().utf8)) as? [String: Any]
        )
        let metadata = try XCTUnwrap(object["raw_transport_metadata"] as? [String: Any])

        XCTAssertEqual(object["event"] as? String, "received_message")
        XCTAssertEqual(object["v"] as? Int, 1)
        XCTAssertEqual(object["message_id"] as? String, event.messageId.base64EncodedString())
        XCTAssertEqual(object["sender_peer_id"] as? String, "meshx-\"alpha\\one")
        XCTAssertEqual(object["recipient_peer_id"] as? String, "meshx\nbeta")
        XCTAssertEqual(object["received_device_id"] as? String, "observer\"device")
        XCTAssertEqual(object["received_at"] as? UInt64, 42)
        XCTAssertEqual(object["rssi"] as? Int, -1)
        XCTAssertEqual(object["envelope"] as? String, envelopeBytes.base64EncodedString())
        XCTAssertEqual(metadata["transport"] as? String, "ble_\"advertisement")
        XCTAssertEqual(metadata["source_event"] as? String, "advertisement_received")
        XCTAssertEqual(metadata["received_device_id"] as? String, "observer\"device")
        XCTAssertEqual(metadata["advertisement"] as? String, Data([0x00, 0x01]).base64EncodedString())
        XCTAssertEqual(metadata["message_payload"] as? String, envelopeBytes.base64EncodedString())
        XCTAssertEqual(
            metadata["manufacturer_data"] as? String,
            (Data([0xFF, 0xFF]) + envelopeBytes).base64EncodedString()
        )
        XCTAssertEqual(metadata["company_identifier"] as? UInt16, 0xFFFF)
        XCTAssertEqual(metadata["ad_type"] as? UInt8, 0xFF)
    }

    func testMalformedMessageAdvertisementReturnsTaggedError() throws {
        let bad = Data([0xFF, 0xFF]) + Data([UInt8(ascii: "M"), UInt8(ascii: "X"), 1, 0, 1, 2, 3])

        let result = MessageAdvertisement.decode(
            manufacturerData: bad,
            fullAdvertisement: bad,
            deviceId: "observer-device",
            rssi: -70,
            receivedAt: 0
        )

        XCTAssertEqual(
            result,
            .decodeError(reason: "message_advertisement_decode_error:truncated_envelope")
        )
    }

    func testDecodeErrorJsonLineEscapesAndParsesStringFields() throws {
        let event = MessageAdvertisementDecodeErrorEvent(
            reason: "message_advertisement_decode_error:\"bad\\reason",
            deviceId: "observer\nbad",
            rssi: -70
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(event.jsonLine().utf8)) as? [String: Any]
        )

        XCTAssertEqual(object["event"] as? String, "error")
        XCTAssertEqual(object["kind"] as? String, "unknown")
        XCTAssertEqual(
            object["detail"] as? String,
            "message_advertisement_decode_error:\"bad\\reason"
        )
        XCTAssertEqual(object["device_id"] as? String, "observer\nbad")
        XCTAssertEqual(object["rssi"] as? Int, -70)
    }
}
