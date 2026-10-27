// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

@testable import AlphaTab
import AlphaTabRuntime
import Foundation

// The hand-written halves of test/PrettyFormat.ts (Kotlin's ScoreSerializerPluginPartials.kt).

/// `@partial @target web` `test`: the JS duck-types on `'nodeType' in arg0`.
extension AlphaTexAstNodePlugin {
    func test(_ arg0: Any?) -> Bool {
        return unwrapAny(arg0) is AlphaTexAstNode
    }
}

/// `@partial @target web` `test`: the JS duck-types on `'severity' in arg0`.
extension AlphaTexDiagnosticPlugin {
    func test(_ arg0: Any?) -> Bool {
        return unwrapAny(arg0) is AlphaTexDiagnostic
    }
}

enum ScoreSerializerPluginPartials {
    /// Lists (Kotlin's DoubleList/BooleanList) are handled by `Array.isArray` in Swift; like the JS,
    /// anything else in the serialized JSON is unexpected.
    static func _isPlatformTypeEqual(_ v: Any?, _ dv: Any?) throws -> Bool {
        throw JsError("Unexpected value in serialized json \(String(describing: v))")
    }
}

/// The members of test/TestPlatform.ts that PrettyFormat uses.
/// shortcut: TestPlatform.ts is outside the transpile filter (its file IO); delete this stand-in when the
/// tier that generates TestPlatform lands.
enum TestPlatform {
    static func loadFileAsStringSync(_ path: String) -> String {
        // a missing .snap is reported before loading (Snapshot.match), so this only fails on unreadable files
        return (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
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

/// Lets an untyped value be iterated as a `Map` of any key and value type.
protocol _AnyMapEntries {
    var _anyEntries: [(Any?, Any?)] { get }
}

extension Map: _AnyMapEntries {
    var _anyEntries: [(Any?, Any?)] {
        return map { ($0.0 as Any?, $0.1 as Any?) }
    }
}

/// `unknown[].includes`: SameValueZero, which `jsSame` implements (NaN equals NaN, objects by identity).
extension List where T == Any? {
    func includes(_ value: Any?) -> Bool {
        return contains { jsSame($0, value) }
    }
}

extension Object {
    /// JS `Object.entries` on a class instance: its stored fields, base class fields first.
    /// shortcut: Swift field names (a private `_x`) stand in for JS property names; only reached for
    /// values no PrettyFormat plugin handles.
    static func entries(_ val: Any) -> List<(String, Any)> {
        var mirrors: [Mirror] = []
        var mirror: Mirror? = Mirror(reflecting: val)
        while let m = mirror {
            mirrors.insert(m, at: 0)
            mirror = m.superclassMirror
        }
        let entries = mirrors.flatMap { m in m.children.compactMap { c in c.label.map { ($0, c.value) } } }
        return List<(String, Any)>(contentsOf: entries)
    }
}
