// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import type ts from 'typescript';
import EmitterContextBase from '../EmitterContextBase';
import type * as cs from '../ir/Ir';
import { SwiftThrows } from './SwiftThrows';

/**
 * Swift-specific emitter context, the twin of `KotlinEmitterContext`.
 * Holds `partialSuffixExpressions`, populated by `PartialsPass` and read
 * by `SwiftTargetStrategy.getClassName`.
 */
export default class SwiftEmitterContext extends EmitterContextBase {
    public readonly partialSuffixExpressions: Set<cs.Node> = new Set();
    /** Methods whose body the printer replaces with a trap (`createEmit`'s `stubbedMembers`), with the reason. */
    public readonly stubbedMethods: Map<cs.Node, string> = new Map();
    private _throws: SwiftThrows | undefined;
    private readonly _tsProgram: ts.Program;

    public constructor(...args: ConstructorParameters<typeof EmitterContextBase>) {
        super(...args);
        this._tsProgram = args[0];
    }

    /** Whole-program `throws` analysis, built on first use. */
    public get throwsAnalysis(): SwiftThrows {
        this._throws ??= new SwiftThrows(this._tsProgram);
        return this._throws;
    }
}
