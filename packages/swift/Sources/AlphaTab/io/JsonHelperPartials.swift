// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

/// Hand-written `@partial` members of `JsonHelper` (src/io/JsonHelper.ts), as Kotlin's
/// `alphaTab/io/JsonHelperPartials.kt`. JSON objects arrive as `Map<String, Any?>`.
/// Follows JS where Kotlin differs: numeric strings go through `parseInt` ("1px" -> 1).
internal enum JsonHelperPartials {
    static func forEach(_ o: Any?, _ fn: (Any?, String) -> Bool) {
        guard let m = unwrapAny(o) as? Map<String, Any?> else {
            return
        }
        for e in m {
            _ = fn(e.value, e.key)
        }
    }

    static func forEach(_ o: Any?, _ fn: (Any?, String) -> Void) {
        forEach(o, { (v: Any?, k: String) -> Bool in
            fn(v, k)
            return true
        })
    }

    static func getValue(_ o: Any?, _ k: String) -> Any? {
        guard let m = unwrapAny(o) as? Map<String, Any?> else {
            return nil
        }
        return m.get(k) ?? nil
    }

    /// JS returns the raw number for a value with no case; a Swift enum cannot hold one, so nil.
    /// Traps on a boolean or other non-object where JS throws: generated callers carry no `try`.
    static func parseEnum<E: IAlphaTabEnum & CaseIterable>(_ value: Any?, _ type: E.Type) -> E? {
        switch unwrapAny(value) {
        case nil:
            return nil
        case let e as E:
            return e
        case let s as String:
            let num = Number.parseInt(s, 10)
            if num.isNaN {
                let lower = s.lowercased()
                return E.allCases.first { String(describing: $0).lowercased() == lower }
            }
            return E(rawValue: num.toInt())
        case let d as Double:
            return E(rawValue: d.toInt())
        case let i as Int:
            return E(rawValue: i)
        case is Bool:
            fatalError("Could not parse enum value '\(String(describing: value))'")
        default:
            return nil // JS: typeof 'object'
        }
    }
}
