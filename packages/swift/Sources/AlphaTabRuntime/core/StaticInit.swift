// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

// Generated classes with a TS static initializer run it once through `jsStaticInit`. One recursive
// lock for all of them: a re-entrant call on the same thread (an initializer touching its own class,
// or another class's) goes through, and another thread waits until the whole initializer has run,
// instead of seeing the flag set and reading half-built statics (swift test runs tests in parallel).
private let staticInitLock = NSRecursiveLock()

public func jsStaticInit(_ body: () throws -> Void) rethrows {
    staticInitLock.lock()
    defer { staticInitLock.unlock() }
    try body()
}
