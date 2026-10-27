/**
 * A class that implements Iterable<T> conforms to Sequence; its iterator is type-erased
 * because `any IteratorProtocol<T>` does not conform to IteratorProtocol.
 * @public
 */
export class Bag implements Iterable<number> {
    public readonly items: number[] = [];

    [Symbol.iterator](): Iterator<number> {
        return this.items[Symbol.iterator]();
    }
}
