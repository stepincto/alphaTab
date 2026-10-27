// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import EmitterContextBase from '../EmitterContextBase';
import type * as cs from '../ir/Ir';

/**
 * Swift-specific emitter context, the twin of `KotlinEmitterContext`.
 * Holds `partialSuffixExpressions`, populated by `PartialsPass` and read
 * by `SwiftTargetStrategy.getClassName`.
 */
export default class SwiftEmitterContext extends EmitterContextBase {
    public readonly partialSuffixExpressions: Set<cs.Node> = new Set();
}
