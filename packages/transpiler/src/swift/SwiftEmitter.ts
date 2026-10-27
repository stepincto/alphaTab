// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import ts from 'typescript';
import AstTransformer from '../AstTransformer';
import { transpileFilter } from '../BuilderHelpers';
import * as cs from '../ir/Ir';
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

/**
 * Leaves out single `it(...)` cases, named `<path suffix>#<test name>` (`/test/importer/AlphaTexImporter.test.ts#grace`):
 * a test that needs a module the Swift target has not ported yet, in a file whose other tests run.
 */
function excludeTests(context: SwiftEmitterContext, excludedTests: string[]) {
    const visit = (node: cs.Node, fileName: string) => {
        if (cs.isMethodDeclaration(node) && node.isTestMethod && node.tsNode && ts.isCallExpression(node.tsNode)) {
            const name = node.tsNode.arguments[0];
            if (ts.isStringLiteralLike(name) && excludedTests.some(t => fileName.endsWith(t.split('#')[0]) && t.split('#')[1] === name.text)) {
                node.skipEmit = true;
            }
        }
        for (const m of (node as { members?: cs.Node[] }).members ?? []) {
            visit(m, fileName);
        }
    };
    for (const file of context.sourceFiles) {
        const fileName = (file.tsNode as ts.SourceFile).fileName.replaceAll('\\', '/');
        for (const d of file.namespace.declarations) {
            visit(d, fileName);
        }
    }
}

export default function createEmit(srcOutDir: string, testOutDir: string, excludedTests: string[] = []) {
    return (program: ts.Program, diagnostics: ts.Diagnostic[]) => {
        const context = new SwiftEmitterContext(program, srcOutDir, testOutDir, ctx => new SwiftTargetStrategy(ctx));

        console.log('[Swift] Transforming to Swift AST');
        for (const file of program.getRootFileNames().filter(transpileFilter)) {
            const sourceFile = program.getSourceFile(file)!;
            const transformer = new AstTransformer(sourceFile, context, SwiftLanguage);
            transformer.transform();
        }

        excludeTests(context, excludedTests);

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
