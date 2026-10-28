// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

/// alphaTab is single-threaded by contract; a value that crosses into a task or continuation goes as it is.
struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
}

/// Settles a `new Promise(...)` once: later `resolve`/`reject` calls are ignored, as in JS.
private final class PromiseSettler<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UncheckedSendable<T>, any Error>?

    init(_ continuation: CheckedContinuation<UncheckedSendable<T>, any Error>) {
        self.continuation = continuation
    }

    private func take() -> CheckedContinuation<UncheckedSendable<T>, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let c = continuation
        continuation = nil
        return c
    }

    func resolve(_ value: T) {
        take()?.resume(returning: UncheckedSendable(value: value))
    }

    func reject(_ reason: Any) {
        // the Kotlin runtime wraps a non-Error rejection the same way
        take()?.resume(throwing: (reason as? any Error) ?? JsError("Promise rejected with: \(reason)"))
    }
}

extension TypeHelper {
    /// `new Promise<T>((resolve, reject) => ...)`. The executor runs at once, as in JS; one that throws rejects.
    public static func createPromise<T>(
        _ action: (@escaping (T) -> Void, @escaping (Any) -> Void) throws -> Void
    ) async throws -> T {
        let result: UncheckedSendable<T> = try await withCheckedThrowingContinuation { continuation in
            let settler = PromiseSettler<T>(continuation)
            do {
                try action(settler.resolve, settler.reject)
            } catch {
                settler.reject(error)
            }
        }
        return result.value
    }

    /// `new Promise<void>((resolve, reject) => ...)`.
    public static func createPromise(
        _ action: (@escaping () -> Void, @escaping (Any) -> Void) throws -> Void
    ) async throws {
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UncheckedSendable<Void>, any Error>) in
            let settler = PromiseSettler<Void>(continuation)
            do {
                try action({ settler.resolve(()) }, settler.reject)
            } catch {
                settler.reject(error)
            }
        }
    }

    /// `new Promise<T>(resolve => ...)`: nothing to reject with, so it cannot fail.
    public static func createPromise<T>(_ action: (@escaping (T) -> Void) -> Void) async -> T {
        let result: UncheckedSendable<T> = await withCheckedContinuation { continuation in
            action { continuation.resume(returning: UncheckedSendable(value: $0)) }
        }
        return result.value
    }

    /// `new Promise<T>(resolve => ...)` whose executor throws: that rejects the promise.
    public static func createPromise<T>(_ action: (@escaping (T) -> Void) throws -> Void) async throws -> T {
        let result: UncheckedSendable<T> = try await withCheckedThrowingContinuation { continuation in
            let settler = PromiseSettler<T>(continuation)
            do {
                try action(settler.resolve)
            } catch {
                settler.reject(error)
            }
        }
        return result.value
    }
}
