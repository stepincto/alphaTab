/**
 * @public
 */
export enum Kind {
    Number,
    Text,
    Ident
}

/**
 * @public
 */
export class Node {
    public kind: Kind = Kind.Number;
}

/**
 * @public
 */
export class Names {
    // after `!== Kind.Number` TS narrows `n.kind` to a union of the other members; it is still an enum
    public describe(n: Node): string {
        if (n.kind !== Kind.Number) {
            return `got ${Kind[n.kind]}`;
        }
        return '';
    }
}
