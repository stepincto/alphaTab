// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Testing

/// JS `Set` (ECMA-262 24.2): a reference type that iterates in insertion order.
@Suite struct SetTests {
    @Test func addHasSizeDeleteClear() {
        let s = AlphaTabRuntime.Set<Double>()
        s.add(1)
        s.add(1)
        s.add(2)
        #expect(s.size == 2)
        #expect(s.has(1))
        #expect(!s.has(3))
        #expect(s.delete(1))
        #expect(!s.delete(1))
        #expect(s.size == 1)
        s.clear()
        #expect(s.size == 0)
    }

    @Test func iteratesInInsertionOrder() {
        let s = AlphaTabRuntime.Set<Double>([5, 1, 3, 1])
        s.delete(5)
        s.add(5)
        #expect(Swift.Array(s) == [1, 3, 5])
        var seen: [Double] = []
        s.forEach { seen.append($0) }
        #expect(seen == [1, 3, 5])
    }

    @Test func isAReference() {
        let a = AlphaTabRuntime.Set<Double>()
        let b = a
        b.add(1)
        #expect(a.has(1))
    }

    /// JS Set compares objects by identity; model classes (Staff, SustainPedalMarker) are not Hashable.
    @Test func holdsNonHashableObjectsByIdentity() {
        final class Node {
            let v: Int
            init(_ v: Int) { self.v = v }
        }
        let a = Node(1)
        let b = Node(1)
        let s = AlphaTabRuntime.Set<Node>()
        s.add(a)
        s.add(a)
        s.add(b)
        #expect(s.size == 2)
        #expect(s.has(a))
        #expect(!s.has(Node(1)))
        #expect(s.delete(a))
        #expect(!s.has(a))
        s.add(a)
        #expect(Swift.Array(s).map { ObjectIdentifier($0) } == [ObjectIdentifier(b), ObjectIdentifier(a)])
    }

    @Test func unqualifiedSetIsTheRuntimeSet() {
        let s: Set<Double> = Set<Double>(nil as [Double]?)
        s.add(1)
        #expect(s.size == 1)
    }
}
