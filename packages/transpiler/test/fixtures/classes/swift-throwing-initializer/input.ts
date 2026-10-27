/**
 * @public
 */
export class Family {
    public name: string;

    public constructor(name: string) {
        if (name.length === 0) {
            throw new Error('empty family');
        }
        this.name = name;
    }
}

/**
 * @public
 */
export class Fonts {
    // an initializer cannot throw in Swift: `try!` traps where JS would throw
    public static readonly defaultFamily: Family = new Family('serif');
    public title: Family = new Family('sans');
}
