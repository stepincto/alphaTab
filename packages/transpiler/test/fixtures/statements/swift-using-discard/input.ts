/**
 * @public
 */
export class Resource implements Disposable {
    public [Symbol.dispose](): void {}
}

/**
 * @public
 */
export class UsingDiscard {
    private _make(open: boolean): Disposable | undefined {
        return open ? new Resource() : undefined;
    }

    public doStuff(): void {
        using _ = this._make(true);
        using named = this._make(false);
    }

    public doMore(): void {
        using _ = new Resource();
    }
}
