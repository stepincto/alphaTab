/**
 * @public
 */
export class Wrapper {
    private _position: number = 0;

    public get position(): number {
        return this._position;
    }

    // a setter parameter named `value` keeps its name (Swift's implicit one is `newValue`)
    public set position(value: number) {
        this._position = value;
    }
}
