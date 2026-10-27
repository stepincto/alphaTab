// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Object` statics the generated code calls.
/// Not ported: `keys`/`entries` on objects (Kotlin reflects over getters), nothing in scope calls them yet.
public enum Object {
    /// `Object.values(SomeEnum)`: JS also yields the case names (strings); callers filter them out with
    /// `typeof k === "number"`, so only the numbers are returned, in declaration order as JS.
    public static func values<E: IAlphaTabEnum & CaseIterable>(_ type: E.Type) -> List<Any> {
        return List<Any>(contentsOf: E.allCases.map { Double($0.rawValue) as Any })
    }
}
