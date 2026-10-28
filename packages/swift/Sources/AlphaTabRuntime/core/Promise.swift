// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

/// A promise object: what `loadFile(path).then(f).catch(g)` chains on and `Promise.withResolvers()` hands out
/// (the Kotlin runtime's `Deferred` with `then`/`catch`/`await`). One that is made from a computation starts it
/// at once, as in JS. Callbacks run on whichever thread settles the promise.
public final class Promise<T>: @unchecked Sendable {
    private enum State {
        case pending
        case fulfilled(UncheckedSendable<T>)
        case rejected(any Error)
    }

    private let lock = NSLock()
    private var state: State = .pending
    private var observers: [(Result<UncheckedSendable<T>, any Error>) -> Void] = []

    /// A promise nobody has settled yet (`Promise.withResolvers`).
    fileprivate init() {}

    /// A promise for what `body` returns or throws.
    public init(_ body: @escaping () async throws -> T) {
        nonisolated(unsafe) let body = body
        Task {
            do {
                self.settle(.success(UncheckedSendable(value: try await body())))
            } catch {
                self.settle(.failure(error))
            }
        }
    }

    fileprivate func settle(_ result: Result<UncheckedSendable<T>, any Error>) {
        lock.lock()
        guard case .pending = state else {
            lock.unlock()
            return
        }
        switch result {
        case .success(let value): state = .fulfilled(value)
        case .failure(let error): state = .rejected(error)
        }
        let waiting = observers
        observers = []
        lock.unlock()
        for observer in waiting {
            observer(result)
        }
    }

    private func observe(_ observer: @escaping (Result<UncheckedSendable<T>, any Error>) -> Void) {
        lock.lock()
        switch state {
        case .pending:
            observers.append(observer)
            lock.unlock()
        case .fulfilled(let value):
            lock.unlock()
            observer(.success(value))
        case .rejected(let error):
            lock.unlock()
            observer(.failure(error))
        }
    }

    /// JS `Promise.resolve(value)` in an `async` function, which awaits it at once: the value itself.
    public static func resolve(_ value: T) -> T {
        return value
    }

    /// JS `Promise.withResolvers()`.
    public static func withResolvers() -> PromiseWithResolvers<T> {
        return PromiseWithResolvers<T>()
    }

    /// Waits for the promise; a rejection is thrown.
    public func await() async throws -> T {
        let result: UncheckedSendable<T> = try await withCheckedThrowingContinuation { continuation in
            observe { continuation.resume(with: $0) }
        }
        return result.value
    }

    /// Runs `callback` with the value; an error it throws rejects the returned promise.
    public func then(_ callback: @escaping (T) throws -> Void) -> Promise<T> {
        let next = Promise<T>()
        nonisolated(unsafe) let callback = callback
        observe { result in
            switch result {
            case .success(let value):
                do {
                    try callback(value.value)
                    next.settle(.success(value))
                } catch {
                    next.settle(.failure(error))
                }
            case .failure(let error):
                next.settle(.failure(error))
            }
        }
        return next
    }

    /// Runs `callback` with the rejection; the returned promise stays rejected.
    public func `catch`(_ callback: @escaping (JsError) throws -> Void) -> Promise<T> {
        return `catch` { (reason: Any) in try callback((reason as? JsError) ?? JsError("\(reason)")) }
    }

    /// `.catch(e => ...)` with `e` untyped.
    public func `catch`(_ callback: @escaping (Any) throws -> Void) -> Promise<T> {
        let next = Promise<T>()
        nonisolated(unsafe) let callback = callback
        observe { result in
            switch result {
            case .success:
                next.settle(result)
            case .failure(let error):
                do {
                    try callback(error)
                    next.settle(.failure(error))
                } catch {
                    next.settle(.failure(error))
                }
            }
        }
        return next
    }
}

/// The result of `Promise.withResolvers()`.
public final class PromiseWithResolvers<T>: @unchecked Sendable {
    public let promise = Promise<T>()

    fileprivate init() {}

    public func resolve(_ value: T) {
        promise.settle(.success(UncheckedSendable(value: value)))
    }

    public func reject(_ reason: Any) {
        promise.settle(.failure((reason as? any Error) ?? JsError("Promise rejected with: \(reason)")))
    }
}
