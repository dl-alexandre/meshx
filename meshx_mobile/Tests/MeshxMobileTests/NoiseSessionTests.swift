import XCTest
@testable import MeshxMobile

final class NoiseSessionTests: XCTestCase {
    func testBLAKE2sKnownVectors() {
        XCTAssertEqual(
            BLAKE2s.hash(Data()).hex(),
            "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9"
        )
        XCTAssertEqual(
            BLAKE2s.hash("abc".data(using: .ascii)!).hex(),
            "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982"
        )
        XCTAssertEqual(
            BLAKE2s.hmac(key: "key".data(using: .ascii)!, data: "data".data(using: .ascii)!).hex(),
            "84f646acda0776ee848b7f9dc5771c7d8cf023999c0c3dd84dc78636a146e805"
        )
    }

    func testNoiseXXHandshakeAndTransportRoundTrip() throws {
        // Fixed vectors generated with a Noise rev34-compatible implementation
        // using the same static and ephemeral X25519 private keys below.
        let initiator = try MeshxNoiseSession(
            role: .initiator,
            staticPrivateKey: Data(hex: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")!,
            ephemeralPrivateKey: Data(hex: "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f")!
        )
        let responder = try MeshxNoiseSession(
            role: .responder,
            staticPrivateKey: Data(hex: "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f")!,
            ephemeralPrivateKey: Data(hex: "606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f")!
        )

        let message1 = try XCTUnwrap(initiator.handshakeSend())
        XCTAssertEqual(message1.count, 32)
        XCTAssertEqual(message1.hex(), "358072d6365880d1aeea329adf9121383851ed21a28e3b75e965d0d2cd166254")
        try responder.handshakeReceive(message1)

        let message2 = try XCTUnwrap(responder.handshakeSend())
        XCTAssertEqual(message2.count, 96)
        XCTAssertEqual(
            message2.hex(),
            "675dd574ed7789310b3d2e7681f3790b466c773b1521fecf36577958371ea52f"
                + "eb05ff723dfaa2cf9c3bba8d146a4a5348d1cb05787a2802a66cd40293380c43"
                + "614fd10dafea57abb5856de7be2a4f2a155bdd926bbc7936c04e9d4b0170316f"
        )
        try initiator.handshakeReceive(message2)

        let message3 = try XCTUnwrap(initiator.handshakeSend())
        XCTAssertEqual(message3.count, 64)
        XCTAssertEqual(
            message3.hex(),
            "cd0bb5353946d9772fcf0852cc0956ef2ca0d30c0573c138692ad8c3f99aef50"
                + "9b5e64cba6c6cd8aa361de4e4a508838266a64975d00ace214e434719f193b96"
        )
        try responder.handshakeReceive(message3)

        XCTAssertTrue(initiator.isEstablished)
        XCTAssertTrue(responder.isEstablished)
        XCTAssertEqual(initiator.remoteStaticKey, responder.localStaticKey)
        XCTAssertEqual(responder.remoteStaticKey, initiator.localStaticKey)
        XCTAssertEqual(initiator.handshakeHash, responder.handshakeHash)
        XCTAssertEqual(
            initiator.handshakeHash?.hex(),
            "c695a654f8caa273b00a9860275370d17047c343630eec3b21773e7cf757d650"
        )
        XCTAssertNil(try initiator.handshakeSend())
        XCTAssertNil(try responder.handshakeSend())

        let plaintext = "hello mesh".data(using: .ascii)!
        let ciphertext = try initiator.encrypt(plaintext)
        XCTAssertNotEqual(ciphertext, plaintext)
        XCTAssertEqual(ciphertext.hex(), "952c9cc8603b6a2c0e025fdca7758f2febb58021519db530187f")
        XCTAssertEqual(try responder.decrypt(ciphertext), plaintext)

        let reply = "ack".data(using: .ascii)!
        let replyCiphertext = try responder.encrypt(reply)
        XCTAssertEqual(replyCiphertext.hex(), "249c2918283b3c93d9a844e03f27d4f1c99954")
        XCTAssertEqual(try initiator.decrypt(replyCiphertext), reply)
    }

    func testNoiseRejectsTransportDecryptBeforeHandshakeCompletes() throws {
        let session = MeshxNoiseSession(role: .initiator)
        XCTAssertThrowsError(try session.encrypt(Data([0x01]))) { err in
            XCTAssertEqual(err as? NoiseError, .handshakeIncomplete)
        }
    }
}
