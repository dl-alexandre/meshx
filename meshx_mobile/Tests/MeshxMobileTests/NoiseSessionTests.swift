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

    /// Cross-implementation pinned vector — mirrors
    /// `apps/meshx_noise/test/meshx_noise/interop_vector_test.exs` on
    /// the Elixir Decibel side. Same four X25519 private keys
    /// (initiator + responder × static + ephemeral), same expected
    /// handshake messages, same expected handshake hash, same expected
    /// transport ciphertext for plaintext "test-vector-001" at nonce 0.
    ///
    /// If this test fails, exactly one of two things is true:
    ///   1. Intentional wire-format change — update both this test AND
    ///      the Elixir mirror in the same commit, treating it as a
    ///      protocol bump.
    ///   2. Silent drift between Decibel and `Noise.swift` — one
    ///      implementation has diverged from the spec. Investigate
    ///      both sides; cross-impl interop is now broken.
    ///
    /// See project memory `[[noise-cross-impl-vector]]` for the full
    /// convention.
    func testNoiseXXHandshakeMatchesElixirInteropVector() throws {
        let initiator = try MeshxNoiseSession(
            role: .initiator,
            staticPrivateKey: Data(hex: "1111111111111111111111111111111111111111111111111111111111111111")!,
            ephemeralPrivateKey: Data(hex: "2222222222222222222222222222222222222222222222222222222222222222")!
        )
        let responder = try MeshxNoiseSession(
            role: .responder,
            staticPrivateKey: Data(hex: "3333333333333333333333333333333333333333333333333333333333333333")!,
            ephemeralPrivateKey: Data(hex: "4444444444444444444444444444444444444444444444444444444444444444")!
        )

        let message1 = try XCTUnwrap(initiator.handshakeSend())
        XCTAssertEqual(
            message1.hex(),
            "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20",
            "msg1 diverged from Elixir interop_vector_test.exs"
        )
        try responder.handshakeReceive(message1)

        let message2 = try XCTUnwrap(responder.handshakeSend())
        XCTAssertEqual(
            message2.hex(),
            "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b"
                + "34844ab378b06d2634652a1eb7d2b6c67c2082af188b41dd5e7da57cf64439f3"
                + "9e4164252dece86e03665b2c8170e73626758372b95363977f16178df5b07cf6",
            "msg2 diverged from Elixir interop_vector_test.exs"
        )
        try initiator.handshakeReceive(message2)

        let message3 = try XCTUnwrap(initiator.handshakeSend())
        XCTAssertEqual(
            message3.hex(),
            "75537efbe989fb8406a0dcce52dbec0f832fd70f3c37a8f6efb0d8b74afcc1a5"
                + "7f070028f97b2774865619e7e95635798a0f66f1a7bf1a0524d7a6d60143eda0",
            "msg3 diverged from Elixir interop_vector_test.exs"
        )
        try responder.handshakeReceive(message3)

        XCTAssertTrue(initiator.isEstablished)
        XCTAssertTrue(responder.isEstablished)
        XCTAssertEqual(
            initiator.handshakeHash?.hex(),
            "d8c98117de2824856612c13cda9c2dd1785d92bea9ec0d22eeaf930554676b3b",
            "handshake_hash diverged from Elixir interop_vector_test.exs"
        )
        XCTAssertEqual(initiator.handshakeHash, responder.handshakeHash)

        // Recovered remote static keys must match.
        XCTAssertEqual(
            initiator.remoteStaticKey?.hex(),
            "7b0d47d93427f8311160781c7c733fd89f88970aef490d8aa0ee19a4cb8a1b14",
            "initiator's view of responder's static key diverged"
        )
        XCTAssertEqual(
            responder.remoteStaticKey?.hex(),
            "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13",
            "responder's view of initiator's static key diverged"
        )

        // First initiator → responder transport message after handshake
        // completion. Pinned byte-for-byte to lock the ChaChaPoly
        // cipherstate init + nonce handling.
        let plaintext = "test-vector-001".data(using: .ascii)!
        let ciphertext = try initiator.encrypt(plaintext)
        XCTAssertEqual(
            ciphertext.hex(),
            "015b6953682e76b486b21405cabb87c4e1a17a37f259823a5e471f9fa5e08c",
            "transport ciphertext at nonce 0 diverged from Elixir interop_vector_test.exs"
        )
        XCTAssertEqual(try responder.decrypt(ciphertext), plaintext)
    }
}
