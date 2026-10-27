// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS typed-array semantics (ECMA-262 23.2): element conversion on write, shared-buffer
/// `subarray`, copying `slice`, relative clamped ranges, out-of-range reads as undefined (NaN).
@Suite struct TypedArrayTests {
    @Test func uint8WrapsModulo256() {
        let a = Uint8Array(4.0)
        a[0] = 300
        a[1] = -1
        a[2] = 1.9
        a[3] = Double.nan
        #expect(Swift.Array(a) == [44, 255, 1, 0])
        a[0.0] = 4_294_967_297 // 2^32 + 1; Kotlin's toInt() saturates here
        #expect(a[0.0] == 1)
    }

    @Test func int32WrapsLikeToInt32() {
        let a = Int32Array(3.0)
        a[0] = 2_147_483_648
        a[1] = -2.5
        a[2] = Double.infinity
        #expect(Swift.Array(a) == [-2_147_483_648, -2, 0])
    }

    @Test func float32RoundsToSinglePrecision() {
        let a = Float32Array(List(0.1, 1.5))
        #expect(a[0] == Double(Float(0.1)))
        #expect(a[1] == 1.5)
        #expect(a.length == 2)
    }

    @Test func outOfRangeReadsNaNAndWritesAreIgnored() {
        let a = Uint8Array(List(1.0, 2.0))
        #expect(a[5].isNaN)
        #expect(a[-1].isNaN)
        #expect(a[0.5].isNaN)
        a[5] = 9
        #expect(a.length == 2)
        #expect(Swift.Array(a) == [1, 2])
    }

    @Test func lengthTruncatesFraction() {
        #expect(Uint8Array(2.7).length == 2)
    }

    @Test func subarraySharesTheBuffer() {
        let a = Uint8Array(List(1.0, 2.0, 3.0, 4.0))
        let s = a.subarray(1, 3)
        s[0] = 9
        #expect(a[1] == 9)
        #expect(s.length == 2)
        let f = Float32Array(List(1.0, 2.0, 3.0))
        f.subarray(1)[0] = 7 // Kotlin copies here
        #expect(f[1] == 7)
    }

    @Test func subarrayClampsAndTakesNegativeIndices() {
        let a = Int32Array(List(1.0, 2.0, 3.0, 4.0))
        #expect(Swift.Array(a.subarray(-2)) == [3, 4])
        #expect(Swift.Array(a.subarray(1, -1)) == [2, 3])
        #expect(a.subarray(3, 1).length == 0)
        #expect(Swift.Array(a.subarray(-10, 10)) == [1, 2, 3, 4])
    }

    @Test func sliceCopies() {
        let a = Uint8Array(List(1.0, 2.0, 3.0))
        let s = a.slice(1)
        s[0] = 9 // Kotlin's slice shares the buffer
        #expect(a[1] == 2)
        #expect(Swift.Array(s) == [9, 3])
    }

    @Test func setCopiesAtOffsetAndHandlesOverlap() {
        let a = Uint8Array(List(1.0, 2.0, 3.0, 4.0, 5.0))
        a.set(a.subarray(0, 3), 2)
        #expect(Swift.Array(a) == [1, 2, 1, 2, 3])
        let b = Int32Array(4.0)
        b.subarray(1).set(Int32Array(List(7.0, 8.0)), 1)
        #expect(Swift.Array(b) == [0, 0, 7, 8])
    }

    @Test func fillUsesRelativeRange() {
        let a = Uint8Array(4.0)
        a.fill(257)
        #expect(Swift.Array(a) == [1, 1, 1, 1])
        a.fill(5, 1, -1)
        #expect(Swift.Array(a) == [1, 5, 5, 1])
        let f = Float32Array(3.0)
        f.subarray(1).fill(2)
        #expect(Swift.Array(f) == [0, 2, 2])
    }

    @Test func reverseOnlyTouchesTheView() {
        let a = Uint8Array(List(1.0, 2.0, 3.0, 4.0))
        a.subarray(1).reverse()
        #expect(Swift.Array(a) == [1, 4, 3, 2])
    }

    @Test func bytesRoundTrip() {
        let a = Uint8Array([1, 2, 3] as [UInt8])
        #expect(a.subarray(1).bytes == [2, 3])
    }
}
