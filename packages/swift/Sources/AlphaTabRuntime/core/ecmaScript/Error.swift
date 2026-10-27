// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `Error` (Kotlin: `typealias Error = Throwable`). `throw new Error(m)` -> `throw JsError(m)`;
/// classes extending `Error` extend this. `@unchecked Sendable`: `Swift.Error` requires `Sendable`,
/// and an open class with a mutable `message` cannot prove it; alphaTab throws on one thread.
open class JsError: Swift.Error, @unchecked Sendable, CustomStringConvertible {
    public var message: String
    public var cause: (any Swift.Error)?

    public init(_ message: String = "", _ cause: (any Swift.Error)? = nil) {
        self.message = message
        self.cause = cause
    }

    open var description: String {
        return message.isEmpty ? "Error" : "Error: \(message)"
    }
}
