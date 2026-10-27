// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

private enum SampleEnum: Int, IAlphaTabEnum, CaseIterable {
    case b = 2
    case a = -1
    case c = 5
}

/// Expected values come from node (V8): `(v).toString(radix)`, DataView conversions, `Object.values`.
@Suite struct GlobalsTests {
    @Test func toStringWithRadixMatchesJs() {
        #expect((255.0).toInvariantString(16.0) == "ff")
        #expect((-255.0).toInvariantString(2.0) == "-11111111")
        #expect((0.0).toInvariantString(16.0) == "0")
        #expect((3.999).toInvariantString(10.0) == "3.999")
        #expect(Double.nan.toInvariantString(16.0) == "NaN")
        #expect((-Double.infinity).toInvariantString(2.0) == "-Infinity")
    }

    @Test func toStringWithRadixKeepsFraction() {
        // Kotlin truncates to an Int here; JS keeps the fraction.
        #expect((0.5).toInvariantString(2.0) == "0.1")
        #expect((-0.75).toInvariantString(2.0) == "-0.11")
        #expect((65536.5).toInvariantString(16.0) == "10000.8")
        #expect((0.1).toInvariantString(16.0) == "0.1999999999999a")
        #expect((0.1).toInvariantString(3.0) == "0.0022002200220022002200220022002201")
        #expect((123.456).toInvariantString(36.0) == "3f.gez4w97ry")
        #expect((1e21).toInvariantString(36.0) == "5v1j4f4ds7c000")
    }

    @Test func lazyComputesOnceAndCachesNull() throws {
        var calls = 0
        let lazy = Lazy<Double?>({ () -> Double? in
            calls += 1
            return nil
        })
        #expect(!lazy.hasValue)
        #expect(try lazy.value == nil)
        #expect(try lazy.value == nil)
        #expect(calls == 1)
        #expect(lazy.hasValue)
        lazy.reset()
        #expect(!lazy.hasValue)
        _ = try lazy.value
        #expect(calls == 2)
    }

    /// A throwing factory reaches the reader (JS lets the error propagate out of the getter) and caches nothing.
    @Test func lazyFactoryErrorReachesTheReader() {
        let lazy = Lazy<Double>({ () throws -> Double in
            throw JsError("factory failed")
        })
        #expect(throws: JsError.self) { try lazy.value }
        #expect(!lazy.hasValue)
    }

    @Test func objectValuesOfEnumGivesNumbersInDeclarationOrder() {
        let values = Object.values(SampleEnum.self).filter({ TypeHelper.typeOf($0) == "number" })
        #expect(values.map({ $0 as! Double })._data == [2.0, -1.0, 5.0])
    }

    @Test func objectEntriesOfRecordGivesPairsInInsertionOrder() {
        let record = Record<String, Double>()
        record.set("b", 1.0)
        record.set("a", 2.0)
        let entries = Object.entries(record)
        #expect(entries.map({ $0.0 })._data == ["b", "a"])
        #expect(entries.map({ $0.1 })._data == [1.0, 2.0])
    }

    @Test func typeConversionsWrapLikeDataView() {
        #expect(TypeConversions.int32ToUint16(65535) == 65535)
        #expect(TypeConversions.int32ToInt16(65535) == -1)
        #expect(TypeConversions.int32ToUint32(-1) == 4_294_967_295)
        #expect(TypeConversions.int32ToInt16(32768) == -32768)
        #expect(TypeConversions.int32ToUint16(70000) == 4464)
        #expect(TypeConversions.int32ToUint32(-2_147_483_649) == 2_147_483_647)
        #expect(TypeConversions.int32ToInt16(1.9e10) == -512)
        #expect(TypeConversions.int32ToUint32(1.9e10) == 1_820_130_816)
        #expect(TypeConversions.int32ToUint16(Double.nan) == 0)
        #expect(TypeConversions.uint16ToInt16(65535) == -1)
    }

    @Test func typeConversionsReadAndWriteBytesLikeDataView() {
        let be = TypeConversions.float32BEToBytes(1.5)
        #expect((0..<4).map { be[$0] } == [63, 192, 0, 0])
        #expect(TypeConversions.bytesToFloat64LE(Uint8Array([0, 0, 0, 0, 0, 0, 244, 63] as [Double])) == 1.25)
        #expect(TypeConversions.bytesToFloat32LE(Uint8Array([0, 0, 32, 192] as [Double])) == -2.5)
        #expect(TypeConversions.bytesToInt64LE(Uint8Array([255, 255, 255, 255, 255, 255, 255, 255] as [Double])) == -1)
        #expect(TypeConversions.bytesToInt64LE(Uint8Array([0, 0, 0, 0, 0, 0, 0, 128] as [Double])) == 9_007_199_254_740_991)
    }
}
