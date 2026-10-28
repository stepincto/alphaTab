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
    new AsyncRewritePass(true),
    new PartialsPass(),
    new DoubleSuffixPass(),
    new RewriteVisibilitiesPass()
];

/**
 * Leaves out single `it(...)` cases, named `<path suffix>#<test name>` (`/test/importer/AlphaTexImporter.test.ts#grace`):
 * a test that needs a module the Swift target has not ported yet, in a file whose other tests run.
 * The name may carry its `describe` path, as vitest prints it (`parser > props > wrong type`), when the
 * bare name is not unique in the file; a bare name or a path suffix matches every test it ends.
 */
function testPath(call: ts.CallExpression): string {
    const names: string[] = [];
    for (let n: ts.Node | undefined = call; n; n = n.parent) {
        if (ts.isCallExpression(n) && n.arguments.length > 0 && ts.isStringLiteralLike(n.arguments[0])) {
            const callee = n.expression.getText();
            if (n === call || callee === 'describe') {
                names.unshift(n.arguments[0].text);
            }
        }
    }
    return names.join(' > ');
}

function excludeTests(context: SwiftEmitterContext, excludedTests: string[]) {
    const visit = (node: cs.Node, fileName: string) => {
        if (cs.isMethodDeclaration(node) && node.isTestMethod && node.tsNode && ts.isCallExpression(node.tsNode)) {
            const name = node.tsNode.arguments[0];
            const fullName = ts.isStringLiteralLike(name) ? testPath(node.tsNode) : '';
            if (
                fullName &&
                excludedTests.some(t => {
                    const [file, test] = t.split('#');
                    return fileName.endsWith(file) && (fullName === test || fullName.endsWith(` > ${test}`));
                })
            ) {
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

/**
 * Replaces the body of single methods with a trap, named `<path suffix>#<Class>.<method>` -> reason: a member of a
 * file that otherwise translates whose body needs a module the Swift target does not have (the audio synth in
 * a test facade). The signature stays, so the class still conforms to its interface.
 */
function stubMembers(context: SwiftEmitterContext, stubbedMembers: Record<string, string>) {
    const visit = (node: cs.Node, fileName: string, className: string) => {
        if (cs.isMethodDeclaration(node)) {
            for (const [key, reason] of Object.entries(stubbedMembers)) {
                const [file, member] = key.split('#');
                if (fileName.endsWith(file) && member === `${className}.${node.name}`) {
                    context.stubbedMethods.set(node, reason);
                }
            }
        }
        const name = cs.isClassDeclaration(node) ? node.name : className;
        for (const m of (node as { members?: cs.Node[] }).members ?? []) {
            visit(m, fileName, name);
        }
    };
    for (const file of context.sourceFiles) {
        const fileName = (file.tsNode as ts.SourceFile).fileName.replaceAll('\\', '/');
        for (const d of file.namespace.declarations) {
            visit(d, fileName, '');
        }
    }
}

export default function createEmit(
    srcOutDir: string,
    testOutDir: string,
    excludedTests: string[] = [],
    stubbedMembers: Record<string, string> = {}
) {
    return (program: ts.Program, diagnostics: ts.Diagnostic[]) => {
        const context = new SwiftEmitterContext(program, srcOutDir, testOutDir, ctx => new SwiftTargetStrategy(ctx));

        console.log('[Swift] Transforming to Swift AST');
        for (const file of program.getRootFileNames().filter(transpileFilter)) {
            const sourceFile = program.getSourceFile(file)!;
            const transformer = new AstTransformer(sourceFile, context, SwiftLanguage);
            transformer.transform();
        }

        excludeTests(context, excludedTests);
        stubMembers(context, stubbedMembers);

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
