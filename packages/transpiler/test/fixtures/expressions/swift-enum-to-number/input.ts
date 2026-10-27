/**
 * @public
 */
export enum Key {
    C = -1,
    G = 1
}

/**
 * @public
 */
export class Table {
    public key: Key | undefined = undefined;
    private static _table: number[] = [1, 2, 3];

    // an optional enum to an optional number
    public keyValue(): number | undefined {
        return this.key as number | undefined;
    }

    // an enum in arithmetic: converted to a number once
    public lookup(key: Key): number {
        return Table._table[key + 1];
    }
}
