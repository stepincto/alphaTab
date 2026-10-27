// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

/// Hand-written stand-in for the TS '@target web' tuple union
/// `[types, parseMode] | [types, parseMode, allowedValues] | [types, parseMode, allowedValues, reservedIdentifiers]`
/// (as in the C# and Kotlin runtimes). `length` is the tuple length.
internal final class SimpleAlphaTexParameterDefinition {
    let length: Double
    let v0: List<AlphaTexNodeType>
    let v1: ArgumentListParseTypesMode
    let v2: List<String>?
    let v3: List<String>?

    init(_ types: List<AlphaTexNodeType>, _ parseMode: ArgumentListParseTypesMode) {
        v0 = types
        v1 = parseMode
        v2 = nil
        v3 = nil
        length = 2
    }

    init(_ types: List<AlphaTexNodeType>, _ parseMode: ArgumentListParseTypesMode, _ allowedValues: List<String>?) {
        v0 = types
        v1 = parseMode
        v2 = allowedValues
        v3 = nil
        length = 3
    }

    init(
        _ types: List<AlphaTexNodeType>,
        _ parseMode: ArgumentListParseTypesMode,
        _ allowedValues: List<String>?,
        _ reservedIdentifiers: List<String>?
    ) {
        v0 = types
        v1 = parseMode
        v2 = allowedValues
        v3 = reservedIdentifiers
        length = 4
    }
}
