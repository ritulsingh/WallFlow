#!/usr/bin/env swift
import CryptoKit
import Foundation

if CommandLine.arguments.count < 3 {
    fputs("usage: sign-update.swift <ed25519-seed-base64> <archive>\n", stderr)
    exit(2)
}

guard let seed = Data(base64Encoded: CommandLine.arguments[1]), seed.count == 32 else {
    fputs("private key must be a 32-byte Ed25519 seed, base64 encoded\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: CommandLine.arguments[2])
guard let body = try? Data(contentsOf: url) else {
    fputs("could not read \(url.path)\n", stderr)
    exit(1)
}

do {
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    let signature = key.signature(for: body)
    print(signature.base64EncodedString())
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
