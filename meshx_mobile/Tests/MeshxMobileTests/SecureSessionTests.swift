import XCTest
@testable import Mob.Node

final class SecureSessionTests: XCTestCase {
    func testSecureSessionRunsHandshakeAndDecryptsApplicationFrame() throws {
        let initiator = try Self.initiatorSession()
        let responder = try Self.responderSession()

        let message1Frame = try XCTUnwrap(initiator.startHandshake(msgId: 1))
        let (message1Packet, message1Rest) = try Frame.decode(message1Frame)
        XCTAssertEqual(message1Rest, Data())
        XCTAssertEqual(message1Packet.type, .control)
        XCTAssertEqual(message1Packet.msgId, 1)
        XCTAssertEqual(try unwrapHandshakePayload(message1Packet.payload).count, 32)

        let responderEvents1 = try responder.receive(frame: message1Frame, replyMsgId: 2)
        XCTAssertEqual(responderEvents1.count, 1)
        let message2Frame = try Self.outgoingFrame(from: responderEvents1[0])

        let initiatorEvents = try initiator.receive(frame: message2Frame, replyMsgId: 3)
        XCTAssertEqual(initiatorEvents.count, 2)
        let message3Frame = try Self.outgoingFrame(from: initiatorEvents[0])
        try Self.assertEstablished(initiatorEvents[1], remoteStaticKey: try Self.responderStaticPublicKey())

        let responderEvents2 = try responder.receive(frame: message3Frame, replyMsgId: 4)
        XCTAssertEqual(responderEvents2.count, 1)
        try Self.assertEstablished(responderEvents2[0], remoteStaticKey: try Self.initiatorStaticPublicKey())

        let plaintext = "hello mesh".data(using: .ascii)!
        let encryptedFrame = try initiator.encrypt(
            packet: Packet(type: .data, flags: [.ackRequested], ttl: 5, msgId: 42, payload: plaintext)
        )
        let (encryptedPacket, encryptedRest) = try Frame.decode(encryptedFrame)
        XCTAssertEqual(encryptedRest, Data())
        XCTAssertTrue(encryptedPacket.flags.contains(.encrypted))
        XCTAssertTrue(encryptedPacket.flags.contains(.ackRequested))
        XCTAssertNotEqual(encryptedPacket.payload, plaintext)

        let applicationEvents = try responder.receive(frame: encryptedFrame, replyMsgId: 5)
        XCTAssertEqual(applicationEvents.count, 1)
        let plaintextFrame = try Self.applicationFrame(from: applicationEvents[0])
        let (plaintextPacket, plaintextRest) = try Frame.decode(plaintextFrame)
        XCTAssertEqual(plaintextRest, Data())
        XCTAssertEqual(plaintextPacket.type, .data)
        XCTAssertEqual(plaintextPacket.ttl, 5)
        XCTAssertEqual(plaintextPacket.msgId, 42)
        XCTAssertFalse(plaintextPacket.flags.contains(.encrypted))
        XCTAssertTrue(plaintextPacket.flags.contains(.ackRequested))
        XCTAssertEqual(plaintextPacket.payload, plaintext)
    }

    func testSecureSessionDoesNotTreatPlainControlPacketAsHandshake() throws {
        let session = SecureSession(role: .initiator)
        let frame = try Frame.encode(Packet(type: .control, msgId: 9, payload: Data([0x00, 0x01])))

        let events = try session.receive(frame: frame, replyMsgId: 10)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(try Self.applicationFrame(from: events[0]), frame)
    }

    func testSecureSessionRefusesEncryptBeforeHandshake() {
        let session = SecureSession(role: .initiator)
        XCTAssertThrowsError(try session.encrypt(packet: Packet(type: .data, msgId: 1, payload: Data()))) { err in
            XCTAssertEqual(err as? NoiseError, .handshakeIncomplete)
        }
    }

    private static func initiatorSession() throws -> SecureSession {
        SecureSession(
            noiseSession: try Mob.NoiseSession(
                role: .initiator,
                staticPrivateKey: Data(hex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!,
                ephemeralPrivateKey: Data(hex: "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f")!
            )
        )
    }

    private static func responderSession() throws -> SecureSession {
        SecureSession(
            noiseSession: try Mob.NoiseSession(
                role: .responder,
                staticPrivateKey: Data(hex: "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f")!,
                ephemeralPrivateKey: Data(hex: "606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f")!
            )
        )
    }

    private static func initiatorStaticPublicKey() throws -> Data {
        try XCTUnwrap((initiatorSession().noiseSession as? Mob.NoiseSession)?.localStaticKey)
    }

    private static func responderStaticPublicKey() throws -> Data {
        try XCTUnwrap((responderSession().noiseSession as? Mob.NoiseSession)?.localStaticKey)
    }

    private static func outgoingFrame(from event: SecureSessionEvent) throws -> Data {
        guard case .outgoingFrame(let frame) = event else {
            XCTFail("expected outgoing frame event, got \(event)")
            throw NoiseError.invalidHandshakeState
        }
        return frame
    }

    private static func applicationFrame(from event: SecureSessionEvent) throws -> Data {
        guard case .applicationFrame(let frame) = event else {
            XCTFail("expected application frame event, got \(event)")
            throw NoiseError.invalidHandshakeState
        }
        return frame
    }

    private static func assertEstablished(_ event: SecureSessionEvent, remoteStaticKey: Data) throws {
        guard case .established(let actualRemoteStaticKey) = event else {
            XCTFail("expected established event, got \(event)")
            throw NoiseError.invalidHandshakeState
        }
        XCTAssertEqual(actualRemoteStaticKey, remoteStaticKey)
    }
}
