import XCTest
@testable import Mob.Node

/// Mirror of `docs/WIRE_VECTORS.md` and the Elixir-side
/// `apps/mob_protocol/test/mob_protocol/wire_vectors_test.exs`.
/// If these fail, the Swift codec disagrees with the canonical bytes.
final class WireVectorsTests: XCTestCase {

    // MARK: - V1

    func testV1_dataPacketEncodesToFixedBytes() throws {
        let packet = Packet(type: .data, msgId: 42, payload: "hello mesh".data(using: .ascii)!)
        let frame = try Frame.encode(packet)
        XCTAssertEqual(frame.hex(), "010100400a002a00000068656c6c6f206d657368c339")
    }

    func testV1_decodesBackToPacket() throws {
        let frame = Data(hex: "010100400a002a00000068656c6c6f206d657368c339")!
        let (packet, rest) = try Frame.decode(frame)
        XCTAssertEqual(packet.type, .data)
        XCTAssertEqual(packet.msgId, 42)
        XCTAssertEqual(packet.ttl, 64)
        XCTAssertEqual(packet.flags.rawValue, 0)
        XCTAssertEqual(String(data: packet.payload, encoding: .ascii), "hello mesh")
        XCTAssertEqual(rest, Data())
    }

    // MARK: - V2

    func testV2_emptyControlPacketEncodesToFixedBytes() throws {
        let packet = Packet(type: .control, msgId: 0, payload: Data())
        let frame = try Frame.encode(packet)
        XCTAssertEqual(frame.hex(), "010400400000000000003d27")
    }

    // MARK: - V3

    func testV3_ackWithFlagsAndShortTtlEncodesToFixedBytes() throws {
        let packet = Packet(
            type: .ack,
            flags: [.ackRequested],
            ttl: 5,
            msgId: 0xDEADBEEF,
            payload: Data()
        )
        let frame = try Frame.encode(packet)
        XCTAssertEqual(frame.hex(), "010204050000efbeadde90b5")
    }

    // MARK: - V4

    func testV4_fragmentedPayloadByteLayout() throws {
        // We can't pin the per-fragment msg_id (it's BEAM phash2 on the
        // Elixir side, random on ours). But the payload layout of each
        // fragment is deterministic and is what receivers actually rely on.
        let payload = "ABCDEFGHIJ".data(using: .ascii)!
        let fragments = Fragment.fragment(origMsgId: 0x11223344, payload: payload, maxChunkSize: 4, ttl: 32)

        XCTAssertEqual(fragments.count, 3)

        // Each fragment's payload field, hex-encoded:
        let payloads = fragments.map { $0.payload.hex() }
        XCTAssertEqual(payloads[0], "44332211000341424344")
        XCTAssertEqual(payloads[1], "4433221101034546474852".prefix(20).description)  // chunk "EFGH"
        XCTAssertEqual(payloads[2], "443322110203494a")

        // Header consistency
        for (i, frag) in fragments.enumerated() {
            XCTAssertEqual(frag.type, .fragment)
            XCTAssertEqual(frag.ttl, 32)
            XCTAssertEqual(frag.flags.rawValue, 0)
            XCTAssertEqual(frag.payload[frag.payload.startIndex + 4], UInt8(i))
            XCTAssertEqual(frag.payload[frag.payload.startIndex + 5], UInt8(3))
        }
    }

    func testV4_fragmentRoundTripReassembles() throws {
        let original = "ABCDEFGHIJ".data(using: .ascii)!
        let fragments = Fragment.fragment(origMsgId: 0x11223344, payload: original, maxChunkSize: 4, ttl: 32)

        guard let parts = Fragment.reassemble(fragments) else {
            XCTFail("reassemble returned nil for a complete set")
            return
        }
        XCTAssertEqual(parts.origMsgId, 0x11223344)
        XCTAssertEqual(parts.chunks.reduce(Data(), +), original)
    }

    // MARK: - V5

    func testV5_handshakeTagBytes() {
        XCTAssertEqual(NoiseProtocol.handshakeTag, [0x4D, 0x58, 0x4E, 0x31])
        XCTAssertEqual(String(bytes: NoiseProtocol.handshakeTag, encoding: .ascii), "MXN1")
    }

    func testV5_wrapAndUnwrapHandshakePayloadRoundTrip() throws {
        let noiseMessage = Data([0xAB, 0xCD])
        let wrapped = wrapHandshakePayload(noiseMessage)
        XCTAssertEqual(wrapped.hex(), "4d584e31abcd")

        let unwrapped = try unwrapHandshakePayload(wrapped)
        XCTAssertEqual(unwrapped, noiseMessage)
    }

    func testV5_unwrapRejectsMissingTag() {
        XCTAssertThrowsError(try unwrapHandshakePayload(Data([0x00, 0x01, 0x02, 0x03, 0xFF]))) { err in
            XCTAssertEqual(err as? NoiseError, .unexpectedTag)
        }
    }

    // MARK: - V6

    func testV6_chunkHeaderEncodesToFixedBytesAtMtu30() {
        let frame = Data(repeating: 0xAA, count: 50)
        let chunks = Chunk.encode(frame: frame, mtu: 30, streamId: 7)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].hex(),
                       "4d5842310000000700000003aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        XCTAssertEqual(chunks[1].hex(),
                       "4d5842310000000700010003aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        XCTAssertEqual(chunks[2].hex(),
                       "4d5842310000000700020003aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    func testV6_chunkReassemblesInOrderRegardlessOfReceiveOrder() {
        let frame = Data(repeating: 0xAA, count: 50)
        let chunks = Chunk.encode(frame: frame, mtu: 30, streamId: 7)
        let reassembler = ChunkReassembler()
        // Out-of-order delivery
        XCTAssertNil(reassembler.push(peerId: "peer-a", chunk: chunks[2]))
        XCTAssertNil(reassembler.push(peerId: "peer-a", chunk: chunks[0]))
        XCTAssertEqual(reassembler.push(peerId: "peer-a", chunk: chunks[1]), frame)
    }

    // MARK: - CRC corruption

    func testFrame_crcMismatchIsRejected() throws {
        var frame = Data(hex: "010100400a002a00000068656c6c6f206d657368c339")!
        frame[frame.endIndex - 1] ^= 0xFF
        XCTAssertThrowsError(try Frame.decode(frame)) { err in
            XCTAssertEqual(err as? FrameError, .checksumMismatch)
        }
    }
}

// MARK: - Hex helpers (test-local; not part of public API)

extension Data {
    func hex() -> String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hex: String) {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let b = UInt8(String(chars[i...i+1]), radix: 16) else { return nil }
            bytes.append(b)
        }
        self.init(bytes)
    }
}
