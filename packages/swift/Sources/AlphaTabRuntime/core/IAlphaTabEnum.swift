// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Every generated numeric enum: `public enum E: Int, IAlphaTabEnum, CaseIterable`.
/// Replaces Kotlin's `IAlphaTabEnum` plus `IAlphaTabEnumCompanion` (`CaseIterable` gives `allCases`).
/// `Comparable` because JS compares enums as numbers (`a > b`, `level >= Logger.logLevel`).
public protocol IAlphaTabEnum: RawRepresentable, Hashable, Comparable where RawValue == Int {}

extension IAlphaTabEnum {
    /// By value, not declaration order (Duration declares -4 before 1).
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// `n as E`. Traps on a value with no case: a Swift enum cannot hold one (JS and Kotlin flags can).
    public static func fromValue(_ value: Double) -> Self {
        guard let e = Self(rawValue: value.toInt()) else {
            fatalError("\(Self.self) has no case with value \(jsNumberToString(value))")
        }
        return e
    }

    public func toDouble() -> Double {
        return Double(rawValue)
    }

    public func toInt() -> Int {
        return rawValue
    }

    /// JS prints an enum as its number.
    public func toInvariantString() -> String {
        return String(rawValue)
    }

    public func toTemplate() -> String {
        return String(rawValue)
    }
}
