/**
 * @public
 */
export enum Symbol {
    None = 0,
    Brace = 57344
}

/**
 * @public
 */
export class Concat {
    public rect(x: number, y: number, w: number, h: number, fill: string): string {
        return '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" fill="' + fill + '" />';
    }

    public entity(symbol: Symbol): string {
        return '&#' + symbol;
    }
}
