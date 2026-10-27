/**
 * @public
 */
export enum Element {
    A,
    B
}

/**
 * @public
 */
export class Style {
    public constructor(
        public text: string,
        public size?: number
    ) {}
}

/**
 * @public
 */
export class Defaults {
    // a Set or Map built from an array literal: the literal is a Swift array literal
    private _filled: Set<number> = new Set<number>([0]);
    public static flags: Map<Element, boolean> = new Map([[Element.A, false]]);
    public static readonly styles: Map<Element, Style> = new Map<Element, Style>([
        [Element.A, new Style('a', undefined)],
        [Element.B, new Style('b', 2)]
    ]);

    public count(): number {
        return this._filled.size + Defaults.flags.size + Defaults.styles.size;
    }
}
