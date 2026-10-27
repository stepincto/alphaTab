// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.


import AlphaTabRuntime
import Testing

/// JS `Error.prototype.toString` (ECMA-262 20.5.3.4): "Error: message", or just "Error" when the message is empty.
@Suite struct ErrorTests {
    @Test func toStringWithMessage() {
        #expect(JsError("bad input").toString() == "Error: bad input")
    }

    @Test func toStringWithoutMessage() {
        #expect(JsError().toString() == "Error")
    }

    /// A TS subclass overriding `toString` (AlphaTexErrorWithDiagnostics) is generated in another module,
    /// so the override must work across the module boundary and dispatch dynamically.
    @Test func subclassOverridesToStringAcrossModules() {
        let error: JsError = CustomToStringError("x")
        #expect(error.toString() == "custom: x")
    }
}

private final class CustomToStringError: JsError {
    override func toString() -> String {
        return "custom: \(message)"
    }
}
