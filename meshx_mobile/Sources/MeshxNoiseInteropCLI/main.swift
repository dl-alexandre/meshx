import Foundation
import Mob.Node

private let initiatorStaticPrivate = Data(hex: "1111111111111111111111111111111111111111111111111111111111111111")!
private let initiatorEphemeralPrivate = Data(hex: "2222222222222222222222222222222222222222222222222222222222222222")!
private let responderStaticPrivate = Data(hex: "3333333333333333333333333333333333333333333333333333333333333333")!
private let responderEphemeralPrivate = Data(hex: "4444444444444444444444444444444444444444444444444444444444444444")!

private let initiatorPlaintext = Data("swift-to-decibel".utf8)
private let responderPlaintext = Data("swift-to-decibel".utf8)

private struct Output: Encodable {
    var mode: String
    var protocolName = NoiseProtocol.name
    var role: String
    var established: Bool?
    var message1: String?
    var message2: String?
    var message3: String?
    var handshakeHash: String?
    var localStaticKey: String?
    var remoteStaticKey: String?
    var ciphertextToResponder: String?
    var ciphertextToInitiator: String?
    var decryptedFromResponder: String?
    var decryptedFromInitiator: String?
}

private enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case invalidHex(String)
    case invalidUTF8(String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .invalidHex(let value):
            return "invalid hex: \(value)"
        case .invalidUTF8(let field):
            return "\(field) was not valid UTF-8"
        }
    }
}

private func argument(_ name: String, in args: [String]) throws -> String {
    guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else {
        throw CLIError.usage("missing required argument \(name)")
    }
    return args[index + 1]
}

private func optionalArgument(_ name: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else {
        return nil
    }
    return args[index + 1]
}

private func dataArgument(_ name: String, in args: [String]) throws -> Data {
    let hex = try argument(name, in: args)
    guard let data = Data(hex: hex) else {
        throw CLIError.invalidHex(hex)
    }
    return data
}

private func optionalDataArgument(_ name: String, in args: [String]) throws -> Data? {
    guard let hex = optionalArgument(name, in: args) else {
        return nil
    }
    guard let data = Data(hex: hex) else {
        throw CLIError.invalidHex(hex)
    }
    return data
}

private func initiator() throws -> Mob.NoiseSession {
    try Mob.NoiseSession(
        role: .initiator,
        staticPrivateKey: initiatorStaticPrivate,
        ephemeralPrivateKey: initiatorEphemeralPrivate
    )
}

private func responder() throws -> Mob.NoiseSession {
    try Mob.NoiseSession(
        role: .responder,
        staticPrivateKey: responderStaticPrivate,
        ephemeralPrivateKey: responderEphemeralPrivate
    )
}

private func utf8(_ data: Data, field: String) throws -> String {
    guard let value = String(data: data, encoding: .utf8) else {
        throw CLIError.invalidUTF8(field)
    }
    return value
}

private func run(args: [String]) throws -> Output {
    guard let mode = args.first else {
        throw CLIError.usage("usage: Mob.NoiseInteropCLI <initiator-message1|initiator|responder-message2|responder> [args]")
    }

    switch mode {
    case "initiator-message1":
        let session = try initiator()
        let message1 = try session.handshakeSend()
        return Output(
            mode: mode,
            role: "initiator",
            established: session.isEstablished,
            message1: message1?.hex(),
            localStaticKey: session.localStaticKey.hex()
        )

    case "initiator":
        let responderMessage2 = try dataArgument("--responder-message2", in: args)
        let responderCiphertext = try optionalDataArgument("--responder-ciphertext", in: args)
        let session = try initiator()
        let message1 = try session.handshakeSend()
        try session.handshakeReceive(responderMessage2)
        let message3 = try session.handshakeSend()
        let ciphertext = try session.encrypt(initiatorPlaintext)
        let decrypted = try responderCiphertext.map { try session.decrypt($0) }

        return Output(
            mode: mode,
            role: "initiator",
            established: session.isEstablished,
            message1: message1?.hex(),
            message3: message3?.hex(),
            handshakeHash: session.handshakeHash?.hex(),
            localStaticKey: session.localStaticKey.hex(),
            remoteStaticKey: session.remoteStaticKey?.hex(),
            ciphertextToResponder: ciphertext.hex(),
            decryptedFromResponder: try decrypted.map { try utf8($0, field: "decryptedFromResponder") }
        )

    case "responder-message2":
        let message1 = try dataArgument("--message1", in: args)
        let session = try responder()
        try session.handshakeReceive(message1)
        let message2 = try session.handshakeSend()
        return Output(
            mode: mode,
            role: "responder",
            established: session.isEstablished,
            message2: message2?.hex(),
            localStaticKey: session.localStaticKey.hex()
        )

    case "responder":
        let message1 = try dataArgument("--message1", in: args)
        let message3 = try dataArgument("--message3", in: args)
        let initiatorCiphertext = try optionalDataArgument("--initiator-ciphertext", in: args)
        let session = try responder()
        try session.handshakeReceive(message1)
        let message2 = try session.handshakeSend()
        try session.handshakeReceive(message3)
        let decrypted = try initiatorCiphertext.map { try session.decrypt($0) }
        let ciphertext = try session.encrypt(responderPlaintext)

        return Output(
            mode: mode,
            role: "responder",
            established: session.isEstablished,
            message2: message2?.hex(),
            handshakeHash: session.handshakeHash?.hex(),
            localStaticKey: session.localStaticKey.hex(),
            remoteStaticKey: session.remoteStaticKey?.hex(),
            ciphertextToInitiator: ciphertext.hex(),
            decryptedFromInitiator: try decrypted.map { try utf8($0, field: "decryptedFromInitiator") }
        )

    default:
        throw CLIError.usage("unknown mode \(mode)")
    }
}

do {
    let output = try run(args: Array(CommandLine.arguments.dropFirst()))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(output))
    FileHandle.standardOutput.write(Data([0x0A]))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

private extension Data {
    func hex() -> String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }

        self.init(bytes)
    }
}
