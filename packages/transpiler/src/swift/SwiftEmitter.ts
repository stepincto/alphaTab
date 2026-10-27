// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import type ts from 'typescript';
import AstTransformer from '../AstTransformer';
import { transpileFilter } from '../BuilderHelpers';
import { AsyncRewritePass } from '../passes/AsyncRewritePass';
import { DoubleSuffixPass } from '../passes/DoubleSuffixPass';
import { type IrPass, PassPipeline } from '../passes/IrPass';
import { PartialsPass } from '../passes/PartialsPass';
import { RecordPostProcessPass } from '../passes/RecordPostProcessPass';
import { ResolveTypesPass } from '../passes/ResolveTypesPass';
import { RewriteVisibilitiesPass } from '../passes/RewriteVisibilitiesPass';
import { SmartCastLoweringPass } from '../passes/SmartCastLoweringPass';
import SwiftAstPrinter from './SwiftAstPrinter';
import SwiftEmitterContext from './SwiftEmitterContext';
import { SwiftLanguage } from './SwiftLanguage';
import SwiftTargetStrategy from './SwiftTargetStrategy';

/** Pass list applied after the Swift transformer runs and before the printer: the Kotlin list. */
const SWIFT_PASSES: readonly IrPass[] = [
    new ResolveTypesPass(),
    new RecordPostProcessPass(),
    new SmartCastLoweringPass(),
    new AsyncRewritePass(),
    new PartialsPass(),
    new DoubleSuffixPass(),
    new RewriteVisibilitiesPass()
];

export default function createEmit(srcOutDir: string, testOutDir: string) {
    return (program: ts.Program, diagnostics: ts.Diagnostic[]) => {
        const context = new SwiftEmitterContext(program, srcOutDir, testOutDir, ctx => new SwiftTargetStrategy(ctx));

        console.log('[Swift] Transforming to Swift AST');
        for (const file of program.getRootFileNames().filter(transpileFilter)) {
            const sourceFile = program.getSourceFile(file)!;
            const transformer = new AstTransformer(sourceFile, context, SwiftLanguage);
            transformer.transform();
        }

        const pipeline = new PassPipeline(SWIFT_PASSES, msg => console.log(`[Swift] ${msg}`));
        pipeline.run(context.sourceFiles, context);

        if (!context.hasErrors) {
            console.log('[Swift] Writing Result');
            for (const file of context.sourceFiles) {
                const printer = new SwiftAstPrinter(file, context);
                printer.print();
                diagnostics.push(...printer.diagnostics);
            }
        }

        diagnostics.push(...context.diagnostics);
    };
}
