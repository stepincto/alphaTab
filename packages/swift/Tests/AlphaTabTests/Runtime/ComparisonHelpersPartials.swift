// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
@testable import AlphaTab
import AlphaTabRuntime

// The hand-written half of test/model/ComparisonHelpers.ts (Kotlin's ComparisonHelpersPartialsImpl.kt).

enum ComparisonHelpersPartials {
    /// `@partial @target web` `compareObjects`. Kotlin compares its DoubleList here; Swift's lists are
    /// `List<T>` and already go through `Array.isArray`, so anything left is unexpected, as in the JS.
    @discardableResult
    static func compareObjects(_ expected: Any?, _ actual: Any?, _ path: String, _ ignoreKeys: List<String>?) throws -> Bool {
        throw JsError("Cannot compare unknown object types on path \(path)")
    }
}
