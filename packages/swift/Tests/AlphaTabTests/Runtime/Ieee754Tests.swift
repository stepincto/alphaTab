// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import AlphaTabRuntime

/// `Math.sin` and friends must return the bits Node returns (V8's fdlibm port, not the platform libm).
/// The vectors come from `scripts/ieee754-vectors.mjs`, run under Node.
@Suite struct Ieee754Tests {
    private static let vectors: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Ieee754Vectors.txt")

    private func double(_ hex: Substring) -> Double {
        return Double(bitPattern: UInt64(hex, radix: 16)!)
    }

    @Test func mathMatchesNode() throws {
        let text = try String(contentsOf: Self.vectors, encoding: .utf8)
        var checked: [String: Int] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ")
            let name = String(parts[0])
            let args = parts.dropFirst().dropLast().map(double)
            let expected = double(parts.last!)
            let actual: Double
            switch name {
            case "sin": actual = Math.sin(args[0])
            case "cos": actual = Math.cos(args[0])
            case "asin": actual = Math.asin(args[0])
            case "log": actual = Math.log(args[0])
            case "log2": actual = Math.log2(args[0])
            case "atan2": actual = Math.atan2(args[0], args[1])
            default: Issue.record("unknown function \(name)"); continue
            }
            let same = expected.isNaN ? actual.isNaN : actual.bitPattern == expected.bitPattern
            #expect(same, "Math.\(name)(\(args.map { String($0.bitPattern, radix: 16) })): \(String(actual.bitPattern, radix: 16)) != \(String(expected.bitPattern, radix: 16))")
            checked[name, default: 0] += 1
        }
        #expect(checked.count == 6)
    }
}
