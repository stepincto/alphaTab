/**
 * @public
 */
export enum Mode {
    All,
    Hide
}

/**
 * @public
 */
export class Picker {
    // `!` on an element of an array of optionals unwraps it, even after a narrowing check
    public first(modes: (Mode | undefined)[]): string {
        if (modes[0] !== undefined) {
            return Mode[modes[0]!];
        }
        return '';
    }

    // an element of an array of non-optionals has nothing to unwrap
    public plain(modes: Mode[]): Mode {
        return modes[0]!;
    }
}
