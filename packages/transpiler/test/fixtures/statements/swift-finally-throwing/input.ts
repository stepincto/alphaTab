/**
 * @public
 */
export class Cleaner {
    public cleaned: boolean = false;
    private _value: string | null = null;

    private _clean(): void {
        this.cleaned = this._value!.length > 0;
    }

    public run(work: () => void): void {
        try {
            work();
        } finally {
            this._clean();
        }
    }
}
