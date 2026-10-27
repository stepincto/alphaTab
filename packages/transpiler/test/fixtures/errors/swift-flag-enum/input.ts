/**
 * @public
 */
export enum Access {
    None = 0,
    Read = 1,
    Write = 2,
    All = Read | Write
}

/**
 * Swift enums hold only their declared cases, so an enum combined with a bit
 * operator cannot land in an enum-typed slot (Read ^ Write is no case here).
 *
 * @public
 */
export class AccessFlags {
    public toggle(a: Access): Access {
        return a ^ Access.Read;
    }

    public grant(a: Access): void {
        const b: Access = a | Access.Write;
        let c = b;
        c &= Access.Read;
        this.use(c);
    }

    public mask(a: Access): number {
        return a & Access.Read;
    }

    private use(_a: Access): void {}
}
