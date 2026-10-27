/**
 * @public
 */
export class Lazy<T> {
    private _value: T | undefined = undefined;
    public get value(): T {
        return this._value!;
    }
}
/**
 * @public
 */
export class Note {
    public isLetRing: boolean = false;
    // TS narrows a getter result; the shared smart cast covers only fields, so Swift unwraps it here
    public check(next: Lazy<Note | null>): boolean {
        return !next.value || !next.value.isLetRing;
    }
}
