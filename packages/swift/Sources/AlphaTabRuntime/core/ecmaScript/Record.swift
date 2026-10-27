// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// TS `Record<K, V>`, a `Map` as in Kotlin: `Record<String, Double>(("alice", 95.0), ("bob", 80.0))`.
/// Inherits `Map`'s initializers.
public final class Record<TKey, TValue>: Map<TKey, TValue> {}
