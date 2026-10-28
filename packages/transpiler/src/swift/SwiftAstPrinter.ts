// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
import * as ts from 'typescript';
import AstPrinterBase from '../AstPrinterBase';
import type EmitterContextBase from '../EmitterContextBase';
import * as cs from '../ir/Ir';
import type SwiftEmitterContext from './SwiftEmitterContext';

/**
 * Prints the IR as Swift, following `packages/swift/CONVENTIONS.md`.
 * Modelled on `KotlinAstPrinter`; the IR and passes are Kotlin's.
 */
export default class SwiftAstPrinter extends AstPrinterBase {
    private _forceInteger: boolean = false;
    private _currentType: cs.NamedTypeDeclaration | undefined = undefined;
    // pending step expressions of enclosing C-style `for` loops (see writeContinueStatement)
    private _forLoopIncrementors: (cs.Expression | undefined)[] = [];

    protected override _context: EmitterContextBase;

    public constructor(sourceFile: cs.SourceFile, context: EmitterContextBase) {
        super(sourceFile, context);
        this._context = context;
    }

    private static readonly _keywords: Set<string> = new Set<string>(
        (
            'associatedtype class deinit enum extension fileprivate func import init inout internal let open ' +
            'operator private precedencegroup protocol public rethrows static struct subscript typealias var ' +
            'break case catch continue default defer do else fallthrough for guard if in repeat return throw ' +
            'switch where while Any as false is nil self Self super throws true try'
        ).split(' ')
    );

    protected override escapeIdentifier(identifier: string): string {
        if (SwiftAstPrinter._keywords.has(identifier)) {
            return `\`${identifier}\``;
        }
        return identifier;
    }

    protected override writeLine(txt?: string) {
        if (!txt && this._isStartOfLine) {
            // blank lines carry no indentation
            const self = this as unknown as { _source: string };
            self._source += ts.sys.newLine;
            return;
        }
        super.writeLine(txt);
    }

    /** Swift has one flat module: `alphaTab.core.TypeHelper` -> `TypeHelper`, `kotlin.X` -> `X`. */
    private _unqualify(name: string): string {
        return name.replace(/^(?:[a-z][A-Za-z0-9]*\.)+(?=[A-Z_])/, '');
    }

    protected override writeIdentifier(expr: cs.Identifier | string) {
        let name: string;
        if (typeof expr !== 'string') {
            name = this._context.getSymbolName(expr) ?? expr.text;
        } else {
            name = expr;
        }
        if (name.startsWith('alphaTab.') || name.startsWith('kotlin.')) {
            this.write(this._unqualify(name));
        } else {
            if (typeof expr !== 'string') {
                this._writeTestClassQualifier(expr);
            }
            this.write(this.escapeIdentifier(name));
        }
        if (typeof expr !== 'string' && this._isNarrowedNullableLocal(expr)) {
            this.write('!');
        }
    }

    /** A `describe` callback's local became a static of its test class: Swift needs `Helpers.helper`. */
    private _writeTestClassQualifier(expr: cs.Identifier) {
        if (!expr.tsNode || !ts.isIdentifier(expr.tsNode)) {
            return;
        }
        const declaration = this._context.typeChecker.getSymbolAtLocation(expr.tsNode)?.valueDeclaration;
        if (!declaration || !(ts.isVariableDeclaration(declaration) || ts.isFunctionDeclaration(declaration))) {
            return;
        }
        for (let t: cs.Node | null | undefined = this._currentType; t && this._isTestClass(t); t = t.parent) {
            const owner = t as cs.ClassDeclaration;
            if (owner.members.some(m => (m as { isStatic?: boolean }).isStatic && m.tsNode === declaration)) {
                this.write(`${this._testClassName(owner)}.`);
                return;
            }
        }
    }

    /** A `T | null` local that TS narrowed to `T` here: Swift does not smart-cast, so it needs `!`. */
    private _isNarrowedNullableLocal(expr: cs.Identifier): boolean {
        const tsNode = expr.tsNode;
        // the shared transformer builds `TypeHelper` for `isTruthy(x)` on x's TS node: it is not x
        if (!tsNode || !ts.isIdentifier(tsNode) || tsNode.text !== expr.text) {
            return false;
        }
        const parent = tsNode.parent;
        if (
            parent &&
            ts.isBinaryExpression(parent) &&
            parent.left === tsNode &&
            parent.operatorToken.kind >= ts.SyntaxKind.FirstAssignment &&
            parent.operatorToken.kind <= ts.SyntaxKind.LastAssignment
        ) {
            return false;
        }
        const checker = this._context.typeChecker;
        // `{ note }`: the name's own symbol is the object literal's property, the local is its value
        const symbol =
            parent && ts.isShorthandPropertyAssignment(parent) && parent.name === tsNode
                ? checker.getShorthandAssignmentValueSymbol(parent)
                : checker.getSymbolAtLocation(tsNode);
        const declaration = symbol?.valueDeclaration;
        if (!declaration || !ts.isVariableDeclaration(declaration) || !declaration.type) {
            return false;
        }
        const declared = checker.getTypeFromTypeNode(declaration.type);
        const narrowed = checker.getTypeAtLocation(tsNode);
        const isNullable = (t: ts.Type) => t.isUnion() && t.types.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined)));
        return isNullable(declared) && !isNullable(narrowed) && !(narrowed.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined));
    }

    // ── file ──────────────────────────────────────────────────────────────

    private _importsVitest(sourceFile: cs.SourceFile): boolean {
        const tsFile = sourceFile.tsNode as ts.SourceFile | undefined;
        return !!tsFile?.statements.some(
            s => ts.isImportDeclaration(s) && ts.isStringLiteral(s.moduleSpecifier) && s.moduleSpecifier.text === 'vitest'
        );
    }

    private _importsLibrary(sourceFile: cs.SourceFile): boolean {
        const tsFile = sourceFile.tsNode as ts.SourceFile | undefined;
        if (!tsFile?.fileName.includes('/test/')) {
            return false;
        }
        const checker = this._context.typeChecker;
        return tsFile.statements.some(s => {
            if (!ts.isImportDeclaration(s)) {
                return false;
            }
            const target = checker.getSymbolAtLocation(s.moduleSpecifier)?.valueDeclaration?.getSourceFile().fileName;
            return !!target && !target.includes('/test/') && !target.includes('/node_modules/');
        });
    }

    protected writeSourceFile(sourceFile: cs.SourceFile) {
        this.writeLine('// <auto-generated>');
        this.writeLine('// This code was auto-generated.');
        this.writeLine('// Changes to this file may cause incorrect behavior and will be lost if');
        this.writeLine('// the code is regenerated.');
        this.writeLine('// </auto-generated>');
        this.writeLine();
        const hasTests = sourceFile.namespace.declarations.some(d => this._isTestClass(d));
        // a test helper that calls vitest's `expect` reports through Swift Testing's macros too
        if (hasTests || this._importsVitest(sourceFile)) {
            this.writeLine('import Testing');
        }
        // a test helper without a describe (ComparisonHelpers) still names AlphaTab's types when it imports them
        if (hasTests || this._importsLibrary(sourceFile)) {
            this.writeLine('@testable import AlphaTab');
        }
        this.writeLine('import AlphaTabRuntime');

        for (const d of sourceFile.namespace.declarations) {
            if (d.skipEmit) {
                continue;
            }
            this.writeLine();
            this.writeMember(d);
        }
    }

    /** Writes a member without the base class's trailing blank line. */
    protected override writeMember(member: cs.Node) {
        switch (member.nodeType) {
            case cs.SyntaxKind.FieldDeclaration:
                this.writeFieldDeclarat1on(member as cs.FieldDeclaration);
                break;
            case cs.SyntaxKind.PropertyDeclaration:
                this.writePropertyDeclaration(member as cs.PropertyDeclaration);
                break;
            case cs.SyntaxKind.ConstructorDeclaration:
                this.writeConstructorDeclaration(member as cs.ConstructorDeclaration);
                break;
            case cs.SyntaxKind.MethodDeclaration:
                this.writeMethodDeclaration(member as cs.MethodDeclaration);
                break;
            case cs.SyntaxKind.ClassDeclaration:
                this.writeClassDeclaration(member as cs.ClassDeclaration);
                break;
            case cs.SyntaxKind.EnumDeclaration:
                this.writeEnumDeclaration(member as cs.EnumDeclaration);
                break;
            case cs.SyntaxKind.InterfaceDeclaration:
                this.writeInterfaceDeclaration(member as cs.InterfaceDeclaration);
                break;
            case cs.SyntaxKind.DelegateDeclaration:
                this.writeDelegateDeclaration(member as cs.DelegateDeclaration);
                break;
        }
    }

    /** Members of a type body, one blank line between them. */
    private _writeMembers(members: cs.Node[]) {
        let first = true;
        for (const m of members) {
            if (m.skipEmit) {
                continue;
            }
            if (!first) {
                this.writeLine();
            }
            first = false;
            this.writeMember(m);
        }
    }

    private _openBrace() {
        this.writeLine(' {');
        this._indent++;
    }

    private _closeBrace(newLine: boolean = true) {
        this._indent--;
        if (newLine) {
            this.writeLine('}');
        } else {
            this.write('}');
        }
    }

    protected writeDocumentation(d: cs.DocumentedElement) {
        if (d.documentation && d.documentation.trim().length > 0) {
            this.writeLine('/**');
            for (const line of d.documentation.split('\n')) {
                this.writeLine(` * ${line.replaceAll('/*', '/\\*')}`.trimEnd());
            }
            this.writeLine(' */');
        }
    }

    /** The transform's attribute names (Kotlin's) map onto Swift attributes; any other is dropped. */
    protected writeAttribute(a: cs.Attribute): void {
        const name = cs.isTypeReference(a.type) && typeof a.type.reference === 'string' ? a.type.reference : '';
        const arg = a.arguments?.[0];
        const writeArg = () => this.writeExpression(arg!);
        // toTypeNameCase capitalises the transform's names (`available` -> `Available`)
        switch (name.substring(name.lastIndexOf('.') + 1).toLowerCase()) {
            case 'available':
                this.write('@available(*, deprecated');
                if (arg && cs.isStringLiteral(arg) && arg.text.length > 0) {
                    this.write(', message: ');
                    writeArg();
                }
                this.writeLine(')');
                break;
            case 'testclass':
                this.write('@Suite(');
                writeArg();
                this.writeLine(')');
                break;
            case 'testname':
                this.write('@Test(');
                writeArg();
                this.writeLine(')');
                break;
        }
    }

    /** A nested `describe('X')` class takes a `Suite` suffix, or it would shadow a model type `X` in its tests. */
    private _testClassName(d: cs.ClassDeclaration): string {
        return this._isTestClass(d.parent) ? `${d.name}Suite` : d.name;
    }

    /** A `describe(...)` class: Swift Testing wants it internal, its tests `async throws`. */
    private _isTestClass(d: cs.Node | null | undefined): boolean {
        return !!d && cs.isClassDeclaration(d) && !!d.tsNode && ts.isCallExpression(d.tsNode);
    }

    // ── declarations ──────────────────────────────────────────────────────

    private _isOpen(d: cs.ClassDeclaration) {
        return d.isAbstract || d.hasVirtualMembersOrSubClasses;
    }

    private _writeTypeVisibility(visibility: cs.Visibility) {
        switch (visibility) {
            case cs.Visibility.Public:
                this.write('public ');
                break;
            case cs.Visibility.Private:
                this.write('private ');
                break;
            case cs.Visibility.Protected:
            case cs.Visibility.Internal:
                this.write('internal ');
                break;
        }
    }

    protected override writeVisibility(visibility: cs.Visibility) {
        this._writeTypeVisibility(visibility);
    }

    protected writeClassDeclaration(d: cs.ClassDeclaration) {
        const previousType = this._currentType;
        this._currentType = d;
        this.writeDocumentation(d);
        this.writeAttributes(d);

        if (this._isTestClass(d)) {
            this.write('final class ');
        } else if (d.isStatic) {
            // a static-only wrapper (`<File>Globals`) is a caseless enum: no instances
            this._writeTypeVisibility(d.visibility);
            this.write('enum ');
        } else if (this._isOpen(d)) {
            if (d.visibility === cs.Visibility.Public) {
                this.write('open ');
            } else {
                this._writeTypeVisibility(d.visibility);
            }
            this.write('class ');
        } else {
            this._writeTypeVisibility(d.visibility);
            this.write('final class ');
        }
        this.writeIdentifier(this._isTestClass(d) ? this._testClassName(d) : d.name);
        this.writeTypeParameters(d.typeParameters);

        const heritage: cs.TypeNode[] = [];
        if (d.baseClass) {
            heritage.push(d.baseClass);
        }
        if (d.interfaces) {
            heritage.push(...d.interfaces.filter(i => !(d.isRecord && d.baseClass && this._isRecordInterface(i))));
        }
        if (heritage.length > 0) {
            this.write(': ');
            this.writeCommaSeparated(heritage, t => this._writeConformance(t, t === d.baseClass));
        }
        this._openBrace();

        const members = d.members.filter(m => !m.skipEmit);
        const hasConstructor = members.some(m => cs.isConstructorDeclaration(m) && !m.isStatic);
        this._writeMembers(members);

        if (!hasConstructor && !d.isStatic) {
            if (members.length > 0) {
                this.writeLine();
            }
            this._writeDefaultConstructor(d);
        }

        this._closeBrace();
        this._currentType = previousType;
    }

    /** A heritage entry: a protocol is named without type arguments (`: Container`), its associated type is inferred. */
    private _isRecordInterface(t: cs.TypeNode) {
        return cs.isTypeReference(t) && typeof t.reference === 'string' && t.reference.endsWith('.IRecord');
    }

    private _writeConformance(t: cs.TypeNode, isBaseClass: boolean) {
        const type = !isBaseClass && cs.isTypeReference(t) && t.typeArguments ? ({ ...t, typeArguments: undefined } as cs.TypeReference) : t;
        // a protocol in an inheritance clause is never an existential: `Iterable<T>` -> `Sequence`
        this.write(this._capture(() => this._writeType(type, { existential: false })).replace(/^any /, ''));
    }

    /** `[Symbol.iterator]()` of a class that implements Iterable: Sequence needs a concrete iterator type. */
    private _isSequenceIterator(m: cs.Node | null): boolean {
        if (!m || !cs.isMethodDeclaration(m) || (m as cs.MethodDeclaration).name !== 'makeIterator' || !m.parent || !cs.isClassDeclaration(m.parent)) {
            return false;
        }
        return !!m.parent.interfaces?.some(i => this._captureType(i).startsWith('any Sequence'));
    }

    /** The superclass's `init` this class inherits from, or [] for its implicit `init()`; undefined without a superclass. */
    private _baseConstructorParameters(d: cs.ClassDeclaration): cs.ParameterDeclaration[] | undefined {
        if (!d.baseClass) {
            return undefined;
        }
        let baseClass: cs.TypeReferenceType | undefined = cs.isTypeReference(d.baseClass)
            ? d.baseClass.reference
            : d.baseClass;
        while (baseClass && typeof baseClass !== 'string' && cs.isClassDeclaration(baseClass)) {
            const ctor = baseClass.members.find(m => cs.isConstructorDeclaration(m) && !m.isStatic) as
                | cs.ConstructorDeclaration
                | undefined;
            if (ctor) {
                return ctor.parameters;
            }
            baseClass =
                baseClass.baseClass && cs.isTypeReference(baseClass.baseClass)
                    ? baseClass.baseClass.reference
                    : undefined;
        }
        return [];
    }

    private _writeDefaultConstructor(d: cs.ClassDeclaration) {
        const baseParameters = this._baseConstructorParameters(d);
        if (baseParameters === undefined) {
            this.writeLine(this._isTestClass(d) ? 'init() {}' : 'public init() {}');
            return;
        }
        this.write('public override init');
        this.writeParameters(baseParameters);
        this._openBrace();
        this.write('super.init(');
        this.writeCommaSeparated(baseParameters, p => this.writeIdentifier(p.name));
        this.writeLine(')');
        this._closeBrace();
    }

    private _parameterSignature(parameters: cs.ParameterDeclaration[]): string {
        return parameters
            .map(p => (p.type ? this._captureType(p.type) : '') + (p.params ? '...' : ''))
            .join(',');
    }

    private _captureType(t: cs.TypeNode): string {
        return this._capture(() => this.writeType(t));
    }

    /** Runs `write` against a scratch buffer and returns what it printed. */
    private _capture(write: () => void): string {
        const self = this as unknown as { _source: string; _isStartOfLine: boolean };
        const source = self._source;
        const isStartOfLine = self._isStartOfLine;
        self._source = '';
        self._isStartOfLine = false;
        try {
            write();
            return self._source;
        } finally {
            self._source = source;
            self._isStartOfLine = isStartOfLine;
        }
    }

    protected writeInterfaceDeclaration(d: cs.InterfaceDeclaration) {
        const previousType = this._currentType;
        this._currentType = d;
        this.writeDocumentation(d);
        this.writeAttributes(d);
        this._writeTypeVisibility(d.visibility);
        this.write('protocol ');
        this.writeIdentifier(d.name);
        this.writeTypeParameters(d.typeParameters);
        this.write(': ');
        if (d.interfaces && d.interfaces.length > 0) {
            this.writeCommaSeparated(d.interfaces, i => this._writeConformance(i, false));
        } else {
            this.write('AnyObject');
        }
        this._openBrace();

        const members: cs.Node[] = d.members.filter(m => !m.skipEmit);
        if (d.typeParameters && d.typeParameters.length > 0) {
            for (const p of d.typeParameters) {
                this.write('associatedtype ');
                this.writeIdentifier(p.name);
                if (p.constraint) {
                    this.write(': ');
                    this._writeType(p.constraint, { existential: false });
                }
                this.writeLine();
            }
            if (members.length > 0) {
                this.writeLine();
            }
        }
        this._writeMembers(members);
        this._closeBrace();
        this._writeProtocolDefaults(d, members);
        this._currentType = previousType;
    }

    /** Protocol requirements take no defaults: one extension overload per omissible trailing parameter. */
    private _writeProtocolDefaults(d: cs.InterfaceDeclaration, members: cs.Node[]) {
        const methods = members.filter(
            (m): m is cs.MethodDeclaration =>
                cs.isMethodDeclaration(m) && m.parameters.some(p => p.isOptional || !!p.initializer)
        );
        if (methods.length === 0) {
            return;
        }
        this.writeLine();
        this._writeTypeVisibility(d.visibility);
        this.write('extension ');
        this.writeIdentifier(d.name);
        this._openBrace();
        let first = true;
        for (const m of methods) {
            const params = m.parameters;
            let required = params.length;
            while (required > 0 && (params[required - 1].isOptional || !!params[required - 1].initializer)) {
                required--;
            }
            for (let n = required; n < params.length; n++) {
                if (!first) {
                    this.writeLine();
                }
                first = false;
                const kept = params.slice(0, n);
                this.write('func ');
                this.writeIdentifier(m.name);
                this.writeTypeParameters(m.typeParameters);
                this.write('(');
                this.writeCommaSeparated(kept, p => this.writeParameter(p), false);
                this.write(')');
                const isAsync = m.isAsync || this._returnsPromise(m);
                const throws = this._throws(m);
                if (isAsync) {
                    this.write(' async');
                }
                if (throws) {
                    this.write(' throws');
                }
                const isVoid = this._isVoid(m.returnType);
                if (!isVoid) {
                    this.write(' -> ');
                    this._writeReturnType(m.returnType, m);
                }
                this._openBrace();
                this.write(`${isVoid ? '' : 'return '}${throws ? 'try ' : ''}${isAsync ? 'await ' : ''}`);
                this.writeIdentifier(m.name);
                this.write('(');
                this.writeCommaSeparated(
                    params,
                    p => {
                        if (params.indexOf(p) < n) {
                            this.writeIdentifier(p.name);
                        } else if (p.initializer) {
                            this.writeExpression(p.initializer);
                        } else {
                            this.write('nil');
                        }
                    },
                    false
                );
                this.writeLine(')');
                this._closeBrace();
            }
        }
        this._closeBrace();
    }

    protected writeEnumDeclaration(d: cs.EnumDeclaration) {
        const previousType = this._currentType;
        this._currentType = d;
        this._forceInteger = true;
        this.writeDocumentation(d);
        this._writeTypeVisibility(d.visibility);
        this.write('enum ');
        this.writeIdentifier(d.name);
        this.write(': Int, IAlphaTabEnum, CaseIterable');
        this._openBrace();

        let next = 0;
        for (const m of d.members) {
            this.writeDocumentation(m);
            let value: number = next;
            const tsMember = m.tsNode;
            if (tsMember && ts.isEnumMember(tsMember)) {
                const constant = this._context.typeChecker.getConstantValue(tsMember);
                if (typeof constant === 'number') {
                    value = constant;
                }
            }
            this.write('case ');
            this.writeIdentifier(m.name);
            this.writeLine(` = ${value}`);
            next = value + 1;
        }

        this._closeBrace();
        this._forceInteger = false;
        this._currentType = previousType;
    }

    protected writeDelegateDeclaration(d: cs.DelegateDeclaration) {
        this.writeDocumentation(d);
        this._writeTypeVisibility(d.visibility);
        this.write('typealias ');
        this.write(d.name);
        this.writeTypeParameters(d.typeParameters);
        this.write(' = (');
        this.writeCommaSeparated(d.parameters, p => this.writeType(p.type!));
        this.write(this._functionTypeThrows(d.tsNode) ? ') throws -> ' : ') -> ');
        this._writeReturnType(d.returnType);
        this.writeLine();
    }

    protected override writeTypeParameter(p: cs.TypeParameterDeclaration) {
        this.writeIdentifier(p.name);
        if (p.constraint && cs.isPrimitiveTypeNode(p.constraint) && p.constraint.type === cs.PrimitiveType.Double) {
            // `T extends number`: alphaTab binds it to enums; Swift cannot constrain to a struct
            this.write(': IAlphaTabEnum');
        } else if (p.constraint) {
            this.write(': ');
            this._writeType(p.constraint, { existential: false });
        }
    }

    // ── members ───────────────────────────────────────────────────────────

    private _isInProtocol(d: cs.Node) {
        return !!d.parent && cs.isInterfaceDeclaration(d.parent);
    }

    /** `override` only where a superclass member is overridden (TS also marks `toString`/`equals`). */
    private _isRealOverride(d: { isOverride: boolean; parent: cs.Node | null; name?: string }) {
        if (!d.isOverride || !d.parent || !cs.isClassDeclaration(d.parent) || !d.parent.baseClass) {
            return false;
        }
        // TS marks a member that implements an interface member as an override too; Swift needs a superclass member
        let base: cs.TypeReferenceType | undefined = cs.isTypeReference(d.parent.baseClass)
            ? d.parent.baseClass.reference
            : d.parent.baseClass;
        while (base && typeof base !== 'string' && cs.isClassDeclaration(base)) {
            if (base.members.some(m => (m as { name?: string }).name === d.name)) {
                return true;
            }
            base = base.baseClass && cs.isTypeReference(base.baseClass) ? base.baseClass.reference : undefined;
        }
        // a superclass outside this program (runtime): keep the override
        return base !== undefined;
    }

    private _writeMemberModifiers(
        d: cs.MemberDeclaration & { isVirtual: boolean; isAbstract: boolean; isOverride: boolean }
    ) {
        if ((d.isVirtual || d.isAbstract) && d.visibility === cs.Visibility.Public && !d.isStatic) {
            this.write('open ');
        } else {
            this.writeVisibility(d.visibility);
        }
        if (d.isStatic) {
            this.write('static ');
        }
        if (this._isRealOverride(d)) {
            this.write('override ');
        }
    }

    protected writeMethodDeclaration(d: cs.MethodDeclaration) {
        this.writeDocumentation(d);
        this.writeAttributes(d);
        const inProtocol = this._isInProtocol(d);
        if (!inProtocol && !d.isTestMethod) {
            this._writeMemberModifiers(d);
        }

        this.write('func ');
        this.writeIdentifier(d.name);
        this.writeTypeParameters(d.typeParameters);
        this.writeParameters(d.parameters);
        if (d.isTestMethod) {
            this.write(' async throws');
        } else if (d.isAsync || this._returnsPromise(d)) {
            this.write(' async');
        }
        if (!d.isTestMethod && this._throws(d)) {
            this.write(' throws');
        }
        if (this._isSequenceIterator(d)) {
            // `any IteratorProtocol<T>` does not conform to IteratorProtocol: type-erase it
            this.write(` -> ${this._captureType(d.returnType).replace(/^any IteratorProtocol/, 'AnyIterator')}`);
        } else if (!this._isVoid(d.returnType)) {
            this.write(' -> ');
            this._writeReturnType(d.returnType, d);
        }

        if (inProtocol) {
            this.writeLine();
            return;
        }

        const stubReason = (this._context as SwiftEmitterContext).stubbedMethods.get(d);
        if (stubReason !== undefined || d.isAbstract || !d.body) {
            this._openBrace();
            this.writeLine(`fatalError(${JSON.stringify(stubReason ?? 'abstract')})`);
            this._closeBrace();
            return;
        }

        if (d.isGeneratorFunction) {
            this._openBrace();
            this.writeLine(this._throws(d) ? 'return try generator { yield in' : 'return generator { yield in');
            this._indent++;
            for (const s of cs.isBlock(d.body) ? d.body.statements : []) {
                this.writeStatement(s);
            }
            this._indent--;
            this.writeLine('}');
            this._closeBrace();
            return;
        }

        this._writeBody(d.body, d.isStatic && this._hasStaticInitializer(d.parent as cs.ClassDeclaration));
    }

    /** The class has a static constructor (TS module statements or `static {}`). */
    private _hasStaticInitializer(cls: cs.Node | undefined): boolean {
        return (
            !!cls &&
            cs.isClassDeclaration(cls) &&
            cls.members.some(m => cs.isConstructorDeclaration(m) && m.isStatic && !m.skipEmit)
        );
    }

    /**
     * Swift has no static initializer: its body runs once from `_staticInit()`, which each static
     * method and `init` call first. The flag is set before the body so a re-entrant call returns;
     * the runtime's `jsStaticInit` lock makes other threads wait until the body has run.
     * shortcut: static properties read directly from outside the class do not trigger it; route
     * them through an accessor once a generated class needs that.
     */
    private _writeStaticInitializer(d: cs.ConstructorDeclaration) {
        this.writeLine('nonisolated(unsafe) private static var _staticInitDone: Bool = false');
        this.writeLine();
        this.writeLine('/// TS module statements and `static {}`: run once, before the first static call or `init`.');
        this.write('private static func _staticInit()');
        this._openBrace();
        this.write('jsStaticInit');
        this._openBrace();
        this.write('if Self._staticInitDone');
        this._openBrace();
        this.writeLine('return');
        this._closeBrace();
        this.writeLine('Self._staticInitDone = true');
        if (d.body && cs.isBlock(d.body)) {
            // the body runs inside the runtime's non-throwing lock closure: a throwing call traps (`try!`)
            this._inStaticInit = true;
            try {
                for (const s of d.body.statements) {
                    this.writeStatement(s);
                }
            } finally {
                this._inStaticInit = false;
            }
        }
        this._closeBrace();
        this._closeBrace();
    }

    private _inStaticInit = false;

    /** A TS function that returns a `Promise` without `async`: Swift makes it `async`, its returns `await`. */
    private _returnsPromise(d: cs.MethodDeclaration): boolean {
        const tsNode = d.tsNode;
        // `@async` (Kotlin's `Deferred`) needs nothing here: a Swift `async` function is already awaited by its callers
        if (!tsNode || !ts.isFunctionLike(tsNode)) {
            return false;
        }
        const checker = this._context.typeChecker;
        const signature = checker.getSignatureFromDeclaration(tsNode as ts.SignatureDeclaration);
        return !!signature && checker.getReturnTypeOfSignature(signature).symbol?.name === 'Promise';
    }

    /** A function type some throwing function value is passed into (`SwiftThrows`). */
    private _functionTypeThrows(tsNode: ts.Node | undefined): boolean {
        const analysis = (this._context as SwiftEmitterContext).throwsAnalysis;
        // a local typed by its closure initializer: `const f = () => ...`
        const closure = tsNode && ts.isVariableDeclaration(tsNode) && !tsNode.type ? tsNode.initializer : tsNode;
        if (closure && (ts.isArrowFunction(closure) || ts.isFunctionExpression(closure))) {
            return analysis.throws(closure);
        }
        if (tsNode && ts.isVariableDeclaration(tsNode) && !tsNode.type) {
            // `const f = this.f`: the type of what it copies
            return analysis.throws(analysis.functionTypeOf(this._context.typeChecker.getTypeAtLocation(tsNode)));
        }
        let t: ts.Node | undefined = tsNode;
        if (t && !ts.isFunctionTypeNode(t) && 'type' in t) {
            t = (t as { type?: ts.Node }).type;
        }
        return !!t && ts.isFunctionTypeNode(t) && (this._context as SwiftEmitterContext).throwsAnalysis.throws(t);
    }

    /** `throws` per the whole-program analysis (`SwiftThrows`). */
    private _throws(d: cs.MethodDeclaration | cs.ConstructorDeclaration): boolean {
        // `[Symbol.dispose]` runs from a `defer`, which cannot throw: its body traps where JS would throw (see _inAccessor)
        if (cs.isMethodDeclaration(d) && d.name === 'dispose') {
            return false;
        }
        return (this._context as SwiftEmitterContext).throwsAnalysis.throws(d.tsNode);
    }

    /**
     * A statement-level expression holding a throwing call: one `try` in front covers it all
     * (Swift rejects `try` right of a binary operator, and `&&`, `??` are rethrowing autoclosures).
     */
    private _needsTry(expr: cs.Expression): boolean {
        const parent = expr.parent;
        if (!parent || !expr.tsNode || !SwiftAstPrinter._tryRoots.has(parent.nodeType)) {
            return false;
        }
        if (cs.isLambdaExpression(parent) && parent.body !== expr) {
            return false;
        }
        return (this._context as SwiftEmitterContext).throwsAnalysis.containsThrowingCall(expr.tsNode);
    }

    private static readonly _tryRoots = new Set<cs.SyntaxKind>([
        cs.SyntaxKind.ExpressionStatement,
        cs.SyntaxKind.ReturnStatement,
        cs.SyntaxKind.VariableDeclaration,
        cs.SyntaxKind.IfStatement,
        cs.SyntaxKind.WhileStatement,
        cs.SyntaxKind.DoStatement,
        cs.SyntaxKind.ForStatement,
        cs.SyntaxKind.ForEachStatement,
        cs.SyntaxKind.SwitchStatement,
        cs.SyntaxKind.ThrowStatement,
        cs.SyntaxKind.LambdaExpression,
        // an initializer cannot throw: `_inAccessor` makes it `try!`, a trap where JS would throw
        cs.SyntaxKind.PropertyDeclaration
    ]);

    protected override writeExpression(expr: cs.Expression) {
        if (this._needsTry(expr)) {
            // Swift accessors cannot throw: trap there, where JS would throw
            this.write(this._inAccessor(expr) ? 'try! ' : 'try ');
        }
        if (expr.tsNode && !this._upcastNodes.has(expr.tsNode) && this._needsSequenceUpcast(expr)) {
            this._upcastNodes.add(expr.tsNode);
            // `any Sequence<Derived>` is not an `any Sequence<any Protocol>` in Swift: convert element-wise
            this.write('jsUpcastSequence(');
            super.writeExpression(expr);
            this.write(')');
            return;
        }
        super.writeExpression(expr);
    }

    /**
     * An array or iterable passed or returned as an `Iterable<Base>` of another element type than its own
     * (`ContinuationTieGlyph[]` as `Iterable<ITieGlyph>`).
     */
    private _needsSequenceUpcast(expr: cs.Expression): boolean {
        const tsNode = expr.tsNode;
        const parent = tsNode?.parent;
        if (
            !tsNode ||
            !parent ||
            ts.isArrayLiteralExpression(tsNode) ||
            !(((ts.isCallExpression(parent) || ts.isNewExpression(parent)) && parent.arguments?.some(a => a === tsNode)) || ts.isReturnStatement(parent))
        ) {
            return false;
        }
        const checker = this._context.typeChecker;
        const target = ts.isReturnStatement(parent) ? this._returnTypeOfEnclosing(parent) : checker.getContextualType(tsNode as ts.Expression);
        if (!target || target.getSymbol()?.name !== 'Iterable') {
            return false;
        }
        const targetElement = checker.getTypeArguments(target as ts.TypeReference)[0];
        const source = checker.getTypeAtLocation(tsNode);
        let sourceElement: ts.Type | undefined;
        if (checker.isArrayType(source)) {
            sourceElement = checker.getTypeArguments(source as ts.TypeReference)[0];
        } else if (source.getSymbol()?.name === 'Iterable') {
            sourceElement = checker.getTypeArguments(source as ts.TypeReference)[0];
        }
        return (
            !!targetElement &&
            !!sourceElement &&
            targetElement !== sourceElement &&
            !(targetElement.flags & (ts.TypeFlags.Any | ts.TypeFlags.Unknown | ts.TypeFlags.TypeParameter)) &&
            !!targetElement.getSymbol() &&
            (targetElement.getSymbol()!.flags & ts.SymbolFlags.Interface) !== 0
        );
    }

    private _returnTypeOfEnclosing(node: ts.Node): ts.Type | undefined {
        for (let p: ts.Node | undefined = node; p; p = p.parent) {
            if (ts.isFunctionLike(p)) {
                const signature = this._context.typeChecker.getSignatureFromDeclaration(p);
                return signature ? this._context.typeChecker.getReturnTypeOfSignature(signature) : undefined;
            }
        }
        return undefined;
    }

    /** Swift cannot make this body `throws`: an accessor, an initializer, a static initializer, or an untracked closure. */
    private _inAccessor(n: cs.Node): boolean {
        if (this._deferDepth > 0) {
            return true;
        }
        for (let p = n.parent; p; p = p.parent) {
            if (cs.isPropertyAccessorDeclaration(p) || cs.isPropertyDeclaration(p)) {
                return true;
            }
            if (cs.isLambdaExpression(p)) {
                // a closure whose `throws` cannot reach its Swift type (`SwiftThrows.isTrackedClosure`)
                const c = p.tsNode;
                return !!c && (ts.isArrowFunction(c) || ts.isFunctionExpression(c)) && !(this._context as SwiftEmitterContext).throwsAnalysis.isTrackedClosure(c);
            }
            if (cs.isMethodDeclaration(p) && p.name === 'dispose') {
                return true;
            }
            if (cs.isMethodDeclaration(p) || cs.isConstructorDeclaration(p) || p.nodeType === cs.SyntaxKind.LocalFunction) {
                return this._inStaticInit;
            }
        }
        return this._inStaticInit;
    }

    protected override writeReturnStatement(r: cs.ReturnStatement) {
        let p: cs.Node | null = r.parent;
        while (p && !cs.isMethodDeclaration(p) && !cs.isLambdaExpression(p) && p.nodeType !== cs.SyntaxKind.LocalFunction) {
            p = p.parent;
        }
        if (r.expression && p && cs.isMethodDeclaration(p) && !p.isAsync && this._returnsPromise(p)) {
            this.write('return await ');
            this.writeExpression(r.expression);
            this.writeSemicolon();
            return;
        }
        if (r.expression && this._isSequenceIterator(p)) {
            this.write('return AnyIterator(');
            this.writeExpression(r.expression);
            this.writeLine(')');
            return;
        }
        super.writeReturnStatement(r);
    }

    private _isVoid(t: cs.TypeNode) {
        if (cs.isPrimitiveTypeNode(t)) {
            return t.type === cs.PrimitiveType.Void && !t.isNullable;
        }
        // `Promise<void>` prints as `Void`
        return this._captureType(t) === 'Void';
    }

    /** A return type: `Promise<T>` prints as `T` (the function is `async`). */
    private _writeReturnType(t: cs.TypeNode, owner?: cs.Node) {
        // `Promise<T | null>`: the `?` sits on `T`, which the async reference wraps
        const inner = cs.isTypeReference(t) && t.isAsync && typeof t.reference !== 'string' ? (t.reference as cs.TypeNode) : t;
        this._writeType(inner, { owner });
    }

    /** ` {` + statements + `}` for a block or expression body. */
    private _writeBody(body: cs.Block | cs.Expression, staticInit = false) {
        this._openBrace();
        if (staticInit) {
            this.writeLine('Self._staticInit()');
        }
        if (cs.isBlock(body)) {
            for (const s of body.statements) {
                this.writeStatement(s);
            }
        } else {
            this.write('return ');
            this.writeExpression(body);
            this.writeLine();
        }
        this._closeBrace();
    }

    protected writeConstructorDeclaration(d: cs.ConstructorDeclaration) {
        if (d.isStatic) {
            this._writeStaticInitializer(d);
            return;
        }
        this.writeDocumentation(d);
        this.writeVisibility(d.visibility);
        const cls = d.parent as cs.ClassDeclaration;
        const baseParameters = this._baseConstructorParameters(cls);
        if (
            baseParameters !== undefined &&
            this._parameterSignature(baseParameters) === this._parameterSignature(d.parameters)
        ) {
            this.write('override ');
        }
        this.write('init');
        this.writeParameters(d.parameters);
        if (this._throws(d)) {
            this.write(' throws');
        }

        const statements = d.body && cs.isBlock(d.body) ? d.body.statements : [];
        const staticInit = this._hasStaticInitializer(cls);
        if (!staticInit && !d.baseConstructorArguments && statements.length === 0 && (!d.body || cs.isBlock(d.body))) {
            this.writeLine(' {}');
            return;
        }
        this._openBrace();
        if (staticInit) {
            this.writeLine('Self._staticInit()');
        }
        // a record sets its own (non-optional) fields before super.init, as Swift's two-phase init requires
        const ownFirst = !!cls.isRecord && !!d.baseConstructorArguments;
        if (ownFirst) {
            for (const s of statements) {
                this.writeStatement(s);
            }
        }
        if (d.baseConstructorArguments) {
            let args = d.baseConstructorArguments;
            if (cls.isRecord && baseParameters) {
                // the base record's init lists required fields first; labels must follow its order
                const order = baseParameters.map(p => p.name);
                const labelOf = (e: cs.Expression) => (cs.isLabeledExpression(e) ? e.label : '');
                args = [...args].sort((a, b) => order.indexOf(labelOf(a)) - order.indexOf(labelOf(b)));
            }
            // the arguments run before the body: a throwing one needs its `try` here
            const throwingArgument = args.some(
                e => !!e.tsNode && (this._context as SwiftEmitterContext).throwsAnalysis.containsThrowingCall(e.tsNode)
            );
            this.write(throwingArgument ? 'try super.init(' : 'super.init(');
            this.writeCommaSeparated(args, e => this.writeExpression(e));
            this.writeLine(')');
        }
        if (d.body && !cs.isBlock(d.body)) {
            this.writeExpression(d.body);
            this.writeLine();
        }
        if (!ownFirst) {
            for (const s of statements) {
                this.writeStatement(s);
            }
        }
        this._closeBrace();
    }

    protected override writeParameters(parameters: cs.ParameterDeclaration[]) {
        this.write('(');
        this.writeCommaSeparated(parameters, p => this.writeParameter(p), false);
        this.write(')');
    }

    private _isRecordConstructorParameter(p: cs.ParameterDeclaration) {
        const ctor = p.parent;
        return (
            !!ctor &&
            cs.isConstructorDeclaration(ctor) &&
            !!ctor.parent &&
            cs.isClassDeclaration(ctor.parent) &&
            !!ctor.parent.isRecord
        );
    }

    private _isFunctionType(t: cs.TypeNode): boolean {
        if (cs.isFunctionTypeNode(t)) {
            return true;
        }
        if (cs.isTypeReference(t) && typeof t.reference !== 'string') {
            const r = t.reference as cs.Node;
            return r.nodeType === cs.SyntaxKind.DelegateDeclaration || cs.isFunctionTypeNode(r);
        }
        return false;
    }

    protected writeParameter(p: cs.ParameterDeclaration) {
        if (!this._isRecordConstructorParameter(p)) {
            this.write('_ ');
        }
        this.writeIdentifier(p.name);
        this.write(': ');
        if (!p.type) {
            this.write('Any?');
            return;
        }
        const type = p.params ? (p.type as cs.ArrayTypeNode).elementType : p.type;
        const optional = p.isOptional && !p.initializer;
        if (this._isFunctionType(type) && !type.isNullable && !optional) {
            this.write('@escaping ');
        }
        this._writeType(type, { nullable: optional || undefined, owner: p });
        if (p.params) {
            this.write('...');
        }
        if (p.parent && cs.isMethodDeclaration(p.parent) && this._isInProtocol(p.parent)) {
            return; // no defaults on requirements: see _writeProtocolDefaults
        }
        if (p.initializer) {
            this.write(' = ');
            this.writeExpression(p.initializer);
        } else if (optional) {
            this.write(' = nil');
        }
    }

    private _isAutoProperty(d: cs.PropertyDeclaration) {
        return !(d.getAccessor && d.getAccessor.body) && !(d.setAccessor && d.setAccessor.body);
    }

    private _isLateInit(d: cs.PropertyDeclaration) {
        return !!d.initializer && cs.isNonNullExpression(d.initializer) && cs.isNullLiteral(d.initializer.expression);
    }

    /** The value a stored property starts with when TS gives none, or undefined for `T!`. */
    private _zeroValue(t: cs.TypeNode): string | undefined {
        if (t.isNullable) {
            return 'nil';
        }
        let type: cs.TypeReferenceType = t;
        while (typeof type !== 'string' && cs.isTypeReference(type)) {
            type = type.reference;
        }
        if (typeof type !== 'string' && cs.isPrimitiveTypeNode(type)) {
            switch (type.type) {
                case cs.PrimitiveType.Double:
                    return '0.0';
                case cs.PrimitiveType.Int:
                case cs.PrimitiveType.Long:
                    return '0';
                case cs.PrimitiveType.Bool:
                    return 'false';
            }
        }
        return undefined;
    }

    private _isSwiftLetPrimitive(t: cs.TypeNode) {
        return (
            cs.isPrimitiveTypeNode(t) &&
            !t.isNullable &&
            [cs.PrimitiveType.Double, cs.PrimitiveType.Int, cs.PrimitiveType.Bool, cs.PrimitiveType.String].includes(
                t.type
            )
        );
    }

    protected writePropertyDeclaration(d: cs.PropertyDeclaration) {
        this.writeDocumentation(d);
        this.writeAttributes(d);

        if (this._isInProtocol(d)) {
            this.write('var ');
            this.writeIdentifier(d.name);
            this.write(': ');
            this._writeType(d.type, { owner: d });
            this.writeLine(d.setAccessor ? ' { get set }' : ' { get }');
            return;
        }

        const isAuto = this._isAutoProperty(d);

        if (d.isAbstract) {
            this._writeMemberModifiers(d);
            this.write('var ');
            this.writeIdentifier(d.name);
            this.write(': ');
            this._writeType(d.type, { owner: d });
            this._openBrace();
            this.write('get');
            this._openBrace();
            this.writeLine('fatalError("abstract")');
            this._closeBrace();
            if (d.setAccessor) {
                this.write('set');
                this._openBrace();
                this.writeLine('fatalError("abstract")');
                this._closeBrace();
            }
            this._closeBrace();
            return;
        }

        if (isAuto && (this._isRealOverride(d) || this._isInterfaceRequiredImplicitlyUnwrapped(d))) {
            // Swift cannot override a property with a stored one, and `T!` does not satisfy a protocol's `T`:
            // private store + computed property
            const store = `__${d.name}`;
            this.write('private var ');
            this.write(store);
            this.write(': ');
            this._writeStoredPropertyTypeAndValue(d);
            this.writeLine();
            this.writeLine();
            this._writeMemberModifiers(d);
            this.write('var ');
            this.writeIdentifier(d.name);
            this.write(': ');
            this._writeType(d.type, { owner: d });
            this._openBrace();
            this.write('get');
            this._openBrace();
            this.writeLine(`return self.${store}`);
            this._closeBrace();
            this.write('set');
            this._openBrace();
            this.writeLine(`self.${store} = newValue`);
            this._closeBrace();
            this._closeBrace();
            return;
        }

        if (isAuto) {
            const isLet = d.isStatic && !d.setAccessor;
            if (d.isStatic && !(isLet && this._isSwiftLetPrimitive(d.type))) {
                this.write('nonisolated(unsafe) ');
            }
            this._writeMemberModifiers(d);
            this.write(isLet ? 'let ' : 'var ');
            this.writeIdentifier(d.name);
            this.write(': ');
            this._writeStoredPropertyTypeAndValue(d);
            this.writeLine();
            return;
        }

        this._writeMemberModifiers(d);
        this.write('var ');
        this.writeIdentifier(d.name);
        this.write(': ');
        this._writeType(d.type, { owner: d });
        this._openBrace();
        this.write('get');
        if (d.getAccessor?.body) {
            this._writeBody(d.getAccessor.body);
        } else {
            this._openBrace();
            this.writeLine(`fatalError("${d.name} has no getter")`);
            this._closeBrace();
        }
        if (d.setAccessor?.body) {
            this.write('set');
            // the shared transformer leaves a TS `value` unnamed (C#'s implicit name); Swift's is `newValue`
            const valueName = d.setAccessor.valueParameterName ?? 'value';
            if (valueName !== 'newValue') {
                this.write(`(${valueName})`);
            }
            this._writeBody(d.setAccessor.body);
        }
        this._closeBrace();
    }

    private _isInterfaceRequiredImplicitlyUnwrapped(d: cs.PropertyDeclaration): boolean {
        return (
            !!d.tsNode &&
            this._capture(() => this._writeStoredPropertyTypeAndValue(d)).endsWith('!') &&
            this._implementsRequiredInterfaceMember(d.tsNode as ts.Declaration)
        );
    }

    /** `Type = initializer`, `Type = <zero>` or `Type!` for a stored property. */
    private _writeStoredPropertyTypeAndValue(d: cs.PropertyDeclaration) {
        const initializer = d.initializer && !this._isLateInit(d) ? d.initializer : undefined;
        const type = d.type;
        if (initializer) {
            this._writeType(type, { nullable: cs.isNullLiteral(initializer) || undefined, owner: d });
            this.write(' = ');
            this.writeExpression(initializer);
            return;
        }
        const zero = this._isLateInit(d) ? undefined : this._zeroValue(type);
        if (zero !== undefined && !this._isAnyType(type, d)) {
            this.writeType(type);
            this.write(` = ${zero}`);
        } else if (this._isAnyType(type, d) || type.isNullable) {
            this._writeType(type, { nullable: true, owner: d });
            this.write(' = nil');
        } else if (d.parent && cs.isClassDeclaration(d.parent) && d.parent.isRecord) {
            this._writeType(type, { owner: d });
        } else {
            this._writeImplicitlyUnwrapped(type, d);
        }
    }

    /** `T!`; a function or existential type needs parentheses: `((Double) -> Bool)!`. */
    private _writeImplicitlyUnwrapped(type: cs.TypeNode, owner?: cs.Node) {
        const text = this._capture(() => this._writeType(type, { owner }));
        this.write(text.startsWith('any ') || text.includes('->') ? `(${text})!` : `${text}!`);
    }

    protected writeFieldDeclarat1on(d: cs.FieldDeclaration) {
        this.writeDocumentation(d);
        if (d.isStatic) {
            if (!(d.isReadonly && this._isSwiftLetPrimitive(d.type))) {
                this.write('nonisolated(unsafe) ');
            }
        }
        this.writeVisibility(d.visibility);
        if (d.isStatic) {
            this.write('static ');
        }
        this.write(d.isStatic && d.isReadonly ? 'let ' : 'var ');
        this.writeIdentifier(d.name);
        this.write(': ');
        if (d.initializer) {
            this._writeType(d.type, { nullable: cs.isNullLiteral(d.initializer) || undefined });
            this.write(' = ');
            this.writeExpression(d.initializer);
        } else {
            const zero = this._zeroValue(d.type);
            if (zero !== undefined) {
                this._writeType(d.type, { owner: d });
                this.write(` = ${zero}`);
            } else {
                this._writeImplicitlyUnwrapped(d.type, d);
            }
        }
        this.writeLine();
    }

    // ── types ─────────────────────────────────────────────────────────────

    /**
     * An Object primitive is `Any?` when its TS type holds `null`: `any`,
     * `unknown`, `object | null`; plain `object` is `Any`. Decided from the
     * TS type of the declaration that owns the type node, because the IR's
     * nullability on Object is Kotlin's (`equals(other: Any?)`, `read(): Any`).
     */
    private _isAnyType(t: cs.TypeNode, owner?: cs.Node) {
        if (!cs.isPrimitiveTypeNode(t) || t.type !== cs.PrimitiveType.Object) {
            return false;
        }
        const kind = t.tsNode?.kind;
        if (kind === ts.SyntaxKind.AnyKeyword || kind === ts.SyntaxKind.UnknownKeyword) {
            return true;
        }
        const tsType = this._ownerTsType(t, owner ?? t.parent ?? undefined);
        if (!tsType) {
            return !!t.isNullable;
        }
        if (tsType.flags & (ts.TypeFlags.Any | ts.TypeFlags.Unknown | ts.TypeFlags.Null | ts.TypeFlags.Undefined)) {
            return true;
        }
        return (
            tsType.isUnion() &&
            tsType.types.some(u => u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined))
        );
    }

    private _ownerTsType(t: cs.TypeNode, owner: cs.Node | undefined): ts.Type | undefined {
        const tsNode = owner?.tsNode;
        if (!owner || !tsNode) {
            return undefined;
        }
        const checker = this._context.typeChecker;
        if (cs.isMethodDeclaration(owner) && owner.returnType === t) {
            if (ts.isFunctionLike(tsNode)) {
                const signature = checker.getSignatureFromDeclaration(tsNode as ts.SignatureDeclaration);
                return signature ? checker.getReturnTypeOfSignature(signature) : undefined;
            }
            return undefined;
        }
        if (
            (cs.isParameterDeclaration(owner) && owner.type === t) ||
            (cs.isPropertyDeclaration(owner) && owner.type === t) ||
            (cs.isFieldDeclaration(owner) && owner.type === t) ||
            (owner.nodeType === cs.SyntaxKind.VariableDeclaration && (owner as cs.VariableDeclaration).type === t)
        ) {
            return checker.getTypeAtLocation(tsNode);
        }
        return undefined;
    }

    protected writeType(
        type: cs.TypeNode,
        forNew: boolean = false,
        _asNativeArray: boolean = false,
        forTypeConstraint: boolean = false
    ) {
        this._writeType(type, { forNew, existential: !forTypeConstraint && !forNew });
    }

    private _writeType(
        type: cs.TypeNode,
        options: { forNew?: boolean; existential?: boolean; nullable?: boolean; owner?: cs.Node }
    ): void {
        const forNew = !!options.forNew;
        const existential = options.existential ?? !forNew;
        const nullable = !forNew && (options.nullable ?? this._isNullableType(type, options.owner));
        const text = this._capture(() => this._writeTypeCore(type, forNew, existential));
        // a function type's text can end in its return type's `?` and still need its own
        if (nullable && (!text.endsWith('?') || this._isFunctionType(type))) {
            const needsParens = text.startsWith('any ') || text.includes('->');
            this.write(needsParens ? `(${text})?` : `${text}?`);
        } else {
            this.write(text);
        }
    }

    private _isNullableType(type: cs.TypeNode, owner?: cs.Node): boolean {
        if (cs.isPrimitiveTypeNode(type) && type.type === cs.PrimitiveType.Object) {
            return this._isAnyType(type, owner);
        }
        return !!type.isNullable;
    }

    private _writeTypeCore(type: cs.TypeNode, forNew: boolean, existential: boolean) {
        switch (type.nodeType) {
            case cs.SyntaxKind.PrimitiveTypeNode:
                switch ((type as cs.PrimitiveTypeNode).type) {
                    case cs.PrimitiveType.Bool:
                        this.write('Bool');
                        break;
                    case cs.PrimitiveType.Double:
                        this.write(this._forceInteger ? 'Int' : 'Double');
                        break;
                    case cs.PrimitiveType.Int:
                        this.write('Int');
                        break;
                    case cs.PrimitiveType.Object:
                        this.write('Any');
                        break;
                    case cs.PrimitiveType.String:
                        this.write('String');
                        break;
                    case cs.PrimitiveType.Void:
                        this.write('Void');
                        break;
                    case cs.PrimitiveType.Var:
                        this.write('var');
                        break;
                    case cs.PrimitiveType.Long:
                        this.write('Int64');
                        break;
                }
                break;
            case cs.SyntaxKind.ArrayTypeNode:
                this.write('List<');
                this._writeType((type as cs.ArrayTypeNode).elementType, {});
                this.write('>');
                break;
            case cs.SyntaxKind.MapTypeNode: {
                const mapType = type as cs.MapTypeNode;
                this.write('Map<');
                if (mapType.keyType) {
                    this._writeType(mapType.keyType, {});
                } else {
                    this.write('Any');
                }
                this.write(', ');
                if (mapType.valueType) {
                    this._writeType(mapType.valueType, {});
                } else {
                    this.write('Any?');
                }
                this.write('>');
                break;
            }
            case cs.SyntaxKind.ArrayTupleNode:
                this.write('(');
                this.writeCommaSeparated((type as cs.ArrayTupleNode).types, t => this._writeType(t, {}), false);
                this.write(')');
                break;
            case cs.SyntaxKind.FunctionTypeNode: {
                const functionType = type as cs.FunctionTypeNode;
                this.write('(');
                this.writeCommaSeparated(functionType.parameterTypes, p => this._writeType(p, {}), false);
                this.write(this._functionTypeThrows(functionType.tsNode) ? ') throws -> ' : ') -> ');
                this._writeReturnType(functionType.returnType);
                break;
            }
            case cs.SyntaxKind.TypeReference: {
                const typeReference = type as cs.TypeReference;
                const targetType = typeReference.reference;
                if (typeof targetType === 'string') {
                    const name = this._unqualify(targetType);
                    if (existential && SwiftAstPrinter._runtimeProtocols.has(name)) {
                        this.write('any ');
                    }
                    this.write(name);
                } else {
                    this._writeTypeCore(targetType as cs.TypeNode, forNew, existential);
                }
                const typeArguments = typeReference.typeArguments;
                if (typeArguments && typeArguments.length > 0) {
                    this.write('<');
                    this.writeCommaSeparated(typeArguments, p => this._writeType(p, {}), false);
                    this.write('>');
                }
                break;
            }
            case cs.SyntaxKind.InterfaceDeclaration:
                if (existential) {
                    this.write('any ');
                }
                this.write(this._typeName(type as cs.NamedTypeDeclaration));
                break;
            case cs.SyntaxKind.ClassDeclaration:
            case cs.SyntaxKind.EnumDeclaration:
            case cs.SyntaxKind.DelegateDeclaration:
                this.write(this._typeName(type as cs.NamedTypeDeclaration));
                break;
            case cs.SyntaxKind.UsingDeclaration:
                this.write((type as cs.UsingDeclaration).name);
                break;
            case cs.SyntaxKind.TypeParameterDeclaration:
                this.writeIdentifier((type as cs.TypeParameterDeclaration).name);
                break;
            case cs.SyntaxKind.EnumMember:
                this.write(this._typeName((type as cs.EnumMember).parent as cs.NamedTypeDeclaration));
                break;
            default:
                // load-bearing debug fallthrough, as in the Kotlin printer
                this.write(`TODO: ${cs.SyntaxKind[type.nodeType]}`);
                break;
        }
    }

    private _typeName(d: cs.NamedTypeDeclaration) {
        return this._unqualify(this._context.getFullName(d));
    }

    // ── expressions ───────────────────────────────────────────────────────

    protected override writeThisLiteral(_expr: cs.ThisLiteral): void {
        this.write('self');
    }

    protected override writeNullLiteral(_expr: cs.NullLiteral) {
        this.write('nil');
    }

    private _escapeString(text: string): string {
        const json = JSON.stringify(text);
        // one pass over the escape pairs, so an escaped backslash before `b` (`\\\\b`) stays one
        return json.substring(1, json.length - 1).replace(/\\(u([0-9a-fA-F]{4})|[^u])/g, (m, e: string, h?: string) => {
            if (h) {
                return `\\u{${h.replace(/^0+(?=.)/, '')}}`;
            }
            return e === 'b' ? '\\u{8}' : e === 'f' ? '\\u{c}' : m;
        });
    }

    protected override writeStringLiteral(expr: cs.StringLiteral): void {
        this.write(`"${this._escapeString(expr.text)}"`);
    }

    protected writeStringTemplateExpression(expr: cs.StringTemplateExpression) {
        this.write('"');
        const start = this._source.length - 1;
        for (const c of expr.chunks) {
            if (cs.isStringLiteral(c)) {
                this.write(this._escapeString(c.text));
            } else if (this._isReference(c)) {
                // `${obj}` is `obj.toString()`; a class without one has no toTemplate()
                if (this._hasOwnToString(c)) {
                    this.write('\\((');
                    this.writeExpression(c);
                    this.write(').toString())');
                } else {
                    this.write('\\(jsTemplate(');
                    this.writeExpression(c);
                    this.write('))');
                }
            } else {
                this.write('\\((');
                this.writeExpression(c);
                this.write(').toTemplate())');
            }
        }
        if (this._source.indexOf('\n', start) === -1) {
            this.write('"');
        } else {
            // a single-line literal cannot hold a multi-line closure; a closing delimiter at column 0 strips no indentation
            const q = '"""';
            this._source = `${this._source.substring(0, start)}${q}\n${this._source.substring(start + 1)}\n${q}`;
        }
    }

    protected writeNumericLiteral(expr: cs.NumericLiteral) {
        this.write(expr.value);
        if (!this._forceInteger && !expr.value.endsWith('L') && expr.forceDoubleSuffix) {
            this.write('.0');
        }
    }

    protected writeTypeOfExpression(expr: cs.TypeOfExpression) {
        if (expr.expression) {
            this.writeExpression(expr.expression);
        }
        if (expr.type) {
            this._writeType(expr.type, { existential: false });
        }
        this.write('.self');
    }

    protected writePrefixUnaryExpression(expr: cs.PrefixUnaryExpression) {
        switch (expr.operator) {
            case '~':
                this.write('jsNot(');
                this._writeBitOperand(expr.operand);
                this.write(')');
                break;
            case '++':
            case '--':
                this._writeIncrement(expr, expr.operator === '++' ? 'jsPreInc' : 'jsPreDec');
                break;
            default: {
                const operand = this._unwrapParens(expr.operand);
                if (expr.operator === '!' && cs.isPrefixUnaryExpression(operand) && operand.operator === '!') {
                    // `!!x` is `Boolean(x)`; its operand already is a Bool (`TypeHelper.isTruthy(x)`)
                    this.writeExpression(operand.operand);
                    break;
                }
                this.write(expr.operator);
                this.writeExpression(expr.operand);
                break;
            }
        }
    }

    protected override writePostfixUnaryExpression(expr: cs.PostfixUnaryExpression) {
        switch (expr.operator) {
            case '++':
            case '--':
                this._writeIncrement(expr, expr.operator === '++' ? 'jsPostInc' : 'jsPostDec');
                break;
            default:
                this.writeExpression(expr.operand);
                this.write(expr.operator);
                break;
        }
    }

    /** `x++` as a statement -> `x += 1`; as a value -> runtime `jsPostInc(&x)` (Swift's `+=` returns `()`). */
    private _writeIncrement(expr: cs.PrefixUnaryExpression | cs.PostfixUnaryExpression, helper: string) {
        const parent = expr.parent;
        if (parent && (cs.isExpressionStatement(parent) || cs.isForStatement(parent))) {
            this.writeExpression(expr.operand);
            this.write(expr.operator === '++' ? ' += 1' : ' -= 1');
            return;
        }
        this.write(`${helper}(&`);
        this.writeExpression(expr.operand);
        this.write(')');
    }

    protected writeBaseLiteralExpression(_expr: cs.BaseLiteralExpression) {
        this.write('super');
    }

    protected writeAwaitExpression(expr: cs.AwaitExpression) {
        this.write('await ');
        this.writeExpression(expr.expression);
    }

    private _tsTypeOf(expr: cs.Expression): ts.Type | undefined {
        const tsNode = expr.tsNode;
        if (!tsNode) {
            return undefined;
        }
        return this._context.typeChecker.getTypeAtLocation(tsNode);
    }

    private _isEnumExpression(expr: cs.Expression): boolean {
        while (cs.isParenthesizedExpression(expr)) {
            expr = expr.expression;
        }
        const t = this._tsTypeOf(expr);
        if (!t) {
            return false;
        }
        const nonNull = this._context.typeChecker.getNonNullableType(t);
        // a narrowed enum (`x !== E.A`) is a union of its remaining members
        const isEnum = (u: ts.Type) => !!(u.flags & ts.TypeFlags.EnumLike);
        return isEnum(nonNull) || (nonNull.isUnion() && nonNull.types.every(isEnum));
    }

    private _isIntegerLiteral(expr: cs.Expression): boolean {
        return cs.isNumericLiteral(expr) && /^-?[0-9]+$/.test(expr.value);
    }

    /** An operand of an integer bit operation. */
    private _writeIntOperand(expr: cs.Expression) {
        if (this._isEnumExpression(expr)) {
            this.writeExpression(expr);
            this.write('.rawValue');
        } else if (this._isIntegerLiteral(expr)) {
            this.writeExpression(expr);
        } else {
            this.write('(');
            this.writeExpression(expr);
            this.write(').toInt()');
        }
    }

    /** Runtime types that are Swift protocols, used as existentials (`any Disposable`). */
    // protocols the Swift module or its runtime declares by hand (EventEmitter.swift is not generated)
    private static readonly _runtimeProtocols = new Set(['Disposable', 'AsyncDisposable', 'IEventEmitter', 'IEventEmitterOfT']);

    private static readonly _bitOperators = new Set(['&', '|', '^', '<<', '>>']);

    /** A bit operation the shared transformer left uncoerced: both operands are enums. */
    private _isEnumBitOp(expr: cs.BinaryExpression): boolean {
        const tsNode = expr.tsNode;
        if (tsNode && ts.isBinaryExpression(tsNode)) {
            const checker = this._context.typeChecker;
            const isEnum = (n: ts.Expression) =>
                !!(checker.getNonNullableType(checker.getTypeAtLocation(n)).flags & ts.TypeFlags.EnumLike);
            return isEnum(tsNode.left) && isEnum(tsNode.right);
        }
        return this._isEnumExpression(expr.left) && this._isEnumExpression(expr.right);
    }

    private _isBitOp(e: cs.Expression): boolean {
        return cs.isBinaryExpression(e) && SwiftAstPrinter._bitOperators.has(e.operator) && !this._isEnumBitOp(e);
    }

    private _unwrapParens(e: cs.Expression): cs.Expression {
        while (cs.isParenthesizedExpression(e)) {
            e = e.expression;
        }
        return e;
    }

    /** An operand of a number bit operation, as the `Double` the runtime's `js*` helpers take: the shared transformer's `Int` casts are dropped. */
    private _writeBitOperand(e: cs.Expression) {
        let inner = this._unwrapParens(e);
        if (cs.isCastExpression(inner) && cs.isPrimitiveTypeNode(inner.type) && inner.type.type === cs.PrimitiveType.Int) {
            inner = this._unwrapParens(inner.expression);
        }
        if (this._isEnumExpression(inner)) {
            this.write('Double(');
            this.writeExpression(inner);
            this.write('.rawValue)');
        } else {
            this.writeExpression(inner);
        }
    }

    private static readonly _bitHelpers: Record<string, string> = {
        '&': 'jsAnd',
        '|': 'jsOr',
        '^': 'jsXor',
        '<<': 'jsShl',
        '>>': 'jsShr'
    };

    private _isUnsignedShift(expr: cs.BinaryExpression): boolean {
        const tsNode = expr.tsNode;
        return (
            expr.operator === '>>>' ||
            expr.operator === '>>>=' ||
            (!!tsNode &&
                ts.isBinaryExpression(tsNode) &&
                (tsNode.operatorToken.kind === ts.SyntaxKind.GreaterThanGreaterThanGreaterThanToken ||
                    tsNode.operatorToken.kind === ts.SyntaxKind.GreaterThanGreaterThanGreaterThanEqualsToken))
        );
    }

    /** `left % right` on numbers: Swift's `Double` has no `%`. */
    private _writeRemainder(left: cs.Expression, right: cs.Expression) {
        const simple =
            cs.isIdentifier(left) ||
            cs.isNumericLiteral(left) ||
            cs.isParenthesizedExpression(left) ||
            cs.isMemberAccessExpression(left) ||
            cs.isInvocationExpression(left) ||
            cs.isThisLiteral(left);
        if (!simple) {
            this.write('(');
        }
        this.writeExpression(left);
        if (!simple) {
            this.write(')');
        }
        this.write('.truncatingRemainder(dividingBy: ');
        this.writeExpression(right);
        this.write(')');
    }

    private static readonly _tsBitOperators = new Set([
        ts.SyntaxKind.AmpersandToken,
        ts.SyntaxKind.BarToken,
        ts.SyntaxKind.CaretToken,
        ts.SyntaxKind.LessThanLessThanToken,
        ts.SyntaxKind.GreaterThanGreaterThanToken,
        ts.SyntaxKind.GreaterThanGreaterThanGreaterThanToken
    ]);

    private static readonly _tsBitAssignOperators = new Set([
        ts.SyntaxKind.AmpersandEqualsToken,
        ts.SyntaxKind.BarEqualsToken,
        ts.SyntaxKind.CaretEqualsToken,
        ts.SyntaxKind.LessThanLessThanEqualsToken,
        ts.SyntaxKind.GreaterThanGreaterThanEqualsToken,
        ts.SyntaxKind.GreaterThanGreaterThanGreaterThanEqualsToken
    ]);

    private readonly _reportedFlagEnums = new Set<ts.Node>();

    /** No flag enums: a Swift enum cannot hold `Read ^ Write` when that is no declared case. */
    private _checkFlagEnum(expr: cs.BinaryExpression) {
        const n = expr.tsNode;
        if (!n || !ts.isBinaryExpression(n) || this._reportedFlagEnums.has(n)) {
            return;
        }
        const checker = this._context.typeChecker;
        const isEnumType = (t: ts.Type | undefined) => !!t && !!(checker.getNonNullableType(t).flags & ts.TypeFlags.EnumLike);
        const isEnum = (e: ts.Expression) => isEnumType(checker.getTypeAtLocation(e));
        const op = n.operatorToken.kind;
        const enumResult = SwiftAstPrinter._tsBitAssignOperators.has(op)
            ? isEnum(n.left)
            : SwiftAstPrinter._tsBitOperators.has(op) &&
              (isEnum(n.left) || isEnum(n.right)) &&
              isEnumType(checker.getContextualType(n));
        if (enumResult) {
            this._reportedFlagEnums.add(n);
            this._context.addTsNodeDiagnostics(
                n,
                'Swift enums hold only their declared cases, so a bit operator on an enum cannot produce an enum value. Use a number for bit flags.',
                ts.DiagnosticCategory.Error
            );
        }
    }

    protected writeBinaryExpression(expr: cs.BinaryExpression) {
        this._checkFlagEnum(expr);
        if (!this._forceInteger && (expr.operator === '%' || expr.operator === '%=')) {
            if (expr.operator === '%=') {
                this.writeExpression(expr.left);
                this.write(' = ');
            }
            this._writeRemainder(expr.left, expr.right);
            return;
        }
        if (expr.operator === '>>>=') {
            // the shared transformer decomposes the other compound bit ops, not this one
            this.writeExpression(expr.left);
            this.write(' = jsUshr(');
            this._writeBitOperand(expr.left);
            this.write(', ');
            this._writeBitOperand(expr.right);
            this.write(')');
            return;
        }
        if (this._isBitOp(expr)) {
            this.write(this._isUnsignedShift(expr) ? 'jsUshr(' : `${SwiftAstPrinter._bitHelpers[expr.operator]}(`);
            this._writeBitOperand(expr.left);
            this.write(', ');
            this._writeBitOperand(expr.right);
            this.write(')');
            return;
        }
        if (SwiftAstPrinter._bitOperators.has(expr.operator)) {
            const enumResult = this._bitResultEnumName(expr);
            if (enumResult) {
                this.write(`${enumResult}.fromValue(Double(`);
            } else {
                this.write('Double(');
            }
            this._writeIntOperand(expr.left);
            this.write(` ${expr.operator} `);
            this._writeIntOperand(expr.right);
            this.write(enumResult ? '))' : ')');
            return;
        }

        if (expr.operator === '+' && this._writeLongStringConcat(expr)) {
            return;
        }
        if (expr.operator === '+' && this._writeStringConcatWithEnum(expr)) {
            return;
        }
        if (expr.operator === '+=' && this._isStringExpression(expr.left) && this._isDeclaredUnknown(expr.right)) {
            // `svg += r.renderResult` with an `unknown` result
            this.writeExpression(expr.left);
            this.write(' += jsTemplate(');
            this.writeExpression(expr.right);
            this.write(')');
            return;
        }
        if (expr.operator === '+' && this._writeStringConcatWithUnknown(expr)) {
            return;
        }
        switch (expr.operator) {
            case '??':
                this.writeExpression(expr.left);
                if (cs.isNullLiteral(expr.right)) {
                    return;
                }
                this.write(' ?? ');
                this.writeExpression(expr.right);
                return;
            case '??=':
            case '||=':
            case '&&=':
                this.writeExpression(expr.left);
                this.write(' = ');
                this.writeExpression(expr.left);
                this.write(` ${expr.operator.substring(0, 2)} `);
                this.writeExpression(expr.right);
                return;
            case '===':
            case '!==':
            case '==':
            case '!=': {
                const negated = expr.operator.startsWith('!');
                if (
                    (this._isAnyValue(expr.left) && (this._isAnyValue(expr.right) || this._isReference(expr.right))) ||
                    (this._isAnyValue(expr.right) && this._isReference(expr.left))
                ) {
                    // an `Any?` value against another or against an instance (`obj === this`): Swift has no `==` on them
                    this.write(negated ? '!TypeHelper.strictEquals(' : 'TypeHelper.strictEquals(');
                    this.writeExpression(expr.left);
                    this.write(', ');
                    this.writeExpression(expr.right);
                    this.write(')');
                    return;
                }
                const identity = this._isReference(expr.left) && this._isReference(expr.right);
                this.writeExpression(expr.left);
                // class instances are not Equatable: TS compares them by reference
                this.write(identity ? (negated ? ' !== ' : ' === ') : negated ? ' != ' : ' == ');
                this.writeExpression(expr.right);
                return;
            }
        }

        this.writeExpression(expr.left);
        this.write(` ${expr.operator} `);
        this.writeExpression(expr.right);
    }

    /**
     * A bit operation whose value lands in an enum-typed slot (a `return`
     * of an enum-returning method) converts back with `E.fromValue`.
     */
    private _bitResultEnumName(expr: cs.BinaryExpression): string | undefined {
        let node: cs.Node = expr;
        while (node.parent && cs.isParenthesizedExpression(node.parent)) {
            node = node.parent;
        }
        const parent = node.parent;
        let target: cs.TypeNode | undefined;
        if (parent && cs.isReturnStatement(parent)) {
            let p: cs.Node | null = parent;
            while (p && !cs.isMethodDeclaration(p) && !cs.isLambdaExpression(p)) {
                p = p.parent;
            }
            if (p && cs.isMethodDeclaration(p)) {
                target = p.returnType;
            }
        } else if (parent && cs.isCastExpression(parent)) {
            target = parent.type;
        }
        if (!target) {
            return undefined;
        }
        let ref: cs.TypeReferenceType = target;
        while (typeof ref !== 'string' && cs.isTypeReference(ref)) {
            ref = ref.reference;
        }
        if (typeof ref !== 'string' && cs.isEnumDeclaration(ref)) {
            return this._typeName(ref);
        }
        return undefined;
    }

    protected writeConditionalExpression(expr: cs.ConditionalExpression) {
        this.writeExpression(expr.condition);
        this.write(' ? ');
        this.writeExpression(expr.whenTrue);
        this.write(' : ');
        this.writeExpression(expr.whenFalse);
    }

    /** `new Promise<T>(resolve => ...)`: the type of `resolve` is `(T) -> Void` (the IR has Kotlin's `(Any) -> Unit`). */
    private _promiseValueType(expr: cs.LambdaExpression): cs.TypeNode | undefined {
        const call = expr.parent;
        if (
            call &&
            cs.isInvocationExpression(call) &&
            cs.isMemberAccessExpression(call.expression) &&
            call.expression.member === 'createPromise' &&
            call.typeArguments?.length === 1
        ) {
            return call.typeArguments[0];
        }
        return undefined;
    }

    protected writeLambdaExpression(expr: cs.LambdaExpression) {
        const promiseValueType = this._promiseValueType(expr);
        this.write('{ (');
        this.writeCommaSeparated(
            expr.parameters,
            p => {
                this.writeIdentifier(p.name);
                this.write(': ');
                if (promiseValueType && p === expr.parameters[0]) {
                    this.write('@escaping (');
                    this.writeType(promiseValueType);
                    this.write(') -> Void');
                } else if (p.type) {
                    if (this._isFunctionType(p.type) && !p.type.isNullable) {
                        this.write('@escaping ');
                    }
                    this.writeType(p.type);
                } else {
                    this.write('Any?');
                }
            },
            false
        );
        this.write(')');
        if (!this._isVoid(expr.returnType)) {
            this.write(' -> ');
            this._writeReturnType(expr.returnType);
        }
        this.writeLine(' in');
        this._indent++;
        if (cs.isBlock(expr.body)) {
            for (const s of expr.body.statements) {
                this.writeStatement(s);
            }
        } else {
            if (!this._isVoid(expr.returnType)) {
                this.write('return ');
            }
            this.writeExpression(expr.body);
            this.writeLine();
        }
        this._indent--;
        this.write('}');
    }

    protected writeArrayCreationExpression(expr: cs.ArrayCreationExpression) {
        if (expr.type && cs.isArrayTupleNode(this._resolveTypeNode(expr.type))) {
            this.write('(');
            this.writeCommaSeparated(expr.values ?? [], v => this.writeExpression(v), false);
            this.write(')');
            return;
        }
        if (expr.type && expr.values && this._capture(() => this._writeType(expr.type!, { forNew: true })).startsWith('any Sequence<')) {
            // an array literal passed as an `Iterable` (`new Set([0])`, `new Map([[k, v]])`): a Swift array literal
            this.write('[');
            this.writeCommaSeparated(expr.values, v => this.writeExpression(v), false);
            this.write(']');
            return;
        }
        if (expr.type) {
            this._writeType(expr.type, { forNew: true });
            this.write('(');
            if (expr.values) {
                this.writeCommaSeparated(expr.values, v => this.writeExpression(v), false);
            } else if (expr.sizeExpression) {
                this.writeExpression(expr.sizeExpression);
            }
            this.write(')');
        } else if (expr.values && expr.values.length > 0) {
            this.write('List(');
            this.writeCommaSeparated(expr.values, v => this.writeExpression(v), false);
            this.write(')');
        } else {
            this._context.addNodeDiagnostics(expr, 'Unknown array type', ts.DiagnosticCategory.Error);
        }
    }

    /** A record literal's labelled arguments in the memberwise init's order (Swift requires it), not the literal's. */
    private _inParameterOrder(type: cs.TypeNode, args: cs.Expression[]): cs.Expression[] {
        const ctor = cs.isClassDeclaration(type)
            ? (type.members.find(m => cs.isConstructorDeclaration(m)) as cs.ConstructorDeclaration | undefined)
            : undefined;
        if (!ctor || !args.every(a => cs.isLabeledExpression(a))) {
            return args;
        }
        const order = ctor.parameters.map(p => p.name);
        const rank = (a: cs.Expression) => order.indexOf((a as cs.LabeledExpression).label);
        return [...args].sort((a, b) => rank(a) - rank(b));
    }

    private _resolveTypeNode(t: cs.TypeNode): cs.TypeNode {
        let ref: cs.TypeReferenceType = t;
        while (typeof ref !== 'string' && cs.isTypeReference(ref)) {
            ref = ref.reference;
        }
        return typeof ref === 'string' ? t : (ref as cs.TypeNode);
    }

    protected writeMemberAccessExpression(expr: cs.MemberAccessExpression) {
        const isEmpty = cs.isIdentifier(expr.expression) && expr.expression.text.length === 0;
        const name = this._context.getSymbolName(expr) ?? expr.member;
        if (!isEmpty) {
            // enum to number: Kotlin's `e.toDouble()` -> `Double(e.rawValue)` (see writeInvocationExpression)
            this.writeExpression(expr.expression);
            // `x!?.m`: the `!` already unwrapped it; `a?.b?.c` with a non-optional `b` continues the chain with `.`
            this.write(
                expr.nullSafe && !this._isUnwrapped(expr.expression) && !this._isDeclaredNonNullable(expr.expression) ? '?.' : '.'
            );
        }
        // the shared transform spells tuple `x[0]` as Kotlin's `x.v0`; a Swift tuple reads `x.0`
        const tsNode = expr.tsNode;
        if (tsNode && ts.isElementAccessExpression(tsNode) && /^v\d+$/.test(name) && this._isSwiftTuple(tsNode.expression)) {
            this.write(name.substring(1));
            return;
        }
        this.writeIdentifier(this._swiftMemberName(name));
        if (this._isNarrowedNullableGetter(expr)) {
            this.write('!');
        }
    }

    /** `o.value` of a `T | null` getter that TS narrowed to `T` here (smart-cast lowering covers only fields). */
    private _isNarrowedNullableGetter(expr: cs.MemberAccessExpression): boolean {
        const tsNode = expr.tsNode;
        if (!tsNode || !ts.isPropertyAccessExpression(tsNode) || (expr.parent && cs.isNonNullExpression(expr.parent))) {
            return false;
        }
        const checker = this._context.typeChecker;
        const symbol = checker.getSymbolAtLocation(tsNode.name);
        if (!symbol || !(symbol.flags & ts.SymbolFlags.GetAccessor)) {
            return false;
        }
        const property = checker.getPropertyOfType(checker.getTypeAtLocation(tsNode.expression), symbol.name);
        const declared = property && checker.getTypeOfSymbol(property);
        const narrowed = checker.getTypeAtLocation(tsNode);
        const isNullable = (t: ts.Type) =>
            !!(t.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined)) ||
            (t.isUnion() && t.types.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined))));
        return !!declared && isNullable(declared) && !isNullable(narrowed);
    }

    /** A TS tuple prints as a Swift tuple; a union of tuples has a hand-written class (Kotlin's partial) with `v0`... */
    private _isSwiftTuple(expr: ts.Expression): boolean {
        const checker = this._context.typeChecker;
        return checker.isTupleType(checker.getNonNullableType(checker.getTypeAtLocation(expr)));
    }

    /** Kotlin-only member spellings the shared transformer produces. */
    private _swiftMemberName(name: string): string {
        switch (name) {
            case 'length.toDouble()':
                return 'length';
        }
        return name;
    }

    protected writeElementAccessExpression(expr: cs.ElementAccessExpression) {
        this.writeExpression(expr.expression);
        let index = expr.argumentExpression;
        while (cs.isParenthesizedExpression(index) || cs.isCastExpression(index)) {
            index = index.expression;
        }
        const tsNode = expr.tsNode;
        if (tsNode && ts.isElementAccessExpression(tsNode) && cs.isNumericLiteral(index) && /^\d+$/.test(index.value)) {
            if (this._isSwiftTuple(tsNode.expression)) {
                // `t?.[1]` on a tuple: Swift reads tuple elements by `.1`
                this.write(expr.nullSafe ? `?.${index.value}` : `.${index.value}`);
                return;
            }
        }
        if (!expr.nullSafe && tsNode && (this._context as SwiftEmitterContext).throwsAnalysis.isThrowingElementRead(tsNode)) {
            this.write('.jsElement(');
            if (cs.isNumericLiteral(index) && /^\d+$/.test(index.value)) {
                this.write(index.value);
            } else {
                this.writeExpression(expr.argumentExpression);
            }
            this.write(')');
            return;
        }
        this.write(expr.nullSafe ? '?[' : '[');
        if (cs.isNumericLiteral(index) && /^\d+$/.test(index.value)) {
            // a literal index is an `Int` (the runtime subscripts take `Int`), whatever suffix the operand got
            this.write(index.value);
            this.write(']');
            return;
        }
        this.writeExpression(expr.argumentExpression);
        this.write(']');
    }

    protected writeNewExpression(expr: cs.NewExpression) {
        const resolved = this._resolveTypeNode(expr.type);
        if (cs.isArrayTupleNode(resolved)) {
            this.write('(');
            this.writeCommaSeparated(expr.arguments, a => this.writeExpression(a), false);
            this.write(')');
            return;
        }

        const lengthArg = expr.arguments.length === 1 ? expr.arguments[0] : undefined;
        if (
            cs.isArrayTypeNode(resolved) &&
            lengthArg &&
            !cs.isCastExpression(lengthArg) &&
            this._isNumericExpression(lengthArg)
        ) {
            // `new Array<number>(n)` is a length; `List<Double>(31.0)` would be a one-element list
            this._writeType(expr.type, { forNew: true });
            this.write('(');
            const forceInteger = this._forceInteger;
            this._forceInteger = true;
            this._writeIntOperand(this._unwrapLiteral(lengthArg));
            this._forceInteger = forceInteger;
            this.write(')');
            return;
        }

        if (expr.objectInitializers?.length) {
            this.write('with(');
        }
        this._writeType(expr.type, { forNew: true });
        this.write('(');
        this.writeCommaSeparated(this._inParameterOrder(resolved, expr.arguments), a => this.writeExpression(a), false);
        this.write(')');

        if (expr.objectInitializers?.length) {
            this.write(')');
            this._openBrace();
            for (const a of expr.objectInitializers) {
                this.write('$0.');
                this.write(a.label);
                this.write(' = ');
                this.writeExpression(a.expression);
                this.writeLine();
            }
            this._closeBrace(false);
        }
    }

    protected writeCastExpression(expr: cs.CastExpression) {
        // Kotlin's `x.promise as Deferred<T>` before `.await()`: the Promise object is already the runtime's Promise
        if (cs.isTypeReference(expr.type) && expr.type.isAsync) {
            this.writeExpression(expr.expression);
            return;
        }
        if (cs.isPrimitiveTypeNode(expr.type)) {
            switch (expr.type.type) {
                case cs.PrimitiveType.Double: {
                    const inner = this._unwrapParens(expr.expression);
                    if (this._isDeclaredUnknown(inner)) {
                        // `unknown`/`any` stays `Any?` in Swift, even where TS narrowed it to a number
                        this.write('TypeHelper.unknownToNumber(');
                        this.writeExpression(cs.isNonNullExpression(inner) ? inner.expression : inner);
                        this.write(')');
                        return;
                    }
                    if (!this._forceInteger && this._isBitOp(inner)) {
                        this.writeExpression(inner);
                        return;
                    }
                    if (this._forceInteger || this._isNumericExpression(expr.expression)) {
                        this.writeExpression(this._unwrapLiteral(expr.expression));
                        return;
                    }
                    if (cs.isCastExpression(inner) && cs.isPrimitiveTypeNode(inner.type) && inner.type.type === cs.PrimitiveType.Double) {
                        // already converted (the transformer casts an enum operand, then the sum)
                        this.writeExpression(expr.expression);
                        return;
                    }
                    if (this._isEnumExpression(expr.expression)) {
                        this.write('Double(');
                        this.writeExpression(expr.expression);
                        this.write('.rawValue)');
                        return;
                    }
                    this.write('Double(');
                    this.writeExpression(expr.expression);
                    this.write(')');
                    return;
                }
                case cs.PrimitiveType.Int: {
                    const inner = this._unwrapLiteral(expr.expression);
                    if (this._isIntegerLiteral(inner)) {
                        this.writeExpression(inner);
                        return;
                    }
                    if (cs.isParenthesizedExpression(expr.expression)) {
                        this.writeExpression(expr.expression);
                    } else {
                        this.write('(');
                        this.writeExpression(expr.expression);
                        this.write(')');
                    }
                    this.write('.toInt()');
                    return;
                }
                case cs.PrimitiveType.Long:
                    if (this._isDeclaredUnknown(this._unwrapParens(expr.expression))) {
                        // `x as bigint` from `unknown`, as `unknownToNumber`
                        this.write('TypeHelper.unknownToInt64(');
                        this.writeExpression(expr.expression);
                        this.write(')');
                        return;
                    }
                    this.write('Int64(');
                    this.writeExpression(expr.expression);
                    this.write(')');
                    return;
            }
        }

        if (this._isNonNullCast(expr)) {
            this.writeExpression(expr.expression);
            this.write('!');
            return;
        }

        if (cs.isPrimitiveTypeNode(expr.type) && expr.type.type === cs.PrimitiveType.String && this._isStringExpression(expr.expression)) {
            this.writeExpression(expr.expression);
            return;
        }

        if (this._isNoOpNullableCast(expr)) {
            this.writeExpression(expr.expression);
            return;
        }

        const resolvedTarget = this._resolveTypeNode(expr.type);
        if (cs.isArrayTypeNode(resolvedTarget) && this._isDeclaredUnknown(this._unwrapParens(expr.expression))) {
            // `v as T[]` from `unknown`: the list may hold `T?` or `Any?` elements (JSON), which `as!` cannot convert;
            // `v as T[] | null` keeps a null
            this.write(expr.type.isNullable || resolvedTarget.isNullable ? 'TypeHelper.unknownToNullableList(' : 'TypeHelper.unknownToList(');
            this.writeExpression(expr.expression);
            this.write(', ');
            this._writeType(resolvedTarget.elementType, {});
            this.write('.self)');
            return;
        }

        if (this._isImplicitArrayWidening(expr)) {
            // `T[]` passed as `(T | undefined)[]`: Swift classes are invariant, so `as!` would trap.
            // shortcut: a copy, so a callee that mutates the array no longer changes the caller's;
            // alphaTab's callers (Atnf.args) only read it. Revisit if a mutating one appears.
            this._writeType(expr.type, { nullable: false });
            this.write('(widening: ');
            this.writeExpression(expr.expression);
            this.write(')');
            return;
        }

        if (!expr.type.isNullable && this._isThrowingAssertion(expr)) {
            this._writeJsCast(expr.expression, expr.type);
            return;
        }

        const parens = !expr.parent || !cs.isParenthesizedExpression(expr.parent);
        if (parens) {
            this.write('(');
        }
        this.writeExpression(expr.expression);
        if (cs.isPrimitiveTypeNode(expr.type) && expr.type.type === cs.PrimitiveType.Object) {
            // to `any`/`unknown` is an upcast
            this.write(' as ');
            this._writeType(expr.type, { owner: expr });
        } else if (this._isUpcast(expr)) {
            this.write(' as ');
            this._writeType(expr.type, { nullable: false });
        } else {
            this.write(expr.type.isNullable ? ' as? ' : ' as! ');
            this._writeType(expr.type, { nullable: false });
        }
        if (parens) {
            this.write(')');
        }
    }

    /** A TS `x!` or `x as T` that can fail: the runtime's throwing helpers (`SwiftThrows.isThrowingAssertion`). */
    private _isThrowingAssertion(expr: cs.Node): boolean {
        return !!expr.tsNode && (this._context as SwiftEmitterContext).throwsAnalysis.isThrowingAssertion(expr.tsNode);
    }

    /** `jsCast(x, T.self)`: throws where Kotlin's `as` and C#'s cast throw (Swift's `as!` traps). */
    private _writeJsCast(value: cs.Expression, type: cs.TypeNode) {
        this.write('jsCast(');
        this.writeExpression(value);
        const t = this._capture(() => this._writeType(type, { nullable: false }));
        this.write(`, ${t.startsWith('any ') ? `(${t})` : t}.self)`);
    }

    /** A field the printer declares `T!`: no initializer and a type with no Swift zero value. */
    private _isImplicitlyUnwrappedField(expr: cs.Expression): boolean {
        const tsNode = this._unwrapParens(expr).tsNode;
        if (!tsNode || !ts.isPropertyAccessExpression(tsNode)) {
            return false;
        }
        const checker = this._context.typeChecker;
        const declaration = checker.getSymbolAtLocation(tsNode.name)?.valueDeclaration;
        if (
            !declaration ||
            !ts.isPropertyDeclaration(declaration) ||
            declaration.initializer ||
            declaration.questionToken ||
            this._implementsRequiredInterfaceMember(declaration)
        ) {
            return false;
        }
        const t = checker.getTypeAtLocation(declaration);
        const parts = t.isUnion() ? t.types : [t];
        const zeroOrOptional =
            ts.TypeFlags.Null | ts.TypeFlags.Undefined | ts.TypeFlags.NumberLike | ts.TypeFlags.BooleanLike | ts.TypeFlags.Any | ts.TypeFlags.Unknown;
        return !parts.some(u => !!(u.flags & zeroOrOptional) && !(u.flags & ts.TypeFlags.EnumLike));
    }

    /** `Any?` in Swift: declared `unknown`/`any`, or cast to `any`/`undefined` (`v as undefined`). */
    private _isAnyValue(expr: cs.Expression): boolean {
        const e = this._unwrapParens(expr);
        if (cs.isCastExpression(e) && cs.isPrimitiveTypeNode(e.type) && e.type.type === cs.PrimitiveType.Object) {
            return true;
        }
        return this._isDeclaredUnknown(e);
    }

    /** `"" + x` (JS `String(x)`) or `"a" + x` with `x` of type `unknown`/`any`: Swift has no `String + Any?`. */
    /**
     * `'<rect x="' + x + '" y="' + y + ...`: Swift's type checker gives up on a `+` chain of this many operands,
     * so the pieces go into an array literal, which it checks one element at a time.
     */
    private _writeLongStringConcat(expr: cs.BinaryExpression): boolean {
        const operands: cs.Expression[] = [];
        let e: cs.Expression = expr;
        while (cs.isBinaryExpression(e) && e.operator === '+') {
            operands.unshift(e.right);
            e = e.left;
        }
        operands.unshift(e);
        if (operands.length < 7 || !operands.some(o => cs.isStringLiteral(o))) {
            return false;
        }
        this.write('[');
        this.writeCommaSeparated(operands, o => this.writeExpression(o), false);
        this.write('].joined()');
        return true;
    }

    /** `'&#' + symbol` with a numeric enum: Kotlin's `symbol.toDouble()` is a Double, which Swift does not append to a String. */
    private _writeStringConcatWithEnum(expr: cs.BinaryExpression): boolean {
        const isString = (e: cs.Expression) => cs.isStringLiteral(this._unwrapParens(e)) || this._isStringExpression(e);
        const isEnumNumber = (e: cs.Expression) => {
            const u = this._unwrapParens(e);
            // `symbol as number`
            if (cs.isCastExpression(u)) {
                return this._isEnumExpression(u.expression) && !this._isOptionalValue(u.expression);
            }
            return (
                cs.isInvocationExpression(u) &&
                u.arguments.length === 0 &&
                cs.isMemberAccessExpression(u.expression) &&
                u.expression.member === 'toDouble' &&
                this._isEnumExpression(u.expression.expression) &&
                !this._isOptionalValue(u.expression.expression)
            );
        };
        const leftEnum = isEnumNumber(expr.left) && isString(expr.right);
        const rightEnum = isEnumNumber(expr.right) && isString(expr.left);
        if (!leftEnum && !rightEnum) {
            return false;
        }
        const operand = (e: cs.Expression, wrap: boolean) => {
            if (wrap) {
                this.write('(');
                this.writeExpression(e);
                this.write(').toInvariantString()');
            } else {
                this.writeExpression(e);
            }
        };
        operand(expr.left, leftEnum);
        this.write(' + ');
        operand(expr.right, rightEnum);
        return true;
    }

    private _writeStringConcatWithUnknown(expr: cs.BinaryExpression): boolean {
        const isString = (e: cs.Expression) => cs.isStringLiteral(this._unwrapParens(e)) || this._isStringExpression(e);
        const leftUnknown = this._isDeclaredUnknown(expr.left) && isString(expr.right);
        const rightUnknown = this._isDeclaredUnknown(expr.right) && isString(expr.left);
        if (!leftUnknown && !rightUnknown) {
            return false;
        }
        const operand = (e: cs.Expression, unknown: boolean) => {
            if (unknown) {
                this.write('jsTemplate(');
                this.writeExpression(e);
                this.write(')');
            } else {
                this.writeExpression(e);
            }
        };
        operand(expr.left, leftUnknown);
        this.write(' + ');
        operand(expr.right, rightUnknown);
        return true;
    }

    /** Declared (not narrowed) as `unknown` or `any`. */
    private _isDeclaredUnknown(expr: cs.Expression): boolean {
        let e = this._unwrapParens(expr);
        if (cs.isNonNullExpression(e)) {
            e = this._unwrapParens(e.expression);
        }
        const tsNode = e.tsNode;
        if (!tsNode) {
            return false;
        }
        const checker = this._context.typeChecker;
        const symbol = ts.isIdentifier(tsNode) ? checker.getSymbolAtLocation(tsNode) : undefined;
        const t = symbol?.valueDeclaration
            ? checker.getTypeOfSymbolAtLocation(symbol, symbol.valueDeclaration)
            : checker.getTypeAtLocation(tsNode);
        return !!(t.flags & (ts.TypeFlags.Unknown | ts.TypeFlags.Any));
    }

    /** Declared (not narrowed) as a string: a narrowed `Any?` still needs its cast in Swift. */
    private _isStringExpression(expr: cs.Expression): boolean {
        const tsNode = this._unwrapParens(expr).tsNode;
        if (!tsNode) {
            return false;
        }
        const checker = this._context.typeChecker;
        const symbol = ts.isIdentifier(tsNode) ? checker.getSymbolAtLocation(tsNode) : undefined;
        const t = symbol?.valueDeclaration
            ? checker.getTypeOfSymbolAtLocation(symbol, symbol.valueDeclaration)
            : checker.getTypeAtLocation(tsNode);
        return !!(t.flags & ts.TypeFlags.StringLike);
    }

    /** A cast the transformer added (no `as` in the TS) from `T[]` to `(T | undefined)[]`. */
    private _isImplicitArrayWidening(expr: cs.CastExpression): boolean {
        const tsNode = expr.tsNode;
        if (!tsNode || ts.isAsExpression(tsNode) || ts.isTypeAssertionExpression(tsNode) || !ts.isExpression(tsNode)) {
            return false;
        }
        const checker = this._context.typeChecker;
        const source = checker.getTypeAtLocation(tsNode);
        const target = checker.getContextualType(tsNode);
        if (!target || source === target || !checker.isArrayType(source) || !checker.isArrayType(target)) {
            return false;
        }
        const sourceElement = checker.getTypeArguments(source as ts.TypeReference)[0];
        const targetElement = checker.getTypeArguments(target as ts.TypeReference)[0];
        return sourceElement !== targetElement && checker.getNonNullableType(targetElement) === checker.getNonNullableType(sourceElement);
    }

    /** `x as T` where TS already knows `x` is a `T`: Swift's `as` (cannot fail). */
    private _isUpcast(expr: cs.CastExpression): boolean {
        const tsNode = expr.tsNode;
        if (!tsNode || !ts.isAsExpression(tsNode)) {
            return false;
        }
        // narrowed in TS (`instanceof`) but still `Any?` in Swift
        if (this._isDeclaredUnknown(expr.expression)) {
            return false;
        }
        const checker = this._context.typeChecker;
        const source = checker.getTypeAtLocation(tsNode.expression);
        const target = checker.getTypeAtLocation(tsNode.type);
        if (source === target || !(target.flags & ts.TypeFlags.Object) || !checker.isTypeAssignableTo(source, target)) {
            return false;
        }
        // TS is structural, Swift nominal: a declared class or interface target must be a declared supertype
        if (!this._isDeclaredInSource(target.symbol)) {
            return true;
        }
        const parts = source.isUnion() ? checker.getNonNullableType(source) : source;
        return (parts.isUnion() ? parts.types : [parts]).every(
            p => !this._isDeclaredInSource(p.symbol) || this._nominalSupertypes(p.symbol).has(target.symbol)
        );
    }

    /** A class or interface declared in the transpiled sources (not a lib .d.ts). */
    private _isDeclaredInSource(symbol: ts.Symbol | undefined): boolean {
        return !!symbol?.declarations?.some(
            d => (ts.isClassDeclaration(d) || ts.isInterfaceDeclaration(d)) && !d.getSourceFile().isDeclarationFile
        );
    }

    /** The symbol and every class or interface it extends or implements, transitively. */
    private _nominalSupertypes(symbol: ts.Symbol, out: Set<ts.Symbol> = new Set()): Set<ts.Symbol> {
        if (out.has(symbol)) {
            return out;
        }
        out.add(symbol);
        const checker = this._context.typeChecker;
        for (const d of symbol.declarations ?? []) {
            if (!ts.isClassDeclaration(d) && !ts.isInterfaceDeclaration(d)) {
                continue;
            }
            for (const clause of d.heritageClauses ?? []) {
                for (const t of clause.types) {
                    const s = checker.getTypeAtLocation(t).symbol;
                    if (s) {
                        this._nominalSupertypes(s, out);
                    }
                }
            }
        }
        return out;
    }

    /** A class field that implements a non-optional property of an interface the class implements. */
    private _implementsRequiredInterfaceMember(declaration: ts.Declaration): boolean {
        const cls = declaration.parent;
        const name = ts.getNameOfDeclaration(declaration);
        if (!ts.isClassDeclaration(cls) || !cls.name || !name || !ts.isIdentifier(name)) {
            return false;
        }
        const checker = this._context.typeChecker;
        const classSymbol = checker.getSymbolAtLocation(cls.name);
        if (!classSymbol) {
            return false;
        }
        for (const s of this._nominalSupertypes(classSymbol)) {
            if (s === classSymbol || !s.declarations?.some(ts.isInterfaceDeclaration)) {
                continue;
            }
            const member = s.members?.get(name.escapedText);
            const decl = member?.valueDeclaration;
            if (decl && ts.isPropertySignature(decl) && !decl.questionToken) {
                const t = checker.getTypeOfSymbolAtLocation(member!, decl);
                if (!(t.isUnion() && t.types.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined))))) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Kotlin's smart-cast lowering `(mode as Mode?)` on a `Mode | null` local: nothing to cast in Swift. */
    private _isNoOpNullableCast(expr: cs.CastExpression): boolean {
        if (!expr.type.isNullable) {
            return false;
        }
        const source = this._tsTypeOf(this._unwrapParens(expr.expression));
        const target = this._resolveTypeNode(expr.type);
        if (!source || !source.isUnion() || !target.tsNode) {
            return false;
        }
        const checker = this._context.typeChecker;
        const nonNull = checker.getBaseTypeOfLiteralType(checker.getNonNullableType(source));
        return !!nonNull.symbol && nonNull.symbol === checker.getTypeAtLocation(target.tsNode).symbol;
    }

    /** `T & {}` to `T` is an unwrap, not a cast: `value!`. */
    private _isNonNullCast(expr: cs.CastExpression): boolean {
        const target = this._resolveTypeNode(expr.type);
        if (target.nodeType !== cs.SyntaxKind.TypeParameterDeclaration) {
            return false;
        }
        const source = this._tsTypeOf(expr.expression);
        const name = (target as cs.TypeParameterDeclaration).name;
        return (
            !!source &&
            source.isIntersection() &&
            source.types.some(u => !!(u.flags & ts.TypeFlags.TypeParameter) && u.symbol?.name === name)
        );
    }

    /** `(2.0)` -> `2.0`: Kotlin's `(2.0).toDouble()` parentheses are not needed. */
    private _unwrapLiteral(expr: cs.Expression): cs.Expression {
        let e = expr;
        while (cs.isParenthesizedExpression(e)) {
            e = e.expression;
        }
        return cs.isNumericLiteral(e) ? e : expr;
    }

    /** A TS `number` expression: a cast to Double is a no-op. */
    private _isNumericExpression(expr: cs.Expression): boolean {
        if (cs.isNumericLiteral(expr)) {
            return true;
        }
        const t = this._tsTypeOf(expr);
        if (!t) {
            return false;
        }
        return !!(t.flags & ts.TypeFlags.NumberLike) && !(t.flags & ts.TypeFlags.EnumLike);
    }

    protected writeNonNullExpression(expr: cs.NonNullExpression) {
        if (this._isThrowingAssertion(expr)) {
            // throws where Kotlin's `!!` throws (Swift's `!` traps)
            this.write('jsNonNull(');
            this.writeExpression(expr.expression);
            this.write(')');
            return;
        }
        this.writeExpression(expr.expression);
        if (!this._isUnwrapped(expr.expression) && !this._isDeclaredNonNullable(expr.expression)) {
            this.write('!');
        }
    }

    /** The value's class declares `toString()` itself (not only `Object`'s). */
    private _hasOwnToString(e: cs.Expression): boolean {
        const t = this._tsTypeOf(this._unwrapParens(e));
        const declarations = t && this._context.typeChecker.getNonNullableType(t).getProperty('toString')?.declarations;
        return !!declarations?.some(d => !d.getSourceFile().isDeclarationFile);
    }

    /** A class or interface instance (a Swift reference type); not `null`, a tuple or a primitive. */
    private _isReference(e: cs.Expression): boolean {
        const t = this._tsTypeOf(this._unwrapParens(e));
        if (!t) {
            return false;
        }
        const checker = this._context.typeChecker;
        let nonNull = checker.getNonNullableType(t);
        if (nonNull.flags & ts.TypeFlags.TypeParameter) {
            // `this` is a type parameter: its apparent type is the class
            nonNull = checker.getApparentType(nonNull);
        }
        return !!(nonNull.flags & ts.TypeFlags.Object) && !checker.isTupleType(nonNull) && !!nonNull.symbol && !!(nonNull.symbol.flags & (ts.SymbolFlags.Class | ts.SymbolFlags.Interface));
    }

    /** Optional in Swift: declared with `null`/`undefined` and not unwrapped where it is used. */
    private _isOptionalValue(e: cs.Expression): boolean {
        if (this._isUnwrapped(e)) {
            return false;
        }
        const tsNode = this._unwrapParens(e).tsNode;
        if (!tsNode) {
            return false;
        }
        const checker = this._context.typeChecker;
        const symbol =
            ts.isPropertyAccessExpression(tsNode) || ts.isIdentifier(tsNode)
                ? checker.getSymbolAtLocation(ts.isPropertyAccessExpression(tsNode) ? tsNode.name : tsNode)
                : undefined;
        const t = symbol && symbol.flags & (ts.SymbolFlags.Property | ts.SymbolFlags.Variable)
            ? checker.getTypeOfSymbol(symbol)
            : checker.getTypeAtLocation(tsNode);
        return t.isUnion() && t.types.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined)));
    }

    /** Already prints its own `!`: a nested non-null, or a narrowed nullable local. */
    private _isUnwrapped(e: cs.Expression): boolean {
        const inner = this._unwrapParens(e);
        return cs.isNonNullExpression(inner) || (cs.isIdentifier(inner) && this._isNarrowedNullableLocal(inner));
    }

    /** Declared without `null`/`undefined` (TS `!` on a non-optional field, call result or local): nothing to unwrap. */
    private _isDeclaredNonNullable(e: cs.Expression): boolean {
        const tsNode = this._unwrapParens(e).tsNode;
        const checker = this._context.typeChecker;
        if (tsNode && ts.isElementAccessExpression(tsNode)) {
            // a list subscript returns a non-optional element (a tuple element is typed per position)
            const target = checker.getNonNullableType(checker.getTypeAtLocation(tsNode.expression));
            if (!checker.isArrayType(target)) {
                return false;
            }
        } else if (!tsNode || !(ts.isPropertyAccessExpression(tsNode) || ts.isIdentifier(tsNode) || ts.isCallExpression(tsNode))) {
            return false;
        }
        let t: ts.Type;
        if (ts.isElementAccessExpression(tsNode)) {
            // the declared element type: `x[0] !== undefined` narrows the access, but Swift's subscript stays optional
            const target = checker.getNonNullableType(checker.getTypeAtLocation(tsNode.expression));
            t = checker.getTypeArguments(target as ts.TypeReference)[0];
        } else if (ts.isCallExpression(tsNode)) {
            t = checker.getTypeAtLocation(tsNode);
        } else {
            const symbol = checker.getSymbolAtLocation(ts.isPropertyAccessExpression(tsNode) ? tsNode.name : tsNode);
            if (!symbol || !(symbol.flags & (ts.SymbolFlags.Property | ts.SymbolFlags.Variable))) {
                return false;
            }
            t = checker.getTypeOfSymbol(symbol);
        }
        const loose =
            ts.TypeFlags.Null |
            ts.TypeFlags.Undefined |
            ts.TypeFlags.Void |
            ts.TypeFlags.Any |
            ts.TypeFlags.Unknown |
            ts.TypeFlags.TypeParameter;
        const parts = t.isUnion() ? t.types : [t];
        return !parts.some(u => !!(u.flags & loose));
    }

    private _flattenedMapGets = new Set<cs.InvocationExpression>();

    /** `m.get(k)` on a map whose values may be null: Swift's `get` returns `V??`. */
    private _isOptionalValueMapGet(expr: cs.InvocationExpression): boolean {
        const tsNode = expr.tsNode;
        if (!tsNode || !ts.isCallExpression(tsNode) || !ts.isPropertyAccessExpression(tsNode.expression) || tsNode.expression.name.text !== 'get' || tsNode.arguments.length !== 1) {
            return false;
        }
        const checker = this._context.typeChecker;
        const mapType = checker.getNonNullableType(checker.getTypeAtLocation(tsNode.expression.expression));
        if (mapType.symbol?.name !== 'Map') {
            return false;
        }
        const value = checker.getTypeArguments(mapType as ts.TypeReference)[1];
        const parts = value ? (value.isUnion() ? value.types : [value]) : [];
        return parts.some(u => !!(u.flags & (ts.TypeFlags.Null | ts.TypeFlags.Undefined)));
    }

    private _isErrorCause(expr: cs.InvocationExpression): boolean {
        const symbol = expr.tsSymbol;
        const owner = symbol?.declarations?.[0]?.parent;
        return symbol?.name === 'cause' && !!owner && ts.isInterfaceDeclaration(owner) && owner.name.text === 'Error';
    }

    protected override writeInvocationExpression(expr: cs.InvocationExpression): void {
        if (!this._flattenedMapGets.has(expr) && this._isOptionalValueMapGet(expr)) {
            // JS returns undefined for a missing key and for a stored null alike: flatten `V??` to `V?`
            this._flattenedMapGets.add(expr);
            this.write('(');
            this.writeInvocationExpression(expr);
            this.write(' ?? nil)');
            return;
        }
        // the shared transform calls `Error.cause` like a method; JsError has it as a property
        if (expr.arguments.length === 0 && expr.tsNode && ts.isPropertyAccessExpression(expr.tsNode) && this._isErrorCause(expr)) {
            this.writeExpression(expr.expression);
            return;
        }
        // Kotlin's enum-to-number lowering: `e.toDouble()` -> `Double(e.rawValue)`
        if (
            expr.arguments.length === 0 &&
            cs.isMemberAccessExpression(expr.expression) &&
            expr.expression.member === 'toDouble' &&
            this._isEnumExpression(expr.expression.expression)
        ) {
            if (this._isOptionalValue(expr.expression.expression)) {
                this.writeExpression(expr.expression.expression);
                this.write('.map { Double($0.rawValue) }');
                return;
            }
            this.write('Double(');
            this.writeExpression(expr.expression.expression);
            this.write('.rawValue)');
            return;
        }
        // the shared transformer wraps some conditions twice: `isTruthy(isTruthy(x))` -> `isTruthy(x)`
        if (this._isTruthyCall(expr) && this._isTruthyCall(this._unwrapParens(expr.arguments[0]))) {
            this.writeExpression(expr.arguments[0]);
            return;
        }
        // Kotlin's tuple assignment `rhs.let { a = it.v0 ... }` -> `(a, b) = rhs`
        if (
            expr.arguments.length === 1 &&
            cs.isBlock(expr.arguments[0] as cs.Node) &&
            cs.isMemberAccessExpression(expr.expression) &&
            expr.expression.member === 'let'
        ) {
            const block = expr.arguments[0] as unknown as cs.Block;
            this.write('(');
            this.writeCommaSeparated(
                block.statements,
                st => this.writeExpression(((st as cs.ExpressionStatement).expression as cs.BinaryExpression).left),
                false
            );
            this.write(') = ');
            this.writeExpression(expr.expression.expression);
            return;
        }
        // Kotlin's enum-to-name lowering: `d.toString()` -> `String(describing: d)`
        if (
            expr.arguments.length === 0 &&
            cs.isMemberAccessExpression(expr.expression) &&
            expr.expression.member === 'toString' &&
            this._isEnumExpression(expr.expression.expression)
        ) {
            this.write('String(describing: ');
            this.writeExpression(expr.expression.expression);
            this.write(')');
            return;
        }
        // `Number(s)`: the shared transformer builds C#'s `Double.Parse(s, InvariantCulture)`
        if (
            expr.arguments.length === 2 &&
            cs.isMemberAccessExpression(expr.expression) &&
            expr.expression.member === 'Parse' &&
            cs.isIdentifier(expr.arguments[1]) &&
            expr.arguments[1].text === 'System.Globalization.CultureInfo.InvariantCulture'
        ) {
            this.write('Double(');
            this.writeExpression(expr.arguments[0]);
            this.write(') ?? Double.nan');
            return;
        }
        if (this._writeSuspendToDeferred(expr) || this._writePromiseChainHead(expr)) {
            return;
        }
        this.writeExpression(expr.expression);
        if (expr.nullSafe) {
            this.write('?');
        }
        this.write('(');
        const isListSplice =
            cs.isMemberAccessExpression(expr.expression) &&
            (expr.expression.member === 'push' || expr.expression.member === 'splice');
        this.writeCommaSeparated(
            expr.arguments,
            a => {
                if (isListSplice && cs.isSpreadExpression(a)) {
                    this.write('contentsOf: ');
                }
                this.writeExpression(a);
            },
            false
        );
        this.write(')');
    }

    /**
     * `loadFile(path).then(f).catch(g)`: a Swift `async` function is no object to chain on, so the call starts a
     * runtime `Promise` (the Kotlin `Deferred` with `then` and `catch`) and the chain continues on that.
     */
    private _isSuspendToDeferred(e: cs.Expression): e is cs.InvocationExpression {
        return (
            cs.isInvocationExpression(e) &&
            cs.isMemberAccessExpression(e.expression) &&
            e.expression.member === 'suspendToDeferred' &&
            e.arguments.length === 1 &&
            cs.isLambdaExpression(e.arguments[0])
        );
    }

    /**
     * `read(path)` of an `async` function that nobody awaits: the shared transform wraps it in Kotlin's
     * `suspendToDeferred { read(path) }`, a started `Deferred`; here that is a runtime `Promise` for the call.
     */
    private _writeSuspendToDeferred(expr: cs.InvocationExpression): boolean {
        if (!this._isSuspendToDeferred(expr)) {
            return false;
        }
        const lambda = expr.arguments[0] as cs.LambdaExpression;
        let inner: cs.Expression | undefined;
        if (cs.isBlock(lambda.body)) {
            const only = lambda.body.statements.length === 1 ? lambda.body.statements[0] : undefined;
            inner = only && cs.isExpressionStatement(only) ? only.expression : only && cs.isReturnStatement(only) ? only.expression : undefined;
        } else {
            inner = lambda.body;
        }
        if (!inner) {
            return false;
        }
        const analysis = (this._context as SwiftEmitterContext).throwsAnalysis;
        this.write(inner.tsNode && analysis.containsThrowingCall(inner.tsNode) ? 'Promise({ try await ' : 'Promise({ await ');
        this.writeExpression(inner);
        this.write(' })');
        return true;
    }

    private _writePromiseChainHead(expr: cs.InvocationExpression): boolean {
        const chain = ['then', 'catch', 'finally'];
        if (!cs.isMemberAccessExpression(expr.expression) || !chain.includes(expr.expression.member)) {
            return false;
        }
        const receiver = this._unwrapParens(expr.expression.expression);
        if (cs.isInvocationExpression(receiver) && cs.isMemberAccessExpression(receiver.expression) && chain.includes(receiver.expression.member)) {
            return false;
        }
        if (this._tsTypeOf(receiver)?.getSymbol()?.name !== 'Promise' || this._isSuspendToDeferred(receiver)) {
            return false;
        }
        const analysis = (this._context as SwiftEmitterContext).throwsAnalysis;
        this.write(receiver.tsNode && analysis.containsThrowingCall(receiver.tsNode) ? 'Promise({ try await ' : 'Promise({ await ');
        this.writeExpression(receiver);
        this.write(` }).${this.escapeIdentifier(expr.expression.member)}(`);
        this.writeCommaSeparated(expr.arguments, a => this.writeExpression(a), false);
        this.write(')');
        return true;
    }

    private _isTruthyCall(e: cs.Expression): e is cs.InvocationExpression {
        return (
            cs.isInvocationExpression(e) &&
            e.arguments.length === 1 &&
            cs.isMemberAccessExpression(e.expression) &&
            e.expression.member === 'isTruthy'
        );
    }

    protected writeYieldExpression(expr: cs.YieldExpression) {
        if (expr.expression) {
            this.write('yield(');
            this.writeExpression(expr.expression);
            this.write(')');
        } else {
            this.write('return');
        }
    }

    protected writeLabeledExpression(expr: cs.LabeledExpression) {
        this.write(expr.label);
        this.write(': ');
        this.writeExpression(expr.expression);
    }

    protected writeDeconstructDeclaration(expr: cs.DeconstructDeclaration) {
        this.write('(');
        this.writeCommaSeparated(expr.names, v => this.write(this.escapeIdentifier(v)), false);
        this.write(')');
    }

    protected override writeDefaultExpression(_d: cs.DefaultExpression): void {
        this.write('nil');
    }

    protected override writeIsExpression(expr: cs.IsExpression) {
        // `<T>x` is a type assertion the shared transformer leaves as an `is`; Kotlin prints it wrong too
        if (expr.tsNode && ts.isTypeAssertionExpression(expr.tsNode)) {
            const inner = this._unwrapParens(expr.expression);
            if (this._isThrowingAssertion(expr)) {
                this._writeJsCast(cs.isCastExpression(inner) ? inner.expression : expr.expression, expr.type);
                return;
            }
            this.write('(');
            this.writeExpression(cs.isCastExpression(inner) ? inner.expression : expr.expression);
            this.write(' as! ');
            this._writeType(expr.type, { nullable: false });
            this.write(')');
            return;
        }
        // `x instanceof Map` / `Set`: Swift cannot test a generic class without its arguments
        // (`is Map<Any, Any?>` misses a `Map<String, Any?>`), so the runtime marks every Map and Set
        const tsNode = expr.tsNode;
        if (
            tsNode &&
            ts.isBinaryExpression(tsNode) &&
            tsNode.operatorToken.kind === ts.SyntaxKind.InstanceOfKeyword &&
            ts.isIdentifier(tsNode.right) &&
            (tsNode.right.text === 'Map' || tsNode.right.text === 'Set') &&
            !this._isDeclaredInSource(this._context.typeChecker.getSymbolAtLocation(tsNode.right))
        ) {
            this.writeExpression(expr.expression);
            this.write(` is any _Any${tsNode.right.text}`);
            return;
        }
        super.writeIsExpression(expr);
    }

    protected override writeParenthesizedExpression(expr: cs.ParenthesizedExpression) {
        if (
            cs.isCastExpression(expr.expression) &&
            (this._isNonNullCast(expr.expression) || this._isNoOpNullableCast(expr.expression))
        ) {
            this.writeExpression(expr.expression);
            return;
        }
        super.writeParenthesizedExpression(expr);
    }

    protected override writeSpreadExpression(expr: cs.SpreadExpression) {
        // Swift cannot splat an array into a variadic (see writeInvocationExpression for the `contentsOf:` of push and splice)
        this.writeExpression(expr.expression);
    }

    // ── statements ────────────────────────────────────────────────────────

    protected override writeSemicolon() {
        this.writeLine();
    }

    protected writeBlock(b: cs.Block) {
        this.write('do');
        this._openBrace();
        for (const s of b.statements) {
            this.writeStatement(s);
        }
        this._closeBrace();
    }

    /** Writes ` {`, the statement(s), and `}` without ending the line. */
    private _writeEmbeddedStatement(s: cs.Statement) {
        this._openBrace();
        if (cs.isBlock(s)) {
            for (const st of s.statements) {
                this.writeStatement(st);
            }
        } else {
            this.writeStatement(s);
        }
        this._closeBrace(false);
    }

    protected override writeIfStatement(s: cs.IfStatement) {
        this.write('if ');
        this.writeExpression(s.expression);
        this._writeEmbeddedStatement(s.thenStatement);
        if (s.elseStatement) {
            this.write(' else');
            if (cs.isIfStatement(s.elseStatement)) {
                this.write(' ');
                this.writeIfStatement(s.elseStatement);
                return;
            }
            this._writeEmbeddedStatement(s.elseStatement);
        }
        this.writeLine();
    }

    protected override writeWhileStatement(s: cs.WhileStatement) {
        this._forLoopIncrementors.push(undefined);
        try {
            this.write('while ');
            this.writeExpression(s.expression);
            this._writeEmbeddedStatement(s.statement);
            this.writeLine();
        } finally {
            this._forLoopIncrementors.pop();
        }
    }

    protected override writeDoStatement(s: cs.DoStatement) {
        this._forLoopIncrementors.push(undefined);
        try {
            this.write('repeat');
            this._writeEmbeddedStatement(s.statement);
            this.write(' while ');
            this.writeExpression(s.expression);
            this.writeLine();
        } finally {
            this._forLoopIncrementors.pop();
        }
    }

    protected writeForEachStatement(s: cs.ForEachStatement) {
        this.write('for ');
        if (cs.isVariableDeclarationList(s.initializer)) {
            const d = s.initializer.declarations[0];
            if (d.deconstructNames) {
                this.write(`(${d.deconstructNames.map(n => this.escapeIdentifier(n)).join(', ')})`);
            } else {
                this.writeIdentifier(d.name);
            }
        } else {
            this.writeExpression(s.initializer as cs.Expression);
        }
        this.write(' in ');
        // a Generator/Iterator is `any IteratorProtocol<T>`, which Swift's for-in rejects: erase it to a Sequence
        const iterated = this._tsTypeOf(this._unwrapParens(s.expression));
        const isIterator = !!iterated && /^(Generator|Iterator|IterableIterator|IteratorObject)$/.test(iterated.getSymbol()?.name ?? '');
        if (isIterator) {
            this.write('jsSequence(');
        }
        this.writeExpression(s.expression);
        if (isIterator) {
            this.write(')');
        }
        this._forLoopIncrementors.push(undefined);
        try {
            this._writeEmbeddedStatement(s.statement);
            this.writeLine();
        } finally {
            this._forLoopIncrementors.pop();
        }
    }

    protected writeForStatement(s: cs.ForStatement) {
        this.write('do');
        this._openBrace();
        if (s.initializer) {
            if (cs.isVariableDeclarationList(s.initializer)) {
                this.writeVariableDeclarationList(s.initializer);
            } else {
                this.writeExpression(s.initializer as cs.Expression);
                this.writeLine();
            }
        }
        this.write('while ');
        if (s.condition) {
            this.writeExpression(s.condition);
        } else {
            this.write('true');
        }
        this._openBrace();
        this._forLoopIncrementors.push(s.incrementor);
        try {
            if (cs.isBlock(s.statement)) {
                for (const stmt of s.statement.statements) {
                    this.writeStatement(stmt);
                }
            } else {
                this.writeStatement(s.statement);
            }
        } finally {
            this._forLoopIncrementors.pop();
        }
        this._writeForIncrementors(s.incrementor);
        this._closeBrace();
        this._closeBrace();
    }

    private _writeForIncrementors(i: cs.Expression | undefined) {
        if (!i) {
            return;
        }
        if (cs.isBinaryExpression(i) && i.operator === ',') {
            this._writeForIncrementors(i.left);
            this._writeForIncrementors(i.right);
            return;
        }
        this.writeExpression(i);
        this.writeLine();
    }

    protected override writeContinueStatement(c: cs.ContinueStatement): void {
        this._writeForIncrementors(this._forLoopIncrementors[this._forLoopIncrementors.length - 1]);
        super.writeContinueStatement(c);
    }

    protected writeSwitchStatement(s: cs.SwitchStatement) {
        this.write('switch ');
        this.writeExpression(s.expression);
        if (this._isImplicitlyUnwrappedField(s.expression)) {
            // a `T!` field is an optional to a pattern: `case E.A` cannot match `E?`
            this.write('!');
        }
        this.writeLine(' {');
        // an optional subject (`E | undefined`): the case patterns match through the optional, `case E.A?:`
        const optionalSubject = !this._isImplicitlyUnwrappedField(s.expression) && this._isOptionalValue(s.expression);

        let hasDefault = false;
        let pending: cs.Expression[] = [];
        for (const c of s.caseClauses) {
            if (cs.isDefaultClause(c)) {
                hasDefault = true;
                pending = [];
                this.writeLine('default:');
                this._writeCaseBody(c.statements);
                continue;
            }
            const caseClause = c as cs.CaseClause;
            pending.push(caseClause.expression);
            if (caseClause.statements.length === 0) {
                continue;
            }
            this.write('case ');
            this.writeCommaSeparated(
                pending,
                e => {
                    this.writeExpression(e);
                    if (optionalSubject) {
                        this.write('?');
                    }
                },
                false
            );
            this.writeLine(':');
            pending = [];
            this._writeCaseBody(caseClause.statements);
        }

        if (!hasDefault) {
            this.writeLine('default:');
            this._indent++;
            this.writeLine('break');
            this._indent--;
        }
        this.writeLine('}');
    }

    private _writeCaseBody(statements: cs.Statement[]) {
        let stmts = statements.slice();
        if (stmts.length > 0 && cs.isBreakStatement(stmts[stmts.length - 1])) {
            stmts.pop();
        }
        if (stmts.length === 1 && cs.isBlock(stmts[0])) {
            stmts = (stmts[0] as cs.Block).statements.slice();
            if (stmts.length > 0 && cs.isBreakStatement(stmts[stmts.length - 1])) {
                stmts.pop();
            }
        }
        this._indent++;
        if (stmts.length === 0) {
            this.writeLine('break');
        }
        for (const st of stmts) {
            this.writeStatement(st);
        }
        this._indent--;
    }

    protected override writeTryStatement(s: cs.TryStatement) {
        if (s.finallyBlock) {
            this.write('do');
            this._openBrace();
            this.write('defer');
            // a `defer` cannot throw: a throwing call in `finally` traps (see _inAccessor)
            this._deferDepth++;
            try {
                this._writeEmbeddedStatement(s.finallyBlock);
            } finally {
                this._deferDepth--;
            }
            this.writeLine();
            if (s.catchClauses && s.catchClauses.length > 0) {
                this._writeDoCatch(s);
            } else {
                for (const st of s.tryBlock.statements) {
                    this.writeStatement(st);
                }
            }
            this._closeBrace();
            return;
        }
        this._writeDoCatch(s);
    }

    private _writeDoCatch(s: cs.TryStatement) {
        this.write('do');
        this._writeEmbeddedStatement(s.tryBlock);
        for (const c of s.catchClauses ?? []) {
            this.write(' ');
            this.writeCatchClause(c);
        }
        this.writeLine();
    }

    protected writeCatchClause(c: cs.CatchClause): void {
        this.write('catch');
        this._openBrace();
        if (c.variableDeclaration) {
            this.write('let ');
            this.writeIdentifier(c.variableDeclaration.name);
            this.writeLine(' = error');
        }
        for (const st of c.block.statements) {
            this.writeStatement(st);
        }
        this._closeBrace(false);
    }

    protected override writeThrowStatement(s: cs.ThrowStatement) {
        this.write('throw');
        if (s.expression) {
            this.write(' ');
            this.writeExpression(s.expression);
        }
        this.writeLine();
    }

    private _usingCounter = 0;
    private _deferDepth = 0;
    private readonly _upcastNodes = new Set<ts.Node>();

    protected writeVariableStatement(s: cs.VariableStatement) {
        const isUsing = s.variableStatementKind === cs.VariableStatementKind.Using;
        if (isUsing) {
            // `using _ = x` binds nothing in TS but must stay alive until the scope ends; Swift's `let _` would
            // release it at once and leaves nothing to dispose
            for (const d of s.declarationList.declarations) {
                if (d.name === '_') {
                    d.name = `_using${this._usingCounter++}`;
                }
            }
        }
        this.writeVariableDeclarationList(s.declarationList, s.variableStatementKind);
        if (isUsing) {
            for (const d of s.declarationList.declarations) {
                this.write('defer');
                this._openBrace();
                this.writeIdentifier(d.name);
                this.writeLine(d.type.isNullable ? '?.dispose()' : '.dispose()');
                this._closeBrace();
            }
        }
    }

    protected writeVariableDeclarationList(
        declarationList: cs.VariableDeclarationList,
        kind: cs.VariableStatementKind = cs.VariableStatementKind.Normal
    ) {
        const isLet = declarationList.isConst || kind !== cs.VariableStatementKind.Normal;
        for (const d of declarationList.declarations) {
            // a `const` tuple is a value in Swift: writing one of its elements needs `var`
            this.write(isLet && !this._tupleElementIsWritten(d) ? 'let ' : 'var ');
            let initializer = d.initializer;
            if (d.deconstructNames) {
                const names = d.deconstructNames.map(n => this.escapeIdentifier(n));
                // Kotlin's cast to its tuple interface: a TS tuple is already a Swift tuple
                if (initializer && cs.isCastExpression(this._unwrapParens(initializer))) {
                    const inner = (this._unwrapParens(initializer) as cs.CastExpression).expression;
                    const tupleType = this._tsTypeOf(inner);
                    if (tupleType && this._context.typeChecker.isTupleType(tupleType)) {
                        initializer = inner;
                        const arity = this._context.typeChecker.getTypeArguments(tupleType as ts.TypeReference).length;
                        while (names.length < arity) {
                            names.push('_');
                        }
                    }
                }
                this.write(`(${names.join(', ')})`);
            } else {
                this.writeIdentifier(d.name);
            }
            if (!(cs.isPrimitiveTypeNode(d.type) && d.type.type === cs.PrimitiveType.Var)) {
                this.write(': ');
                this._writeType(d.type, { owner: d });
            }
            if (initializer) {
                this.write(' = ');
                this.writeExpression(initializer);
            }
            this.writeLine();
        }
    }

    /** `const t = [a, b]; t[0] = x`: TS tuples are mutable arrays, Swift tuples are values. */
    private _tupleElementIsWritten(d: cs.VariableDeclaration): boolean {
        return this._firstTupleWrite(d) !== undefined;
    }

    /** The position of the first element write to the tuple a declaration holds, if any. */
    private _firstTupleWrite(d: cs.VariableDeclaration): number | undefined {
        const tsNode = d.tsNode;
        if (!tsNode || !ts.isVariableDeclaration(tsNode) || !ts.isIdentifier(tsNode.name)) {
            return undefined;
        }
        const checker = this._context.typeChecker;
        if (!checker.isTupleType(checker.getTypeAtLocation(tsNode.name))) {
            return undefined;
        }
        const symbol = checker.getSymbolAtLocation(tsNode.name);
        let scope: ts.Node = tsNode;
        while (scope.parent && !ts.isFunctionLike(scope) && !ts.isSourceFile(scope)) {
            scope = scope.parent;
        }
        const isTarget = (n: ts.Node) => {
            while (ts.isParenthesizedExpression(n)) {
                n = n.expression;
            }
            return (
                ts.isElementAccessExpression(n) &&
                ts.isIdentifier(n.expression) &&
                checker.getSymbolAtLocation(n.expression) === symbol
            );
        };
        let first: number | undefined;
        const visit = (n: ts.Node) => {
            if (first !== undefined) {
                return;
            }
            if (
                (ts.isBinaryExpression(n) &&
                    n.operatorToken.kind >= ts.SyntaxKind.FirstAssignment &&
                    n.operatorToken.kind <= ts.SyntaxKind.LastAssignment &&
                    isTarget(n.left)) ||
                ((ts.isPrefixUnaryExpression(n) || ts.isPostfixUnaryExpression(n)) &&
                    (n.operator === ts.SyntaxKind.PlusPlusToken || n.operator === ts.SyntaxKind.MinusMinusToken) &&
                    isTarget(n.operand))
            ) {
                first = n.getStart();
                return;
            }
            ts.forEachChild(n, visit);
        };
        visit(scope);
        return first;
    }

    /**
     * `setShared(key, info); ... info[0] = x`: the call hands `info` to a store while TS goes on mutating the same
     * array. A Swift tuple is copied into the store, so the call moves to the end of the scope (`defer`), where
     * it publishes the final value; nothing between reads the store (TabWhammyEffectInfo.onAlignGlyphs).
     */
    private _isTuplePublish(s: cs.ExpressionStatement): boolean {
        const call = s.expression.tsNode;
        if (!call || !ts.isCallExpression(call) || !ts.isExpressionStatement(call.parent)) {
            return false;
        }
        const checker = this._context.typeChecker;
        return call.arguments.some(a => {
            if (!ts.isIdentifier(a)) {
                return false;
            }
            const declaration = checker.getSymbolAtLocation(a)?.valueDeclaration;
            if (!declaration || !ts.isVariableDeclaration(declaration) || declaration.getSourceFile() !== a.getSourceFile()) {
                return false;
            }
            // the declaration's cs node is not at hand: rebuild the position test from the TS side
            const write = this._firstTupleWriteOf(declaration);
            return write !== undefined && write > a.getStart();
        });
    }

    private _firstTupleWriteOf(declaration: ts.VariableDeclaration): number | undefined {
        return this._firstTupleWrite({ tsNode: declaration } as unknown as cs.VariableDeclaration);
    }

    protected override writeExpressionStatement(s: cs.ExpressionStatement) {
        if (this._isTuplePublish(s)) {
            this.write('defer');
            this._openBrace();
            this._deferDepth++;
            try {
                super.writeExpressionStatement(s);
            } finally {
                this._deferDepth--;
            }
            this._closeBrace();
            return;
        }
        super.writeExpressionStatement(s);
    }

    protected writeLocalFunction(expr: cs.LocalFunctionDeclaration) {
        this.write('func ');
        this.writeIdentifier(expr.name);
        this.writeParameters(expr.parameters);
        if (!this._isVoid(expr.returnType)) {
            this.write(' -> ');
            this._writeReturnType(expr.returnType);
        }
        this._writeBody(expr.body);
    }
}
