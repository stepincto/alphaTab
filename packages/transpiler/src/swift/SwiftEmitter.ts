// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import type ts from 'typescript';

/**
 * Swift target of the transpiler. Stub: emits nothing yet, so every
 * fixture with an expected.swift fails until the emitter is written (spec 027).
 */
export default function createEmit(_srcOutDir: string, _testOutDir: string) {
    return (_program: ts.Program, _diagnostics: ts.Diagnostic[]) => {};
}
