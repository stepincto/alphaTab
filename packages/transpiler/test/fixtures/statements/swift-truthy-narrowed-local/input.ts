/**
 * @public
 */
export class Node {
    public next: Node | null = null;
}

/**
 * @public
 */
export class Truthy {
    public walk(start: Node | null): number {
        let cursor: Node | null = null;
        let count = 0;
        if (start) {
            cursor = start;
        }
        while (cursor) {
            if (!start || !cursor) {
                break;
            }
            count++;
            cursor = cursor.next;
        }
        return count;
    }
}
