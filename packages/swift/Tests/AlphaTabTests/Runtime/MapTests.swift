// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `Map` (ECMA-262 24.1): built from `[k, v]` pairs, iterated as `[k, v]` pairs in insertion order.
@Suite struct MapTests {
    @Test func buildsFromAnArrayOfPairs() {
        let m = Map<String, Double>([("a", 1), ("b", 2), ("a", 3)])
        #expect(m.size == 2)
        #expect(m.get("a") == 3)
    }

    @Test func iteratesPairsInInsertionOrder() {
        let m = Map<String, Double>(("b", 1), ("a", 2))
        m.set("b", 5)
        var keys: [String] = []
        var values: [Double] = []
        for (k, v) in m {
            keys.append(k)
            values.append(v)
        }
        #expect(keys == ["b", "a"])
        #expect(values == [5, 2])
        let copy = Map<String, Double>(m)
        #expect(copy.get("a") == 2)
    }
}
