// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

// V8 computes Math.sin, cos, atan2, asin, log and log2 with its own port of fdlibm (src/base/ieee754.cc), whose
// results differ from the platform libm (glibc, Apple) in the last bit for a few percent of the arguments. A
// coordinate that went through one of them prints differently, so the runtime does the same arithmetic.
// Ported from fdlibm 5.3 (k_sin, k_cos, e_rem_pio2, s_atan, e_atan2, e_asin, e_log) and FreeBSD (e_log2, k_log).
// shortcut: sin and cos take |x| up to 2^19 * pi/2 (the "medium size" branch of e_rem_pio2); larger arguments
// go to the platform libm. Rendering never gets near that.
enum Ieee754 {
    @inline(__always) private static func high(_ x: Double) -> Int32 {
        return Int32(truncatingIfNeeded: x.bitPattern >> 32)
    }

    @inline(__always) private static func low(_ x: Double) -> UInt32 {
        return UInt32(truncatingIfNeeded: x.bitPattern)
    }

    @inline(__always) private static func make(_ high: Int32, _ low: UInt32) -> Double {
        return Double(bitPattern: (UInt64(UInt32(bitPattern: high)) << 32) | UInt64(low))
    }

    @inline(__always) private static func withLow(_ x: Double, _ low: UInt32) -> Double {
        return make(high(x), low)
    }

    @inline(__always) private static func withHigh(_ x: Double, _ high: Int32) -> Double {
        return make(high, self.low(x))
    }

    // MARK: sin, cos

    private static let S1 = -1.66666666666666324348e-01
    private static let S2 = 8.33333333332248946124e-03
    private static let S3 = -1.98412698298579493134e-04
    private static let S4 = 2.75573137070700676789e-06
    private static let S5 = -2.50507602534068634195e-08
    private static let S6 = 1.58969099521155010221e-10

    private static let C1 = 4.16666666666666019037e-02
    private static let C2 = -1.38888888888741095749e-03
    private static let C3 = 2.48015872894767294178e-05
    private static let C4 = -2.75573143513906633035e-07
    private static let C5 = 2.08757232129817482790e-09
    private static let C6 = -1.13596475577881948265e-11

    private static func kernelSin(_ x: Double, _ y: Double, _ iy: Int) -> Double {
        let ix = high(x) & 0x7fffffff
        if ix < 0x3e400000 {
            if Int(x) == 0 { return x }
        }
        let z = x * x
        let v = z * x
        let r = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)))
        if iy == 0 {
            return x + v * (S1 + z * r)
        }
        return x - ((z * (0.5 * y - v * r) - y) - v * S1)
    }

    private static func kernelCos(_ x: Double, _ y: Double) -> Double {
        let ix = high(x) & 0x7fffffff
        if ix < 0x3e400000 {
            if Int(x) == 0 { return 1.0 }
        }
        let z = x * x
        let r = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))))
        if ix < 0x3FD33333 {
            return 1.0 - (0.5 * z - (z * r - x * y))
        }
        let qx: Double = ix > 0x3fe90000 ? 0.28125 : make(ix - 0x00200000, 0)
        let hz = 0.5 * z - qx
        let a = 1.0 - qx
        return a - (hz - (z * r - x * y))
    }

    private static let invpio2 = 6.36619772367581382433e-01
    private static let pio2_1 = 1.57079632673412561417e+00
    private static let pio2_1t = 6.07710050650619224932e-11
    private static let pio2_2 = 6.07710050630396597660e-11
    private static let pio2_2t = 2.02226624879595063154e-21
    private static let pio2_3 = 2.02226624871116645580e-21
    private static let pio2_3t = 8.47842766036889956997e-32

    /// High words of n * pi/2, n = 1...32.
    private static let npio2hw: [Int32] = (1...32).map { high(Double($0) * 1.5707963267948966) }

    /// `__ieee754_rem_pio2` for |x| <= 2^19 * pi/2: returns n and sets y0, y1 so that x = n * pi/2 + y0 + y1.
    private static func remPio2(_ x: Double) -> (n: Int, y0: Double, y1: Double) {
        let hx = high(x)
        let ix = hx & 0x7fffffff
        if ix <= 0x3fe921fb {
            return (0, x, 0)
        }
        if ix < 0x4002d97c {
            if hx > 0 {
                var z = x - pio2_1
                if ix != 0x3ff921fb {
                    let y0 = z - pio2_1t
                    return (1, y0, (z - y0) - pio2_1t)
                }
                z -= pio2_2
                let y0 = z - pio2_2t
                return (1, y0, (z - y0) - pio2_2t)
            }
            var z = x + pio2_1
            if ix != 0x3ff921fb {
                let y0 = z + pio2_1t
                return (-1, y0, (z - y0) + pio2_1t)
            }
            z += pio2_2
            let y0 = z + pio2_2t
            return (-1, y0, (z - y0) + pio2_2t)
        }
        // |x| ~<= 2^19 * (pi/2), medium size
        var t = abs(x)
        let n = Int(t * invpio2 + 0.5)
        let fn = Double(n)
        var r = t - fn * pio2_1
        var w = fn * pio2_1t
        var y0: Double
        if n < 32 && ix != npio2hw[n - 1] {
            y0 = r - w
        } else {
            let j = ix >> 20
            y0 = r - w
            var i = j - ((high(y0) >> 20) & 0x7ff)
            if i > 16 {
                t = r
                w = fn * pio2_2
                r = t - w
                w = fn * pio2_2t - ((t - r) - w)
                y0 = r - w
                i = j - ((high(y0) >> 20) & 0x7ff)
                if i > 49 {
                    t = r
                    w = fn * pio2_3
                    r = t - w
                    w = fn * pio2_3t - ((t - r) - w)
                    y0 = r - w
                }
            }
        }
        let y1 = (r - y0) - w
        if hx < 0 {
            return (-n, -y0, -y1)
        }
        return (n, y0, y1)
    }

    static func sin(_ x: Double) -> Double {
        let ix = high(x) & 0x7fffffff
        if ix <= 0x3fe921fb {
            return kernelSin(x, 0, 0)
        }
        if ix >= 0x7ff00000 {
            return Double.nan
        }
        if ix > 0x413921fb {
            return Foundation.sin(x)
        }
        let (n, y0, y1) = remPio2(x)
        switch n & 3 {
        case 0: return kernelSin(y0, y1, 1)
        case 1: return kernelCos(y0, y1)
        case 2: return -kernelSin(y0, y1, 1)
        default: return -kernelCos(y0, y1)
        }
    }

    static func cos(_ x: Double) -> Double {
        let ix = high(x) & 0x7fffffff
        if ix <= 0x3fe921fb {
            return kernelCos(x, 0)
        }
        if ix >= 0x7ff00000 {
            return Double.nan
        }
        if ix > 0x413921fb {
            return Foundation.cos(x)
        }
        let (n, y0, y1) = remPio2(x)
        switch n & 3 {
        case 0: return kernelCos(y0, y1)
        case 1: return -kernelSin(y0, y1, 1)
        case 2: return -kernelCos(y0, y1)
        default: return kernelSin(y0, y1, 1)
        }
    }

    // MARK: atan, atan2

    private static let atanhi: [Double] = [
        4.63647609000806093515e-01, 7.85398163397448278999e-01, 9.82793723247329054082e-01, 1.57079632679489655800e+00
    ]
    private static let atanlo: [Double] = [
        2.26987774529616870924e-17, 3.06161699786838301793e-17, 1.39033110312309984516e-17, 6.12323399573676603587e-17
    ]
    private static let aT: [Double] = [
        3.33333333333329318027e-01, -1.99999999998764832476e-01, 1.42857142725034663711e-01,
        -1.11111104054623557880e-01, 9.09088713343650656196e-02, -7.69187620504482999495e-02,
        6.66107313738753120669e-02, -5.83357013379057348645e-02, 4.97687799461593236017e-02,
        -3.65315727442169155270e-02, 1.62858201153657823623e-02
    ]

    static func atan(_ input: Double) -> Double {
        var x = input
        let hx = high(x)
        let ix = hx & 0x7fffffff
        var id: Int
        if ix >= 0x44100000 {
            if ix > 0x7ff00000 || (ix == 0x7ff00000 && low(x) != 0) {
                return x + x
            }
            return hx > 0 ? atanhi[3] + atanlo[3] : -atanhi[3] - atanlo[3]
        }
        if ix < 0x3fdc0000 {
            if ix < 0x3e200000 {
                if 1.0e300 + x > 1.0 { return x }
            }
            id = -1
        } else {
            x = abs(x)
            if ix < 0x3ff30000 {
                if ix < 0x3fe60000 {
                    id = 0
                    x = (2.0 * x - 1.0) / (2.0 + x)
                } else {
                    id = 1
                    x = (x - 1.0) / (x + 1.0)
                }
            } else {
                if ix < 0x40038000 {
                    id = 2
                    x = (x - 1.5) / (1.0 + 1.5 * x)
                } else {
                    id = 3
                    x = -1.0 / x
                }
            }
        }
        let z = x * x
        let w = z * z
        let s1 = z * (aT[0] + w * (aT[2] + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))))
        let s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))))
        if id < 0 {
            return x - x * (s1 + s2)
        }
        let r = atanhi[id] - ((x * (s1 + s2) - atanlo[id]) - x)
        return hx < 0 ? -r : r
    }

    static func atan2(_ y: Double, _ x: Double) -> Double {
        let tiny = 1.0e-300
        let piO4 = 7.8539816339744827900e-01
        let piO2 = 1.5707963267948965580e+00
        let pi = 3.1415926535897931160e+00
        let piLo = 1.2246467991473531772e-16
        let hx = high(x)
        let lx = low(x)
        let ix = hx & 0x7fffffff
        let hy = high(y)
        let ly = low(y)
        let iy = hy & 0x7fffffff
        // NaN
        if (UInt32(bitPattern: ix) | ((lx | (0 &- lx)) >> 31)) > 0x7ff00000
            || (UInt32(bitPattern: iy) | ((ly | (0 &- ly)) >> 31)) > 0x7ff00000 {
            return x + y
        }
        if (UInt32(bitPattern: hx &- 0x3ff00000) | lx) == 0 {
            return atan(y)
        }
        var m = Int(((hy >> 31) & 1) | ((hx >> 30) & 2))
        if (UInt32(bitPattern: iy) | ly) == 0 {
            switch m {
            case 0, 1: return y
            case 2: return pi + tiny
            default: return -pi - tiny
            }
        }
        if (UInt32(bitPattern: ix) | lx) == 0 {
            return hy < 0 ? -piO2 - tiny : piO2 + tiny
        }
        if ix == 0x7ff00000 {
            if iy == 0x7ff00000 {
                switch m {
                case 0: return piO4 + tiny
                case 1: return -piO4 - tiny
                case 2: return 3.0 * piO4 + tiny
                default: return -3.0 * piO4 - tiny
                }
            }
            switch m {
            case 0: return 0.0
            case 1: return -0.0
            case 2: return pi + tiny
            default: return -pi - tiny
            }
        }
        if iy == 0x7ff00000 {
            return hy < 0 ? -piO2 - tiny : piO2 + tiny
        }
        let k = (iy - ix) >> 20
        var z: Double
        if k > 60 {
            z = piO2 + 0.5 * piLo
            m &= 1
        } else if hx < 0 && k < -60 {
            z = 0.0
        } else {
            z = atan(abs(y / x))
        }
        switch m {
        case 0: return z
        case 1: return -z
        case 2: return pi - (z - piLo)
        default: return (z - piLo) - pi
        }
    }

    // MARK: asin

    private static let pio2Hi = 1.57079632679489655800e+00
    private static let pio2Lo = 6.12323399573676603587e-17
    private static let pio4Hi = 7.85398163397448278999e-01
    private static let pS0 = 1.66666666666666657415e-01
    private static let pS1 = -3.25565818622400915405e-01
    private static let pS2 = 2.01212532134862925881e-01
    private static let pS3 = -4.00555345006794114027e-02
    private static let pS4 = 7.91534994289814532176e-04
    private static let pS5 = 3.47933107596021167570e-05
    private static let qS1 = -2.40339491173441421878e+00
    private static let qS2 = 2.02094576023350569471e+00
    private static let qS3 = -6.88283971605453293030e-01
    private static let qS4 = 7.70381505559019352791e-02

    static func asin(_ x: Double) -> Double {
        let hx = high(x)
        let ix = hx & 0x7fffffff
        if ix >= 0x3ff00000 {
            if (UInt32(bitPattern: ix &- 0x3ff00000) | low(x)) == 0 {
                return x * pio2Hi + x * pio2Lo
            }
            return Double.nan
        } else if ix < 0x3fe00000 {
            var t = 0.0
            if ix < 0x3e400000 {
                if 1.0e300 + x > 1.0 { return x }
            } else {
                t = x * x
            }
            let p = t * (pS0 + t * (pS1 + t * (pS2 + t * (pS3 + t * (pS4 + t * pS5)))))
            let q = 1.0 + t * (qS1 + t * (qS2 + t * (qS3 + t * qS4)))
            let w = p / q
            return x + x * w
        }
        var w = 1.0 - abs(x)
        var t = w * 0.5
        let p = t * (pS0 + t * (pS1 + t * (pS2 + t * (pS3 + t * (pS4 + t * pS5)))))
        let q = 1.0 + t * (qS1 + t * (qS2 + t * (qS3 + t * qS4)))
        let s = t.squareRoot()
        if ix >= 0x3FEF3333 {
            w = p / q
            t = pio2Hi - (2.0 * (s + s * w) - pio2Lo)
        } else {
            w = withLow(s, 0)
            let c = (t - w * w) / (s + w)
            let r = p / q
            let pp = 2.0 * s * r - (pio2Lo - 2.0 * c)
            let qq = pio4Hi - 2.0 * w
            t = pio4Hi - (pp - qq)
        }
        return hx > 0 ? t : -t
    }

    // MARK: log, log2

    private static let ln2Hi = 6.93147180369123816490e-01
    private static let ln2Lo = 1.90821492927058770002e-10
    private static let two54 = 1.80143985094819840000e+16
    private static let Lg1 = 6.666666666666735130e-01
    private static let Lg2 = 3.999999999940941908e-01
    private static let Lg3 = 2.857142874366239149e-01
    private static let Lg4 = 2.222219843214978396e-01
    private static let Lg5 = 1.818357216161805012e-01
    private static let Lg6 = 1.531383769920937332e-01
    private static let Lg7 = 1.479819860511658591e-01

    static func log(_ input: Double) -> Double {
        var x = input
        var hx = high(x)
        let lx = low(x)
        var k: Int32 = 0
        if hx < 0x00100000 {
            if (UInt32(bitPattern: hx & 0x7fffffff) | lx) == 0 {
                return -Double.infinity
            }
            if hx < 0 {
                return Double.nan
            }
            k -= 54
            x *= two54
            hx = high(x)
        }
        if hx >= 0x7ff00000 {
            return x + x
        }
        k += (hx >> 20) - 1023
        hx &= 0x000fffff
        var i = (hx + 0x95f64) & 0x100000
        x = withHigh(x, hx | (i ^ 0x3ff00000))
        k += i >> 20
        let f = x - 1.0
        if (0x000fffff & (2 + hx)) < 3 {
            if f == 0.0 {
                if k == 0 { return 0.0 }
                let dk = Double(k)
                return dk * ln2Hi + dk * ln2Lo
            }
            let r = f * f * (0.5 - 0.33333333333333333 * f)
            if k == 0 { return f - r }
            let dk = Double(k)
            return dk * ln2Hi - ((r - dk * ln2Lo) - f)
        }
        let s = f / (2.0 + f)
        let dk = Double(k)
        let z = s * s
        i = hx - 0x6147a
        let w = z * z
        let j = 0x6b851 - hx
        let t1 = w * (Lg2 + w * (Lg4 + w * Lg6))
        let t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)))
        i |= j
        let r = t2 + t1
        if i > 0 {
            let hfsq = 0.5 * f * f
            if k == 0 { return f - (hfsq - s * (hfsq + r)) }
            return dk * ln2Hi - ((hfsq - (s * (hfsq + r) + dk * ln2Lo)) - f)
        }
        if k == 0 { return f - s * (f - r) }
        return dk * ln2Hi - ((s * (f - r) - dk * ln2Lo) - f)
    }

    private static let ivln2hi = 1.44269504072144627571e+00
    private static let ivln2lo = 1.67517131648865118353e-10

    private static func kLog1p(_ f: Double) -> Double {
        let s = f / (2.0 + f)
        let z = s * s
        let w = z * z
        let t1 = w * (Lg2 + w * (Lg4 + w * Lg6))
        let t2 = z * (Lg1 + w * (Lg3 + w * (Lg5 + w * Lg7)))
        let r = t2 + t1
        let hfsq = 0.5 * f * f
        return s * (hfsq + r)
    }

    static func log2(_ input: Double) -> Double {
        var x = input
        var hx = high(x)
        let lx = low(x)
        var k: Int32 = 0
        if hx < 0x00100000 {
            if (UInt32(bitPattern: hx & 0x7fffffff) | lx) == 0 {
                return -Double.infinity
            }
            if hx < 0 {
                return Double.nan
            }
            k -= 54
            x *= two54
            hx = high(x)
        }
        if hx >= 0x7ff00000 {
            return x + x
        }
        if hx == 0x3ff00000 && lx == 0 {
            return 0.0
        }
        k += (hx >> 20) - 1023
        hx &= 0x000fffff
        let i = (hx + 0x95f64) & 0x100000
        x = withHigh(x, hx | (i ^ 0x3ff00000))
        k += i >> 20
        let y = Double(k)
        let f = x - 1.0
        let hfsq = 0.5 * f * f
        let r = kLog1p(f)
        let hi = withLow(f - hfsq, 0)
        let lo = (f - hi) - hfsq + r
        var valHi = hi * ivln2hi
        var valLo = (lo + hi) * ivln2lo + lo * ivln2hi
        let w = y + valHi
        valLo += (y - w) + valHi
        valHi = w
        return valLo + valHi
    }
}
