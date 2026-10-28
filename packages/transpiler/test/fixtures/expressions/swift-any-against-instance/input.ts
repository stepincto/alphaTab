/**
 * @public
 */
export class Entry {
    public id: number = 0;

    public equals(obj: unknown): boolean {
        if (obj === this) {
            return true;
        }
        return obj instanceof Entry && obj.id === this.id;
    }
}
