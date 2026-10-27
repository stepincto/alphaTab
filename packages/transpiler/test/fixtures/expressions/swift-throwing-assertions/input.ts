/**
 * @public
 */
export interface Node {
    kind: number;
}

/**
 * @public
 */
export class TextNode implements Node {
    public kind: number = 0;
    public text: string = '';
}

/**
 * @public
 */
export class Args {
    public items: Node[] = [];
}

/**
 * @public
 */
export class Prop {
    public args: Args | null = null;
    public names: Map<string, number> = new Map<string, number>();

    // `!` on a nullable value and a downcast can fail: throwing helpers, and the method `throws`
    public firstText(): string {
        return (this.args!.items[0] as TextNode).text;
    }

    // a caller of a throwing method throws too
    public describe(): string {
        return 'text ' + this.firstText();
    }

    public lookup(key: string): number {
        return this.names.get(key)!;
    }

    // narrowed: TS knows these cannot fail, so they stay `!` / `as!`
    public narrowed(n: Node, a: Args | null): string {
        if (a !== null && n instanceof TextNode) {
            return (n as TextNode).text + a!.items.length;
        }
        return '';
    }

    // an upcast cannot fail
    public upcast(t: TextNode): Node {
        return t as Node;
    }

    // `?.` before `!`: unwraps only when set
    public chained(p: Prop | null): number {
        return p?.args!.items.length ?? 0;
    }

    // a closure passed as an argument throws, and so does the call
    public texts(): string[] {
        return this.args!.items.map(i => (i as TextNode).text);
    }

    // an accessor cannot throw: it keeps the trapping form
    public get first(): Node {
        return this.args!.items[0];
    }
}

/**
 * @public
 */
export class Callbacks {
    private _resolve: (n: Node) => string;

    // a function value stored in a declared function type makes that type throw
    public constructor(resolve: (n: Node) => string) {
        this._resolve = resolve;
    }

    public run(n: Node): string {
        // a local holding a throwing closure prints its type with `throws`
        const text = (x: Node) => (x as TextNode).text;
        return text(n) + this._resolve(n);
    }

    public static create(): Callbacks {
        return new Callbacks(n => (n as TextNode).text);
    }
}

/**
 * @public
 */
export class Reader {
    // inside a throwing function, `xs[i].m` reads through the throwing `jsElement`
    public kindAt(p: Prop, i: number): number {
        return p.args!.items[i].kind;
    }

    // a function that does not throw keeps the plain subscript
    public firstKind(a: Args): number {
        return a.items[0].kind;
    }
}
