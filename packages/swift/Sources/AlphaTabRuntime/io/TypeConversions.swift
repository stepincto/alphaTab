// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Port of `src/io/TypeConversions.ts` (`@target web`). JS goes through a shared DataView; these are
/// the same conversions as pure functions (ToInt32, then keep the low bits), so they are thread-safe.
public enum TypeConversions {
    public static func uint16ToInt16(_ v: Double) -> Double {
        return Double(Int16(truncatingIfNeeded: jsToInt32(v)))
    }

    /// JS reads two stale buffer bytes here; this sign-extends, as Kotlin and C# do. Synth only.
    public static func int16ToUint32(_ v: Double) -> Double {
        return Double(UInt32(bitPattern: Int32(Int16(truncatingIfNeeded: jsToInt32(v)))))
    }

    public static func int32ToUint16(_ v: Double) -> Double {
        return Double(UInt16(truncatingIfNeeded: jsToInt32(v)))
    }

    public static func int32ToInt16(_ v: Double) -> Double {
        return Double(Int16(truncatingIfNeeded: jsToInt32(v)))
    }

    public static func int32ToUint32(_ v: Double) -> Double {
        return Double(jsToUint32(v))
    }

    public static func uint8ToInt8(_ v: Double) -> Double {
        return Double(Int8(truncatingIfNeeded: jsToInt32(v)))
    }

    /// First 8 bytes, little endian; JS's `set` throws on more, missing bytes read as 0 here.
    private static func _littleEndian(_ bytes: Uint8Array, _ count: Int) -> UInt64 {
        var bits: UInt64 = 0
        for i in 0..<min(count, Int(bytes.length)) {
            bits |= UInt64(UInt8(truncatingIfNeeded: jsToInt32(bytes[i]))) << (8 * i)
        }
        return bits
    }

    public static func bytesToInt64LE(_ bytes: Uint8Array) -> Double {
        let v = Int64(bitPattern: _littleEndian(bytes, 8))
        // Number.MAX_SAFE_INTEGER outside the safe range, as JS.
        return (-9_007_199_254_740_991...9_007_199_254_740_991).contains(v) ? Double(v) : 9_007_199_254_740_991
    }

    public static func bytesToFloat64LE(_ bytes: Uint8Array) -> Double {
        return Double(bitPattern: _littleEndian(bytes, 8))
    }

    public static func bytesToFloat32LE(_ bytes: Uint8Array) -> Double {
        return Double(Float(bitPattern: UInt32(truncatingIfNeeded: _littleEndian(bytes, 4))))
    }

    public static func float32BEToBytes(_ v: Double) -> Uint8Array {
        let bits = Float(v).bitPattern
        let result = Uint8Array(4.0)
        for i in 0..<4 {
            result[i] = Double((bits >> (8 * (3 - i))) & 0xFF)
        }
        return result
    }

    public static func float64ToBytes(_ v: Double) -> Uint8Array {
        let bits = v.bitPattern
        let result = Uint8Array(8.0)
        for i in 0..<8 {
            result[i] = Double((bits >> (8 * i)) & 0xFF)
        }
        return result
    }
}
