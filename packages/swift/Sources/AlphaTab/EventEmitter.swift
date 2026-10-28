// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: src/EventEmitter.ts is not generated. Its `off(value)` finds the listener with `l !== value`, and
// Swift closures have no identity (storing one in a generic container re-wraps it, so the stored one never
// equals the argument). Listeners get an id instead: `on` returns a closure that removes its own listener,
// which is how alphaTab itself unregisters. `off(value)` compares the closure's code and context pointers and
// so only finds a closure that was not re-wrapped on the way in; move to a token-based API when a caller needs it. A listener that throws reaches the
// `trigger` caller as in JS; one that throws while `on` replays the current value (`fireOnRegister`) is dropped.

/// An emitter for an event without any value passed to the listeners.
public protocol IEventEmitter: AnyObject {
    @discardableResult
    func on(_ value: @escaping () throws -> Void) -> () -> Void
    func off(_ value: @escaping () throws -> Void)
}

/// An emitter for an event with a single parameter passed to the listeners.
public protocol IEventEmitterOfT<T>: AnyObject {
    associatedtype T

    @discardableResult
    func on(_ value: @escaping (T) throws -> Void) -> () -> Void
    func off(_ value: @escaping (T) throws -> Void)
}

private func sameClosure<F>(_ a: F, _ b: F) -> Bool {
    guard MemoryLayout<F>.size == MemoryLayout<(Int, Int)>.size else {
        return false
    }
    let x = unsafeBitCast(a, to: (Int, Int).self)
    let y = unsafeBitCast(b, to: (Int, Int).self)
    return x.0 == y.0 && x.1 == y.1
}

internal final class EventEmitter: IEventEmitter {
    private var _listeners: [(id: Int, fn: () throws -> Void)] = []
    private var _nextId = 0
    private let _fireOnRegister: (() -> Bool)?

    public init(_ fireOnRegister: (() -> Bool)? = nil) {
        self._fireOnRegister = fireOnRegister
    }

    @discardableResult
    public func on(_ value: @escaping () throws -> Void) -> () -> Void {
        let id = self._nextId
        self._nextId += 1
        self._listeners.append((id: id, fn: value))
        if self._fireOnRegister?() == true {
            try? value()
        }
        return { [self] in
            self._listeners.removeAll { $0.id == id }
        }
    }

    public func off(_ value: @escaping () throws -> Void) {
        self._listeners.removeAll { sameClosure($0.fn, value) }
    }

    public func trigger() throws {
        for l in self._listeners {
            try l.fn()
        }
    }
}

internal final class EventEmitterOfT<T>: IEventEmitterOfT {
    private var _listeners: [(id: Int, fn: (T) throws -> Void)] = []
    private var _nextId = 0
    private let _fireOnRegister: (() -> T?)?

    public init(_ fireOnRegister: (() -> T?)? = nil) {
        self._fireOnRegister = fireOnRegister
    }

    @discardableResult
    public func on(_ value: @escaping (T) throws -> Void) -> () -> Void {
        let id = self._nextId
        self._nextId += 1
        self._listeners.append((id: id, fn: value))
        if let arg = self._fireOnRegister?() {
            try? value(arg)
        }
        return { [self] in
            self._listeners.removeAll { $0.id == id }
        }
    }

    public func off(_ value: @escaping (T) throws -> Void) {
        self._listeners.removeAll { sameClosure($0.fn, value) }
    }

    public func trigger(_ arg: T) throws {
        for l in self._listeners {
            try l.fn(arg)
        }
    }
}
