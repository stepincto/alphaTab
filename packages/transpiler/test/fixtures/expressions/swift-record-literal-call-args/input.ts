/**
 * @public
 * @record
 */
export interface ChannelInfo {
    program: number;
    owner: Reader;
}

/**
 * @public
 */
export class Reader {
    private _pos: number = 0;

    public readByte(): number {
        if (this._pos > 10) {
            throw new Error('end of data');
        }
        return this._pos++;
    }

    // a throwing call inside a record literal needs the statement's `try`
    public readInfo(): ChannelInfo {
        const info: ChannelInfo = {
            program: this.readByte(),
            owner: this
        };
        return info;
    }

    // a shorthand property names a narrowed nullable local: Swift needs its `!`
    public wrap(other: Reader | null): ChannelInfo | null {
        const owner: Reader | null = other;
        if (owner !== null) {
            return { program: 1, owner };
        }
        return null;
    }
}
