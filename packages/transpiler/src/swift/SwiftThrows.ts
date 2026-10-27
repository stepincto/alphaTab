// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import ts from 'typescript';

/**
 * Which functions are Swift `throws`, over the whole program (TS has no checked exceptions).
 * A function throws when its body throws outside a `catch`, calls a throwing function outside
 * a `catch`, or is overridden or implemented by a throwing one (a Swift override cannot add
 * `throws`). Closures do not make their enclosing function throw.
 * shortcut: getters, setters and closures are never `throws`; give them effectful accessors or
 * throwing function types when alphaTab code needs them.
 */
export class SwiftThrows {
    private _throwing: Set<ts.Node> | undefined;

    public constructor(private readonly _program: ts.Program) {}

    public throws(declaration: ts.Node | undefined): boolean {
        return !!declaration && this._compute().has(declaration);
    }

    /** A call or `new` whose target throws. */
    public callThrows(call: ts.CallExpression | ts.NewExpression): boolean {
        return this.throws(this._program.getTypeChecker().getResolvedSignature(call)?.declaration);
    }

    /** `node` holds a throwing call outside any nested function. */
    public containsThrowingCall(node: ts.Node): boolean {
        const visit = (n: ts.Node): boolean => {
            if ((ts.isCallExpression(n) || ts.isNewExpression(n)) && this.callThrows(n)) {
                return true;
            }
            if (ts.isFunctionLike(n) || ts.isClassLike(n)) {
                return false;
            }
            return !!ts.forEachChild(n, c => visit(c) || undefined);
        };
        return visit(node);
    }

    private _compute(): Set<ts.Node> {
        if (this._throwing) {
            return this._throwing;
        }
        const checker = this._program.getTypeChecker();
        // `becomesThrowing.get(x)`: the functions that throw once `x` throws
        const becomesThrowing = new Map<ts.Node, ts.Node[]>();
        const edge = (from: ts.Node, to: ts.Node) => {
            let list = becomesThrowing.get(from);
            if (!list) {
                list = [];
                becomesThrowing.set(from, list);
            }
            list.push(to);
        };
        const seeds: ts.Node[] = [];

        const scanBody = (fn: ts.FunctionLikeDeclaration) => {
            let throws = false;
            const visit = (n: ts.Node) => {
                if (ts.isThrowStatement(n)) {
                    throws = true;
                } else if (ts.isCallExpression(n) || ts.isNewExpression(n)) {
                    const callee = checker.getResolvedSignature(n)?.declaration;
                    if (callee) {
                        edge(callee, fn);
                    }
                }
                if (ts.isFunctionLike(n) || ts.isClassLike(n)) {
                    return;
                }
                if (ts.isTryStatement(n) && n.catchClause) {
                    // the try block's throws are caught
                    visit(n.catchClause.block);
                    if (n.finallyBlock) {
                        visit(n.finallyBlock);
                    }
                    return;
                }
                ts.forEachChild(n, visit);
            };
            ts.forEachChild(fn.body!, visit);
            if (throws) {
                seeds.push(fn);
            }
        };

        const linkOverrides = (cls: ts.ClassLikeDeclaration, member: ts.MethodDeclaration) => {
            const name = member.name.getText();
            const classType = checker.getTypeAtLocation(cls);
            const bases: ts.Type[] = [...(classType.getBaseTypes?.() ?? [])];
            for (const clause of cls.heritageClauses ?? []) {
                if (clause.token === ts.SyntaxKind.ImplementsKeyword) {
                    for (const t of clause.types) {
                        bases.push(checker.getTypeAtLocation(t));
                    }
                }
            }
            for (const base of bases) {
                for (const d of base.getProperty(name)?.declarations ?? []) {
                    edge(member, d);
                }
            }
        };

        const visitDeclarations = (n: ts.Node) => {
            if ((ts.isMethodDeclaration(n) || ts.isConstructorDeclaration(n) || ts.isFunctionDeclaration(n)) && n.body) {
                scanBody(n);
            }
            if (ts.isMethodDeclaration(n) && ts.isClassLike(n.parent)) {
                linkOverrides(n.parent, n);
            }
            ts.forEachChild(n, visitDeclarations);
        };
        for (const file of this._program.getSourceFiles()) {
            if (!file.isDeclarationFile) {
                visitDeclarations(file);
            }
        }

        const throwing = new Set<ts.Node>();
        const queue = [...seeds];
        while (queue.length > 0) {
            const n = queue.pop()!;
            if (throwing.has(n)) {
                continue;
            }
            throwing.add(n);
            queue.push(...(becomesThrowing.get(n) ?? []));
        }
        this._throwing = throwing;
        return throwing;
    }
}
