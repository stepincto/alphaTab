/**
 * @public
 */
export class Messages {
    // a closure inside an interpolation spans lines, so the string is a multi-line literal
    public describe(items: number[]): string {
        return `Expected one of: ${items.map(v => v.toString()).join(',')}.`;
    }

    public inner(items: number[]): string {
        if (items.length > 0) {
            return `"${items.map(v => v * 2).join(',')}"\n`;
        }
        return '';
    }
}
