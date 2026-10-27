/**
 * @public
 */
export class Reader {
    private _require(n: number): void {
        if (n < 0) {
            throw new Error('short');
        }
    }

    // throws through a call; the call is marked `try`
    public readByte(): number {
        this._require(1);
        return 1;
    }

    // caught: not `throws`, but the call still needs `try` inside `do`
    public safe(): number {
        try {
            return this.readByte();
        } catch (e) {
            return 0;
        }
    }

    // one `try` covers the whole expression
    public sum(): number {
        return this.readByte() + this.readByte();
    }

    // a closure: the enclosing function does not throw because of it
    public later(): () => number {
        return () => 1;
    }
}

/**
 * @public
 */
export class Assigner {
    public constructor(n: number) {
        if (n < 1) {
            throw new Error('n');
        }
    }
}

/**
 * @public
 */
export class Factory {
    public make(): Assigner {
        const a = new Assigner(2);
        return a;
    }
}

/**
 * @public
 */
export class Event {
    // not throwing itself, but an override is
    public writeTo(): void {}
}

/**
 * @public
 */
export class BendEvent extends Event {
    public override writeTo(): void {
        throw new Error('no');
    }
}

/**
 * @public
 */
export interface Sink {
    put(): void;
}

/**
 * @public
 */
export class BadSink implements Sink {
    public put(): void {
        throw new Error('x');
    }
}

/**
 * @public
 */
export class User {
    public use(e: Event, s: Sink): void {
        e.writeTo();
        s.put();
    }
}
