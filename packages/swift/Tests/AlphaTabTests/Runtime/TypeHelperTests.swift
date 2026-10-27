// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import AlphaTabRuntime
import Testing

private final class Box {}

/// `TypeHelper.strictEquals` is JS `===` on two `unknown` values.
@Suite struct TypeHelperTests {
    @Test func strictEqualsPrimitivesByValue() {
        #expect(TypeHelper.strictEquals(nil, nil))
        #expect(!TypeHelper.strictEquals(nil, 0.0))
        #expect(TypeHelper.strictEquals(1.5, 1.5))
        #expect(TypeHelper.strictEquals(2, 2.0))
        #expect(!TypeHelper.strictEquals(Double.nan, Double.nan))
        #expect(TypeHelper.strictEquals("a", "a"))
        #expect(!TypeHelper.strictEquals("1", 1.0))
        #expect(TypeHelper.strictEquals(true, true))
        #expect(!TypeHelper.strictEquals(true, 1.0))
    }

    @Test func strictEqualsObjectsByReference() {
        let a = Box()
        #expect(TypeHelper.strictEquals(a, a))
        #expect(!TypeHelper.strictEquals(a, Box()))
        let optional: Any? = Optional<Box>.none
        #expect(TypeHelper.strictEquals(optional, nil))
    }

    @Test func unknownToListKeepsAnExactList() {
        let list = List<Double>(1.0, 2.0)
        #expect(TypeHelper.unknownToList(list, Double.self) === list)
    }

    @Test func unknownToListConvertsOptionalAndAnyElements() {
        let maps: Any? = List<Map<String, Any?>?>(Map<String, Any?>())
        #expect(TypeHelper.unknownToList(maps, Map<String, Any?>.self).length == 1.0)
        let any: Any? = List<Any?>(1.0, 2.0)
        #expect(Swift.Array(TypeHelper.unknownToList(any, Double.self)) == [1.0, 2.0])
    }

    @Test func unknownToNullableListKeepsNull() {
        let null: Any? = Optional<List<String>>.none
        #expect(TypeHelper.unknownToNullableList(null, String.self) == nil)
        let any: Any? = List<Any?>("a")
        #expect(TypeHelper.unknownToNullableList(any, String.self)?.length == 1.0)
    }

    @Test func unknownToInt64() {
        #expect(TypeHelper.unknownToInt64(Int64(42)) == 42)
        #expect(TypeHelper.unknownToInt64(7) == 7)
    }

    @Test func instanceofMapAndSetIgnoreTypeArguments() {
        let m: Any? = Map<String, Double>()
        let s: Any? = AlphaTabRuntime.Set<Double>()
        #expect(m is any _AnyMap)
        #expect(!(m is any _AnySet))
        #expect(s is any _AnySet)
    }
}
