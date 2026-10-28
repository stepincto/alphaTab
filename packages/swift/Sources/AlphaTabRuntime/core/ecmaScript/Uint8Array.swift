// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// An element type a JS typed array stores, with the spec's conversion from `number`.
public protocol TypedArrayElement {
    init(js value: Double)
    var js: Double { get }
}

extension UInt8: TypedArrayElement {
    /// ECMA-262 ToUint8: ToUint32 modulo 2^8.
    @inlinable public init(js value: Double) { self.init(truncatingIfNeeded: jsToUint32(value)) }
    @inlinable public var js: Double { Double(self) }
}

/// Backing store shared by a typed array and its `subarray` views (JS `ArrayBuffer`).
public final class TypedArrayStorage<E> {
    public var data: [E]
    init(_ data: [E]) { self.data = data }
}

/// Shared core of `Uint8Array`, `Int32Array` and `Float32Array`: a view (`offset`,
/// `count`) on a shared store, as in JS. Elements read and write as `number` (`Double`).
/// Out-of-range or non-integer reads give `NaN` (JS `undefined`) and such writes are ignored.
/// Range errors JS throws (negative length, `set` past the end) trap here.
public class TypedArray<E: TypedArrayElement>: Sequence {
    public let storage: TypedArrayStorage<E>
    public let offset: Int
    public let count: Int

    public required init(storage: TypedArrayStorage<E>, offset: Int, count: Int) {
        self.storage = storage
        self.offset = offset
        self.count = count
    }

    /// `new XArray(length)`: ToIndex, so a fraction truncates.
    public convenience init(_ length: Double) {
        let n = length.isNaN ? 0.0 : length.rounded(.towardZero)
        precondition(n >= 0 && n <= Double(Int32.max), "RangeError: Invalid typed array length: \(length)")
        self.init(storage: TypedArrayStorage([E](repeating: E(js: 0), count: Int(n))), offset: 0, count: Int(n))
    }

    /// `new XArray()`: empty.
    public convenience init() {
        self.init(0.0)
    }

    /// `new XArray(arrayLike)`: each value converted as on write.
    public convenience init(_ values: some Sequence<Double>) {
        self.init(values.map { E(js: $0) })
    }

    /// Wraps platform values without conversion.
    public convenience init(_ values: [E]) {
        self.init(storage: TypedArrayStorage(values), offset: 0, count: values.count)
    }

    public var length: Double { Double(count) }

    /// The view's elements as a Swift array (a copy).
    public var elements: [E] { Swift.Array(storage.data[offset..<(offset + count)]) }

    public subscript(index: Int) -> Double {
        get { index >= 0 && index < count ? storage.data[offset + index].js : .nan }
        set {
            if index >= 0 && index < count {
                storage.data[offset + index] = E(js: newValue)
            }
        }
    }

    public subscript(index: Double) -> Double {
        get { index == index.rounded(.towardZero) && abs(index) < 9e15 ? self[Int(index)] : .nan }
        set {
            if index == index.rounded(.towardZero) && abs(index) < 9e15 {
                self[Int(index)] = newValue
            }
        }
    }

    /// ECMA-262 relative index: negative counts from the end, clamped to `0...count`.
    private func relative(_ value: Double?, _ fallback: Int) -> Int {
        guard let v = value else { return fallback }
        if v.isNaN { return 0 }
        let t = v.rounded(.towardZero)
        return t < 0 ? Int(Swift.max(Double(count) + t, 0)) : Int(Swift.min(t, Double(count)))
    }

    /// A view on the same store; writes through it show in this array.
    public func subarray(_ begin: Double = 0, _ end: Double? = nil) -> Self {
        let s = relative(begin, 0)
        let e = relative(end, count)
        return Self(storage: storage, offset: offset + s, count: Swift.max(e - s, 0))
    }

    /// A copy of a range, on a new store.
    public func slice(_ start: Double = 0, _ end: Double? = nil) -> Self {
        let s = relative(start, 0)
        let e = Swift.max(relative(end, count), s)
        let copy = Swift.Array(storage.data[(offset + s)..<(offset + e)])
        return Self(storage: TypedArrayStorage(copy), offset: 0, count: copy.count)
    }

    /// Copies `source` in at `offset`; an overlapping view of the same store copies as if
    /// through a temporary, as JS does.
    public func set(_ source: TypedArray<E>, _ offset: Double = 0) {
        let o = offset.rounded(.towardZero)
        precondition(o >= 0 && o + source.length <= length, "RangeError: offset is out of bounds")
        let at = self.offset + Int(o)
        let src = source.storage.data[source.offset..<(source.offset + source.count)]
        storage.data.replaceSubrange(at..<(at + source.count), with: Swift.Array(src))
    }

    /// Copies array-like `source` (another element type or a `List`) in at `offset`.
    public func set(_ source: some Sequence<Double>, _ offset: Double = 0) {
        let values = source.map { E(js: $0) }
        set(TypedArray(values), offset)
    }

    @discardableResult
    public func fill(_ value: Double, _ start: Double = 0, _ end: Double? = nil) -> Self {
        let s = relative(start, 0)
        let e = relative(end, count)
        let v = E(js: value)
        var i = s
        while i < e {
            storage.data[offset + i] = v
            i += 1
        }
        return self
    }

    @discardableResult
    public func reverse() -> Self {
        storage.data[offset..<(offset + count)].reverse()
        return self
    }

    public struct Iterator: IteratorProtocol {
        let array: TypedArray<E>
        var index = 0
        public mutating func next() -> Double? {
            guard index < array.count else { return nil }
            defer { index += 1 }
            return array[index]
        }
    }

    public func makeIterator() -> Iterator { Iterator(array: self) }
}

/// JS `Uint8Array`: bytes, written modulo 2^8.
public final class Uint8Array: TypedArray<UInt8> {
    /// The view's bytes, for platform code (text codecs, file IO).
    public var bytes: [UInt8] { elements }
}
