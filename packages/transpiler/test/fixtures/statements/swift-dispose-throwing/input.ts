/**
 * @public
 */
export class Scope implements Disposable {
    public parent: Scope | null = null;
    public closed: boolean = false;

    public [Symbol.dispose](): void {
        this.parent!.closed = true;
    }
}
