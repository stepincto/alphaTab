/**
 * @public
 */
export class Base {
    public constructor(public value: number) {}
}

/**
 * @public
 */
export class Derived extends Base {
    public constructor(source: number | null) {
        super(source!);
    }
}
