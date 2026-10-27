/**
 * @public
 */
export class Parser {
    public static parse(value: string): string[] {
        if (value.length === 0) {
            throw new Error('empty');
        }
        return [value];
    }
}

/**
 * @public
 */
export class Font {
    public families: string[] = [];

    // Swift accessors cannot throw: a throwing call traps there (`try!`) where JS throws
    public set family(value: string) {
        this.families = Parser.parse(value);
    }

    public get family(): string {
        return Parser.parse(this.families[0])[0];
    }
}
