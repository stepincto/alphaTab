/**
 * @public
 */
export enum Kind {
    A,
    B
}

/**
 * @public
 */
export class Event {
    // no initializer: Swift declares it `Kind!`, so a switch on it needs `!`
    public kind: Kind;
    public name: string;
    public count: number;

    public constructor(kind: Kind, name: string) {
        this.kind = kind;
        this.name = name;
        this.count = 0;
    }

    public describe(): number {
        switch (this.kind) {
            case Kind.A:
                return 1;
        }
        switch (this.name) {
            case 'x':
                return 2;
        }
        switch (this.count) {
            case 1:
                return 3;
        }
        return 0;
    }
}
