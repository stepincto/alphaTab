/**
 * @record
 * @public
 */
export interface Pending {
    callback: (value: number) => void;
}

/**
 * @public
 */
export class Queue {
    private _pending: Pending[] = [];

    public add(callback: (value: number) => void): void {
        this._pending.push({ callback });
    }

    public run(): void {
        for (const p of this._pending) {
            p.callback(1);
        }
    }

    public go(): void {
        this.add(v => {
            if (v < 0) {
                throw new Error('negative');
            }
        });
    }
}
