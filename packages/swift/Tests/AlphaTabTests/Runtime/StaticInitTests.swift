// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
import Foundation
import Testing

/// The shape the emitter prints for a TS static initializer, raced from many threads.
private final class Racy {
    nonisolated(unsafe) static var done = false
    nonisolated(unsafe) static var values: [Int] = []
    nonisolated(unsafe) static var reentered = false

    static func staticInit() {
        jsStaticInit {
            if done { return }
            done = true
            for i in 0..<1000 { values.append(i) }
            staticInit() // re-entrant on the same thread: returns, no deadlock
            reentered = true
        }
    }

    static func count() -> Int {
        staticInit()
        return values.count
    }
}

@Suite struct StaticInitTests {
    @Test func otherThreadsWaitForTheWholeInitializer() {
        nonisolated(unsafe) var seen = [Int](repeating: -1, count: 16)
        DispatchQueue.concurrentPerform(iterations: 16) { i in seen[i] = Racy.count() }
        #expect(seen.allSatisfy { $0 == 1000 })
        #expect(Racy.reentered)
    }
}
