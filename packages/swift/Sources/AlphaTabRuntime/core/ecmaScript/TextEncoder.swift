// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// JS `TextEncoder`: always UTF-8 (WHATWG Encoding 8.2).
public final class TextEncoder {
    public init() {}

    public func encode(_ str: String) -> Uint8Array {
        return Uint8Array(Swift.Array(str.utf8))
    }
}
