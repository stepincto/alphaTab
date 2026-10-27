// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Array<T>`: a reference type, as in JS and Kotlin's `alphaTab.collections.List`.
/// Kotlin's `DoubleList` and `BooleanList` collapse into this (Swift generics are not boxed).
/// Indices are `Int` (`list[(i).toInt()]`), counts and positions are `Double`.
public final class List<T>: Sequence {
    /// Public so hand-written partials in the `AlphaTab` module can reach it (Kotlin: `internal`).
    public var _data: Swift.Array<T>

    public init() {
        _data = []
    }

    public init(_ items: T...) {
        _data = items
    }

    public init(contentsOf items: some Sequence<T>) {
        _data = Swift.Array(items)
    }

    /// JS `new Array<T>(length)`: JS fills holes with `undefined` (Kotlin: unchecked `null`);
    /// Swift needs a value, so elements start at `JsArrayHole.hole`. Generated code fills or
    /// writes every slot before reading it.
    public init(_ length: Int) where T: JsArrayHole {
        _data = Swift.Array(repeating: T.hole, count: length)
    }

    public var length: Double {
        return Double(_data.count)
    }

    public func makeIterator() -> IndexingIterator<Swift.Array<T>> {
        return _data.makeIterator()
    }

    /// Out of range traps (JS reads `undefined`), as Kotlin's `IndexOutOfBoundsException`.
    public subscript(index: Int) -> T {
        get { return _data[index] }
        set { _data[index] = newValue }
    }

    public func push(_ item: T) {
        _data.append(item)
    }

    public func push(_ items: T...) {
        _data.append(contentsOf: items)
    }

    public func push(contentsOf items: some Sequence<T>) {
        _data.append(contentsOf: items)
    }

    /// JS returns `undefined` on an empty array, so this is optional (Kotlin: non-null, throws).
    /// Generated code writes TS's `pop()!` as `pop()!`.
    @discardableResult
    public func pop() -> T? {
        return _data.popLast()
    }

    @discardableResult
    public func shift() -> T? {
        return _data.isEmpty ? nil : _data.removeFirst()
    }

    public func unshift(_ item: T) {
        _data.insert(item, at: 0)
    }

    @discardableResult
    public func fill(_ item: T) -> List<T> {
        for i in _data.indices {
            _data[i] = item
        }
        return self
    }

    public func filter(_ predicate: (T) throws -> Bool) rethrows -> List<T> {
        return List(contentsOf: try _data.filter(predicate))
    }

    public func findIndex(_ predicate: (T) throws -> Bool) rethrows -> Double {
        return Double(try _data.firstIndex(where: predicate) ?? -1)
    }

    public func find(_ predicate: (T) throws -> Bool) rethrows -> T? {
        return try _data.first(where: predicate)
    }

    public func some(_ predicate: (T) throws -> Bool) rethrows -> Bool {
        return try _data.contains(where: predicate)
    }

    public func map<TOut>(_ transform: (T) throws -> TOut) rethrows -> List<TOut> {
        return List<TOut>(contentsOf: try _data.map(transform))
    }

    public func map<TOut>(_ transform: (T, Double) throws -> TOut) rethrows -> List<TOut> {
        var out: Swift.Array<TOut> = []
        out.reserveCapacity(_data.count)
        for (i, v) in _data.enumerated() {
            out.append(try transform(v, Double(i)))
        }
        return List<TOut>(contentsOf: out)
    }

    public func flatMap<TOut>(_ transform: (T) throws -> List<TOut>) rethrows -> List<TOut> {
        let out = List<TOut>()
        for v in _data {
            out._data.append(contentsOf: try transform(v)._data)
        }
        return out
    }

    public func reduce(_ operation: (Double, T) throws -> Double, _ initial: Double) rethrows -> Double {
        var acc = initial
        for v in _data {
            acc = try operation(acc, v)
        }
        return acc
    }

    /// JS `sort` is stable and reads the comparator's sign only (NaN counts as equal).
    @discardableResult
    public func sort(_ comparison: (T, T) throws -> Double) rethrows -> List<T> {
        let indexed = try _data.enumerated().sorted { a, b in
            let d = try comparison(a.element, b.element)
            return d < 0 || (!(d > 0) && a.offset < b.offset)
        }
        _data = indexed.map { $0.element }
        return self
    }

    /// JS `sort()` with no comparator orders by each element's string form (`[10, 9].sort()` stays
    /// `[10, 9]`); Kotlin's `DoubleList.sort()` sorts numerically instead.
    @discardableResult
    public func sort() -> List<T> {
        let keys = _data.map { jsTemplate($0) }
        let order = _data.indices.sorted { keys[$0] < keys[$1] || (keys[$0] == keys[$1] && $0 < $1) }
        _data = order.map { _data[$0] }
        return self
    }

    @discardableResult
    public func reverse() -> List<T> {
        _data.reverse()
        return self
    }

    public func slice() -> List<T> {
        return List(contentsOf: _data)
    }

    public func slice(_ start: Double) -> List<T> {
        return slice(start, length)
    }

    public func slice(_ start: Double, _ end: Double) -> List<T> {
        let s = _relativeIndex(start)
        let e = _relativeIndex(end)
        return s < e ? List(contentsOf: _data[s..<e]) : List()
    }

    /// JS `splice(start)`: removes everything from `start` (negative counts from the end).
    @discardableResult
    public func splice(_ start: Double) -> List<T> {
        return splice(start, length)
    }

    /// JS `splice(start, deleteCount, ...items)`: returns only the removed elements
    /// (Kotlin returns everything from `start` to the end; see the runtime notes).
    @discardableResult
    public func splice(_ start: Double, _ deleteCount: Double, _ items: T...) -> List<T> {
        return splice(start, deleteCount, contentsOf: items)
    }

    @discardableResult
    public func splice(_ start: Double, _ deleteCount: Double, contentsOf items: some Collection<T>) -> List<T> {
        let s = _relativeIndex(start)
        let count = Swift.max(0, Swift.min(deleteCount.toInt(), _data.count - s))
        let removed = List(contentsOf: _data[s..<(s + count)])
        _data.replaceSubrange(s..<(s + count), with: items)
        return removed
    }

    public func join(_ separator: String) -> String {
        return _data.map { jsTemplate($0) }.joined(separator: separator)
    }

    /// JS relative index: negative counts from the end, clamped to `0...count`.
    private func _relativeIndex(_ index: Double) -> Int {
        let i = index.toInt()
        let n = _data.count
        return i < 0 ? Swift.max(0, n + i) : Swift.min(i, n)
    }
}

extension List where T: Equatable {
    public func includes(_ value: T) -> Bool {
        return _data.contains(value)
    }

    public func indexOf(_ value: T) -> Double {
        return Double(_data.firstIndex(of: value) ?? -1)
    }
}

/// Class instances compare by identity, as JS `===` and Kotlin's default `equals`.
/// shortcut: a class that is also `Equatable` makes these ambiguous; give it one rule when one appears.
extension List where T: AnyObject {
    public func includes(_ value: T) -> Bool {
        return _data.contains { $0 === value }
    }

    public func indexOf(_ value: T) -> Double {
        return Double(_data.firstIndex { $0 === value } ?? -1)
    }
}

/// The placeholder `new Array<T>(length)` starts with.
/// shortcut: only the element types generated code sizes this way so far; add a conformance
/// (or make the slot optional) when another one appears.
public protocol JsArrayHole {
    static var hole: Self { get }
}

extension String: JsArrayHole {
    public static var hole: String { "" }
}

extension Double: JsArrayHole {
    public static var hole: Double { 0 }
}

extension Bool: JsArrayHole {
    public static var hole: Bool { false }
}

extension Optional: JsArrayHole {
    public static var hole: Wrapped? { nil }
}
