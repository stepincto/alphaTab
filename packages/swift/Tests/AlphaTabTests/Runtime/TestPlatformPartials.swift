// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Foundation

/// The hand-written `@partial` members of test/TestPlatform.ts (Kotlin's TestPlatformPartialsImpl.kt),
/// only those the generated code calls.
enum TestPlatformPartials {
    /// `packages/alphatab`: vitest runs there, so the tests' relative paths (`test-data/...`) start there.
    private static let projectRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Runtime/
        .deletingLastPathComponent() // AlphaTabTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // swift/
        .deletingLastPathComponent() // packages/
        .appendingPathComponent("alphatab")

    private static func resolve(_ path: String) -> URL {
        return path.hasPrefix("/") ? URL(fileURLWithPath: path) : projectRoot.appendingPathComponent(path)
    }

    /// The generated callers carry no `try` (JS rejects the promise), so a missing file traps with its path.
    static func loadFileSync(_ path: String) -> Uint8Array {
        guard let data = try? Data(contentsOf: resolve(path)) else {
            fatalError("TestPlatform.loadFile: cannot read \(resolve(path).path)")
        }
        return Uint8Array([UInt8](data))
    }

    static func loadFile(_ path: String) async -> Uint8Array {
        return loadFileSync(path)
    }

    /// The files (not directories) in `path`, sorted by name: Node's `readdir` order on the file systems
    /// alphaTab's CI uses, and stable across runs.
    static func listDirectory(_ path: String) async -> List<String> {
        let url = resolve(path)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            fatalError("TestPlatform.listDirectory: cannot read \(url.path)")
        }
        let files = names.filter { name in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
        return List<String>(contentsOf: files.sorted())
    }

    private final class Debounce: @unchecked Sendable {
        private let lock = NSLock()
        private var pending: Task<Void, Never>?

        func call(_ action: @escaping () throws -> Void, after delay: Double) {
            nonisolated(unsafe) let action = action
            lock.lock()
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000))
                if !Task.isCancelled {
                    try? action()
                }
            }
            lock.unlock()
        }
    }

    /// Debounce, as Kotlin's `throttle`: every call restarts the delay and only the last one runs.
    static func throttle(_ action: @escaping () throws -> Void, _ delay: Double) -> () -> Void {
        let debounce = Debounce()
        return { debounce.call(action, after: delay) }
    }

    static func typedArrayAsUnknownArray(_ array: Any?) -> List<Any?> {
        return List<Any?>(contentsOf: jsElements(array) ?? [])
    }

    static func typedArrayAsUnknownIterable(_ array: Any?) -> any Sequence<Any?> {
        return jsElements(array) ?? []
    }

    static func setAsUnknownIterable(_ set: Any?) -> any Sequence<Any?> {
        return jsElements(set) ?? []
    }

    static func mapAsUnknownIterable(_ map: Any?) -> any Sequence<(Any?, Any?)> {
        return (unwrapAny(map) as? any _AnyMapEntries)?._anyEntries ?? []
    }

    /// JS `val.constructor.name`.
    static func getConstructorName(_ val: Any?) -> String {
        return unwrapAny(val).map { String(describing: type(of: $0)) } ?? "Object"
    }
}
