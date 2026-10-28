// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// A started asynchronous computation that callbacks chain on: what `loadFile(path).then(f).catch(g)` needs
/// (the Kotlin runtime's `Deferred.then`/`catch`). The computation starts when the promise is made, as in JS.
public final class Promise<T> {
    private let task: Task<UncheckedSendable<T>, any Error>

    public init(_ body: @escaping () async throws -> T) {
        nonisolated(unsafe) let body = body
        task = Task { UncheckedSendable(value: try await body()) }
    }

    /// JS `Promise.resolve(value)` in an `async` function, which awaits it at once: the value itself.
    public static func resolve(_ value: T) -> T {
        return value
    }

    /// Runs `callback` with the value; an error it throws rejects the returned promise.
    public func then(_ callback: @escaping (T) throws -> Void) -> Promise<T> {
        let previous = task
        nonisolated(unsafe) let callback = callback
        return Promise {
            let value = try await previous.value.value
            try callback(value)
            return value
        }
    }

    /// Runs `callback` with the rejection; the returned promise stays rejected.
    public func `catch`(_ callback: @escaping (JsError) throws -> Void) -> Promise<T> {
        return `catch` { (reason: Any) in try callback((reason as? JsError) ?? JsError("\(reason)")) }
    }

    /// `.catch(e => ...)` with `e` untyped.
    public func `catch`(_ callback: @escaping (Any) throws -> Void) -> Promise<T> {
        let previous = task
        nonisolated(unsafe) let callback = callback
        return Promise {
            do {
                return try await previous.value.value
            } catch {
                try callback(error)
                throw error
            }
        }
    }
}
