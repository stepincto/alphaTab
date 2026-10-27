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

    @Test func entriesArePairsInInsertionOrder() {
        let m = Map<Double, String>((2, "b"), (1, "a"))
        let e = Array.from(m.entries())
        #expect(e.length == 2)
        #expect(e[0].0 == 2 && e[0].1 == "b")
        #expect(e[1].0 == 1 && e[1].1 == "a")
    }

    private final class Obj {
        let n: Double
        init(_ n: Double) { self.n = n }
    }

    /// JS Map keys objects by identity: two distinct instances are two keys, the same instance is one.
    @Test func keysClassInstancesByIdentity() {
        let a = Obj(1)
        let b = Obj(1)
        let m = Map<Obj, String>()
        m.set(a, "a")
        m.set(b, "b")
        m.set(a, "a2")
        #expect(m.size == 2)
        #expect(m.get(a) == "a2")
        #expect(m.get(b) == "b")
        #expect(m.has(Obj(1)) == false)
        #expect(m.delete(b))
        #expect(m.keys().length == 1 && m.keys()[0] === a)
        let r = Record<Obj, Double>()
        r.set(a, 1)
        #expect(r.get(a) == 1)
    }
}
