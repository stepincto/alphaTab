// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

// File-scope forwarders: inside `Math`, a bare `sin(x)` would call `Math.sin` itself.
private func _sqrt(_ x: Double) -> Double { Foundation.sqrt(x) }
private func _pow(_ b: Double, _ e: Double) -> Double { Foundation.pow(b, e) }
private func _exp(_ x: Double) -> Double { Foundation.exp(x) }
private func _log(_ x: Double) -> Double { Foundation.log(x) }
private func _log2(_ x: Double) -> Double { Foundation.log2(x) }
private func _log10(_ x: Double) -> Double { Foundation.log10(x) }
private func _sin(_ x: Double) -> Double { Foundation.sin(x) }
private func _cos(_ x: Double) -> Double { Foundation.cos(x) }
private func _tan(_ x: Double) -> Double { Foundation.tan(x) }
private func _asin(_ x: Double) -> Double { Foundation.asin(x) }
private func _atan(_ x: Double) -> Double { Foundation.atan(x) }
private func _atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) }

/// JS `Math`, the members Kotlin's `alphaTab.core.ecmaScript.Math` has.
public enum Math {
    public static let PI: Double = Double.pi
    public static let SQRT2: Double = 1.4142135623730951

    public static func floor(_ x: Double) -> Double {
        return x.rounded(.down)
    }

    public static func ceil(_ x: Double) -> Double {
        return x.rounded(.up)
    }

    /// JS rounds half up (`-2.5` -> `-2`, `2.5` -> `3`) and keeps `-0` for `[-0.5, 0)`;
    /// Swift's `.rounded()` rounds half away from zero. Exact for every Double (no `x + 0.5` drift).
    public static func round(_ x: Double) -> Double {
        if !x.isFinite {
            return x
        }
        let f = x.rounded(.down)
        let r = x - f >= 0.5 ? f + 1 : f
        return r == 0 && x.sign == .minus ? -0.0 : r
    }

    public static func abs(_ x: Double) -> Double {
        return Swift.abs(x)
    }

    public static func sqrt(_ x: Double) -> Double {
        return _sqrt(x)
    }

    /// JS: `pow(x, NaN)` is NaN and `pow(+-1, +-Infinity)` is NaN; C's `pow` returns 1 for both.
    public static func pow(_ b: Double, _ e: Double) -> Double {
        if e.isNaN || (Swift.abs(b) == 1 && e.isInfinite) {
            return Double.nan
        }
        return _pow(b, e)
    }

    public static func exp(_ x: Double) -> Double {
        return _exp(x)
    }

    public static func log(_ x: Double) -> Double {
        return _log(x)
    }

    public static func log2(_ x: Double) -> Double {
        return _log2(x)
    }

    public static func log10(_ x: Double) -> Double {
        return _log10(x)
    }

    public static func sin(_ x: Double) -> Double {
        return _sin(x)
    }

    public static func cos(_ x: Double) -> Double {
        return _cos(x)
    }

    public static func tan(_ x: Double) -> Double {
        return _tan(x)
    }

    public static func asin(_ x: Double) -> Double {
        return _asin(x)
    }

    public static func atan(_ x: Double) -> Double {
        return _atan(x)
    }

    public static func atan2(_ y: Double, _ x: Double) -> Double {
        return _atan2(y, x)
    }

    public static func random() -> Double {
        return Double.random(in: 0..<1)
    }

    /// JS: NaN wins, and `max(-0, 0)` is `0`. Swift's `max` does neither.
    public static func max(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN {
            return Double.nan
        }
        if a == b {
            return a.sign == .minus ? b : a
        }
        return a > b ? a : b
    }

    /// JS: NaN wins, and `min(-0, 0)` is `-0`.
    public static func min(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN {
            return Double.nan
        }
        if a == b {
            return a.sign == .minus ? a : b
        }
        return a < b ? a : b
    }

    /// `Math.max()` with no arguments is `-Infinity`, as JS.
    public static func max(_ values: Double...) -> Double {
        return values.reduce(-Double.infinity) { max($0, $1) }
    }

    /// `Math.min()` with no arguments is `Infinity`, as JS.
    public static func min(_ values: Double...) -> Double {
        return values.reduce(Double.infinity) { min($0, $1) }
    }
}
