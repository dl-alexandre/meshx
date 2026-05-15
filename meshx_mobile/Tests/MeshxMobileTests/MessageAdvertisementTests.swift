import XCTest
import CryptoKit
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

    // MARK: - Legacy beacon build (send-side, advert-only profile)

    func testLegacyBeaconBuildProducesByteLayoutPerWireSpec() {
        let messageId = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        let senderPeerId = "meshx-ios"

        let beacon = MeshxLegacyBeaconAdvertisement.build(
            messageId: messageId,
            senderPeerId: senderPeerId,
            payloadKind: "TX"
        )

        XCTAssertEqual(beacon.beaconPayload.count, MeshxLegacyBeaconAdvertisement.payloadSize)
        // M B (magic) then versions, kind, flags.
        XCTAssertEqual(beacon.beaconPayload[0], 0x4D)
        XCTAssertEqual(beacon.beaconPayload[1], 0x42)
        XCTAssertEqual(beacon.beaconPayload[2], 1)    // beacon_version
        XCTAssertEqual(beacon.beaconPayload[3], 1)    // envelope_version
        XCTAssertEqual(beacon.beaconPayload[4], 1)    // kind = TX
        XCTAssertEqual(beacon.beaconPayload[5], 0)    // reserved flags

        XCTAssertEqual(beacon.messageIdHash.count, 8)
        XCTAssertEqual(beacon.senderPeerIdHash.count, 8)
        // Hashes are deterministic — sha256(input)[0..8].
        XCTAssertEqual(
            beacon.beaconPayload.subdata(in: 6..<14),
            beacon.messageIdHash
        )
        XCTAssertEqual(
            beacon.beaconPayload.subdata(in: 14..<22),
            beacon.senderPeerIdHash
        )

        // Manufacturer-data wrap: little-endian 0xFFFF then the 22 payload bytes.
        XCTAssertEqual(beacon.manufacturerData.count, 24)
        XCTAssertEqual(beacon.manufacturerData[0], 0xFF)
        XCTAssertEqual(beacon.manufacturerData[1], 0xFF)
        XCTAssertEqual(beacon.manufacturerData.suffix(22), beacon.beaconPayload)

        // Full AD structure: [length, type, manufacturerData].
        XCTAssertEqual(beacon.advertisement.count, 26)
        XCTAssertEqual(beacon.advertisement[0], UInt8(beacon.manufacturerData.count + 1))
        XCTAssertEqual(beacon.advertisement[1], 0xFF) // AD type = MANUFACTURER_SPECIFIC_DATA
    }

    func testLegacyBeaconBuildRoundTripsThroughParse() throws {
        let messageId = Data([
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
        ])
        let senderPeerId = "meshx-t577u"

        let built = MeshxLegacyBeaconAdvertisement.build(
            messageId: messageId,
            senderPeerId: senderPeerId
        )

        let parsed = try XCTUnwrap(
            MeshxLegacyBeaconAdvertisement.parse(manufacturerData: built.manufacturerData)
        )

        XCTAssertEqual(parsed.beaconVersion, built.beaconVersion)
        XCTAssertEqual(parsed.envelopeVersion, built.envelopeVersion)
        XCTAssertEqual(parsed.payloadKind, built.payloadKind)
        XCTAssertEqual(parsed.messageIdHash, built.messageIdHash)
        XCTAssertEqual(parsed.senderPeerIdHash, built.senderPeerIdHash)
        XCTAssertEqual(parsed.beaconPayload, built.beaconPayload)
        XCTAssertEqual(parsed.manufacturerData, built.manufacturerData)
        XCTAssertEqual(parsed.advertisement, built.advertisement)
    }

    func testLegacyBeaconHashesMatchAndroidDerivation() {
        // Android: sha256(messageId).copyOfRange(0, 8) and
        // sha256(senderPeerId UTF-8).copyOfRange(0, 8). The fleet relies
        // on identical hashing so a beacon advertised by an Android
        // tablet has the *same* message_id_hash an iOS receiver computes.
        // This test pins the hash inputs and verifies that property by
        // recomputing the truncation independently here.
        let messageId = Data([0xDE, 0xAD, 0xBE, 0xEF] + Array(repeating: UInt8(0), count: 12))
        let senderPeerId = "meshx-android-test"

        let beacon = MeshxLegacyBeaconAdvertisement.build(
            messageId: messageId,
            senderPeerId: senderPeerId
        )

        let expectedMsgHash = Data(sha256ReferenceImpl(messageId)).prefix(8)
        let expectedSenderHash = Data(sha256ReferenceImpl(Data(senderPeerId.utf8))).prefix(8)

        XCTAssertEqual(beacon.messageIdHash, Data(expectedMsgHash))
        XCTAssertEqual(beacon.senderPeerIdHash, Data(expectedSenderHash))
    }

    func testIOSParseDecodesAndroidEmittedBeaconByteForByte() throws {
        // Bytes captured from the bidirectional run on real hardware
        // (commit cd5b473, T390 dispatching a beacon decoded by T577U):
        //   MeshxBleDispatch: legacy_beacon_advertising_started
        //     beacon = "TUIBAQEAIfYKelgWpNr3CAbt3ChbzA=="  (22 bytes)
        //     message_id_hash    = "IfYKelgWpNo="          (8 bytes)
        //     sender_peer_id_hash = "9wgG7dwoW8w="          (8 bytes)
        //     payload_kind = "TX", envelope_version = 1
        //
        // This is the empirical iOS↔Android wire-compatibility check the
        // parity goal asks for, *without* needing an iOS device: the
        // Swift parser MUST decode an Android-emitted beacon to the
        // same field values the Android side logged at emit time. If
        // the layouts ever drift, this test fails at exactly the byte
        // that broke.

        let beaconPayload = try XCTUnwrap(
            Data(base64Encoded: "TUIBAQEAIfYKelgWpNr3CAbt3ChbzA==")
        )
        XCTAssertEqual(beaconPayload.count, 22)

        var manufacturerData = Data([0xFF, 0xFF]) // company id 0xFFFF, little-endian
        manufacturerData.append(beaconPayload)

        let parsed = try XCTUnwrap(
            MeshxLegacyBeaconAdvertisement.parse(manufacturerData: manufacturerData)
        )

        XCTAssertEqual(parsed.beaconVersion, 1)
        XCTAssertEqual(parsed.envelopeVersion, 1)
        XCTAssertEqual(parsed.payloadKind, "TX")
        XCTAssertEqual(
            parsed.messageIdHash,
            try XCTUnwrap(Data(base64Encoded: "IfYKelgWpNo="))
        )
        XCTAssertEqual(
            parsed.senderPeerIdHash,
            try XCTUnwrap(Data(base64Encoded: "9wgG7dwoW8w="))
        )
        XCTAssertEqual(parsed.beaconPayload, beaconPayload)
        XCTAssertEqual(parsed.manufacturerData, manufacturerData)
    }

    func testLegacyBeaconBuildAcceptsUnknownPayloadKindCodeZero() {
        let beacon = MeshxLegacyBeaconAdvertisement.build(
            messageId: Data(repeating: 0xAA, count: 16),
            senderPeerId: "x",
            payloadKind: "OTHER"
        )

        XCTAssertEqual(beacon.beaconPayload[4], 0) // kindCode = 0 for non-TX

        // parse maps kindCode 0 → "unknown" (per existing parse logic).
        let parsed = MeshxLegacyBeaconAdvertisement.parse(
            manufacturerData: beacon.manufacturerData
        )
        XCTAssertEqual(parsed?.payloadKind, "unknown")
    }

    // SHA-256 reference (CryptoKit; same backend the production code uses,
    // but isolated here so the test is independent of the build helper).
    private func sha256ReferenceImpl(_ data: Data) -> [UInt8] {
        var hasher = CryptoKit.SHA256()
        hasher.update(data: data)
        return Array(hasher.finalize())
    }
}
