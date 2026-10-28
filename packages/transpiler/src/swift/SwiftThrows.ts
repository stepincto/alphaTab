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
 * `throws`). A closure that throws makes the call it is passed to throw (the callee must be
 * `rethrows`, as the runtime's callback helpers are). A function value passed as an argument
 * (closure, method reference, function-typed value) makes the parameter's function type throw
 * when it throws, and a call through a throwing function type throws.
 * A function value stored in a declared function type (a field, a typed local, an assignment) makes
 * that type throw too.
 * shortcut: getters and setters are never `throws`; a closure nested in a literal (`new Map([[k, () => x]])`)
 * is not tracked, so its throwing calls trap (`try!`).
 */
export class SwiftThrows {
    private _throwing: Set<ts.Node> | undefined;

    public constructor(private readonly _program: ts.Program) {}

    public throws(declaration: ts.Node | undefined): boolean {
        return !!declaration && this._compute().has(declaration);
    }

    /** A call or `new` whose target throws. */
    public callThrows(call: ts.CallExpression | ts.NewExpression): boolean {
        if (this.throws(this._program.getTypeChecker().getResolvedSignature(call)?.declaration)) {
            return true;
        }
        // a throwing function argument: the callee rethrows (runtime helpers are `rethrows`)
        return (call.arguments ?? []).some(a => this._functionValues(a).some(f => this.throws(f)));
    }

    /** The declaration behind a function type (`(v: T) => U`, also through a type alias). */
    public functionTypeOf(type: ts.Type | undefined): ts.FunctionTypeNode | undefined {
        const signatures = type?.getNonNullableType().getCallSignatures() ?? [];
        const d = signatures.length === 1 ? signatures[0].declaration : undefined;
        return d && ts.isFunctionTypeNode(d) ? d : undefined;
    }

    /**
     * What a function-valued expression stands for in the graph: a closure itself, a referenced
     * method or function (`PrettyFormat.printer`), or the function type of a function-typed value.
     */
    private _functionValues(e: ts.Expression): ts.Node[] {
        while (ts.isParenthesizedExpression(e)) {
            e = e.expression;
        }
        if (SwiftThrows._isClosure(e)) {
            return [e];
        }
        if (!ts.isIdentifier(e) && !ts.isPropertyAccessExpression(e)) {
            return [];
        }
        const checker = this._program.getTypeChecker();
        const d = checker.getSymbolAtLocation(e)?.valueDeclaration;
        if (d && (ts.isMethodDeclaration(d) || ts.isFunctionDeclaration(d))) {
            return [d];
        }
        if (d && ts.isVariableDeclaration(d) && !d.type && d.initializer && SwiftThrows._isClosure(d.initializer)) {
            // a local holding a closure: `const f = (x) => ...; g(f)`
            return [d.initializer];
        }
        const t = this.functionTypeOf(checker.getTypeAtLocation(e));
        return t ? [t] : [];
    }

    /**
     * `EventEmitter.trigger`: not generated (the runtime has its own, whose listeners may throw and whose
     * `trigger` rethrows, as a JS listener error reaches the code that raised the event), so its callers throw.
     */
    private static _isEventTrigger(fn: ts.Node): boolean {
        return (
            ts.isMethodDeclaration(fn) &&
            fn.name.getText() === 'trigger' &&
            ts.isClassDeclaration(fn.parent) &&
            fn.getSourceFile().fileName.endsWith('/src/EventEmitter.ts')
        );
    }

    private static _isClosure(n: ts.Node): n is ts.ArrowFunction | ts.FunctionExpression {
        return ts.isArrowFunction(n) || ts.isFunctionExpression(n);
    }

    /**
     * A TS `x!` or `x as T` that can fail at run time, printed as the runtime's throwing
     * `jsNonNull(x)` / `jsCast(x, T.self)`: JS throws a TypeError where the value is then used,
     * C# and Kotlin throw at the cast or deref; Swift's `!`/`as!` would trap the process instead.
     * Not where it cannot fail: an operand TS already knows is non-null (declared or narrowed),
     * an upcast, or a cast TS narrowed (`instanceof`). Not where Swift cannot throw: an accessor,
     * a property initializer, a static initializer, or a closure not passed as an argument (its
     * function type is not tracked); those keep the trapping `!`/`as!`.
     */
    public isThrowingAssertion(n: ts.Node): boolean {
        const checker = this._program.getTypeChecker();
        if (ts.isNonNullExpression(n)) {
            if (n.flags & ts.NodeFlags.OptionalChain || SwiftThrows._isWriteTarget(n)) {
                // `a?.b!.c` unwraps only when `a` is set; `x! = v` assigns
                return false;
            }
            const t = checker.getTypeAtLocation(n.expression);
            const parts = t.isUnion() ? t.types : [t];
            if (!parts.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined)))) {
                return false;
            }
        } else if (ts.isAsExpression(n) || ts.isTypeAssertionExpression(n)) {
            if (ts.isConstTypeReference(n.type)) {
                return false;
            }
            const source = checker.getTypeAtLocation(n.expression);
            const target = checker.getTypeFromTypeNode(n.type);
            if (
                source.flags & (ts.TypeFlags.Any | ts.TypeFlags.Unknown) ||
                target.isUnion() ||
                !(target.flags & ts.TypeFlags.Object) ||
                !(target.symbol && target.symbol.flags & (ts.SymbolFlags.Class | ts.SymbolFlags.Interface)) ||
                checker.isArrayType(target) ||
                checker.isTupleType(target) ||
                checker.isTypeAssignableTo(source, target)
            ) {
                return false;
            }
        } else {
            return false;
        }
        return this._canThrowHere(n);
    }

    /**
     * `lazy.value` on alphaTab's `Lazy`: the runtime's `value` is `get throws`, since its factory
     * (a closure passed to `new Lazy(...)`) may throw and JS lets that error reach the reader.
     */
    public isThrowingRead(n: ts.Node): boolean {
        if (!ts.isPropertyAccessExpression(n) || n.name.text !== 'value') {
            return false;
        }
        const d = this._program.getTypeChecker().getSymbolAtLocation(n.name)?.valueDeclaration;
        return (
            !!d &&
            ts.isGetAccessorDeclaration(d) &&
            ts.isClassDeclaration(d.parent) &&
            d.parent.name?.text === 'Lazy' &&
            d.getSourceFile().fileName.endsWith('/util/Lazy.ts')
        );
    }

    /**
     * `xs[i].m` on a list, inside a function that already throws: the runtime's throwing
     * `xs.jsElement(i).m`, where JS reads `undefined` and throws a TypeError on the member access
     * (Kotlin throws IndexOutOfBoundsException). shortcut: elsewhere (a read not dereferenced, or in a
     * function that does not throw) an out-of-range read still traps; it seeds no `throws`, so the
     * output does not grow. Widen it when a test needs such a read caught.
     */
    public isThrowingElementRead(n: ts.Node): boolean {
        if (!ts.isElementAccessExpression(n) || n.questionDotToken) {
            return false;
        }
        let e: ts.Node = n;
        while (ts.isParenthesizedExpression(e.parent)) {
            e = e.parent;
        }
        if (!ts.isPropertyAccessExpression(e.parent) || e.parent.expression !== e || SwiftThrows._isWriteTarget(e.parent)) {
            return false;
        }
        const checker = this._program.getTypeChecker();
        if (!checker.isArrayType(checker.getNonNullableType(checker.getTypeAtLocation(n.expression)))) {
            return false;
        }
        let fn: ts.Node | undefined = n.parent;
        while (fn && !ts.isFunctionLike(fn)) {
            fn = fn.parent;
        }
        return this._canThrowHere(n) && this.throws(fn);
    }

    private static _isWriteTarget(n: ts.Node): boolean {
        let e: ts.Node = n;
        while (ts.isParenthesizedExpression(e.parent)) {
            e = e.parent;
        }
        const p = e.parent;
        return (
            (ts.isBinaryExpression(p) && p.left === e && p.operatorToken.kind >= ts.SyntaxKind.FirstAssignment && p.operatorToken.kind <= ts.SyntaxKind.LastAssignment) ||
            ((ts.isPrefixUnaryExpression(p) || ts.isPostfixUnaryExpression(p)) &&
                (p.operator === ts.SyntaxKind.PlusPlusToken || p.operator === ts.SyntaxKind.MinusMinusToken))
        );
    }

    /**
     * A closure whose `throws` reaches its Swift type: an argument (the callee rethrows), a local
     * initialised with it (the printed type comes from the closure), or one whose contextual type
     * is a declared function type (that type prints `throws`).
     */
    public isTrackedClosure(c: ts.ArrowFunction | ts.FunctionExpression): boolean {
        let e: ts.Node = c;
        while (ts.isParenthesizedExpression(e.parent)) {
            e = e.parent;
        }
        const p = e.parent;
        if ((ts.isCallExpression(p) || ts.isNewExpression(p)) && !!p.arguments?.includes(e as ts.Expression)) {
            return true;
        }
        if (ts.isVariableDeclaration(p) && p.initializer === e && !p.type) {
            return true;
        }
        return !!this.functionTypeOf(this._program.getTypeChecker().getContextualType(c));
    }

    /** The nearest enclosing body is one the analysis can make `throws`. */
    private _canThrowHere(n: ts.Node): boolean {
        for (let p = n.parent; p; p = p.parent) {
            if (SwiftThrows._isClosure(p)) {
                return this.isTrackedClosure(p);
            }
            if (ts.isMethodDeclaration(p) || ts.isConstructorDeclaration(p) || ts.isFunctionDeclaration(p)) {
                return !!p.body;
            }
            if (ts.isFunctionLike(p) || ts.isPropertyDeclaration(p) || ts.isClassStaticBlockDeclaration(p) || ts.isClassLike(p)) {
                return false;
            }
        }
        return false;
    }

    /** `node` holds a throwing call outside any nested function. */
    public containsThrowingCall(node: ts.Node): boolean {
        const visit = (n: ts.Node): boolean => {
            if (((ts.isCallExpression(n) || ts.isNewExpression(n)) && this.callThrows(n)) || this.isThrowingAssertion(n) || this.isThrowingRead(n) || this.isThrowingElementRead(n)) {
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
                if (ts.isThrowStatement(n) || this.isThrowingAssertion(n) || this.isThrowingRead(n)) {
                    throws = true;
                } else if (ts.isCallExpression(n) || ts.isNewExpression(n)) {
                    const callee = checker.getResolvedSignature(n)?.declaration;
                    if (callee) {
                        edge(callee, fn);
                    }
                    for (const a of n.arguments ?? []) {
                        // a function value passed on: the call rethrows it, and the parameter's
                        // function type throws once the value does
                        const target = this.functionTypeOf(checker.getContextualType(a));
                        for (const f of this._functionValues(a)) {
                            edge(f, fn);
                            if (target && target !== f) {
                                edge(f, target);
                            }
                        }
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
            const body = fn.body!;
            if (ts.isBlock(body)) {
                ts.forEachChild(body, visit);
            } else {
                visit(body);
            }
            if (throws || SwiftThrows._isEventTrigger(fn)) {
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
                    // Swift wants the same `throws` on a function-typed parameter of the requirement and its implementation
                    if (ts.isMethodDeclaration(d) || ts.isMethodSignature(d)) {
                        member.parameters.forEach((p, i) => {
                            const other = d.parameters[i];
                            const a = this.functionTypeOf(checker.getTypeAtLocation(p));
                            const b = other ? this.functionTypeOf(checker.getTypeAtLocation(other)) : undefined;
                            if (a && b && a !== b) {
                                edge(a, b);
                                edge(b, a);
                            }
                        });
                    }
                }
            }
        };

        const visitDeclarations = (n: ts.Node) => {
            if (
                (ts.isMethodDeclaration(n) || ts.isConstructorDeclaration(n) || ts.isFunctionDeclaration(n) || SwiftThrows._isClosure(n)) &&
                n.body
            ) {
                scanBody(n);
            }
            if (ts.isMethodDeclaration(n) && ts.isClassLike(n.parent)) {
                linkOverrides(n.parent, n);
            }
            // a function value stored in a declared function type (`this._f = f`, `x: F = f`) makes that type throw
            const stored =
                ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.EqualsToken
                    ? [n.left, n.right]
                    : (ts.isVariableDeclaration(n) || ts.isPropertyDeclaration(n)) && n.type && n.initializer
                      ? [n.name, n.initializer]
                      : undefined;
            if (stored) {
                const target = this.functionTypeOf(checker.getTypeAtLocation(stored[0]));
                for (const f of target ? this._functionValues(stored[1] as ts.Expression) : []) {
                    if (f !== target) {
                        edge(f, target!);
                    }
                }
            }
            // an object literal field typed as a function type (`{ renderCallback: callback }`, a record literal)
            if (ts.isPropertyAssignment(n) || ts.isShorthandPropertyAssignment(n)) {
                const value = ts.isPropertyAssignment(n) ? n.initializer : n.name;
                const target = this.functionTypeOf(checker.getContextualType(value));
                for (const f of target ? this._functionValues(value) : []) {
                    if (f !== target) {
                        edge(f, target!);
                    }
                }
            }
            if (SwiftThrows._isClosure(n)) {
                // a closure stored in a declared function type (a field, a map value) makes that type throw
                const target = this.functionTypeOf(checker.getContextualType(n));
                if (target) {
                    edge(n, target);
                }
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
