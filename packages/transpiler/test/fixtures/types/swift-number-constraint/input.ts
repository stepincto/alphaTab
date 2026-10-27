/**
 * @public
 */
export enum Part {
    Head,
    Stem
}

/**
 * @public
 */
export class Style<TPart extends number> {
    // `T extends number` holds enums in alphaTab: Swift bounds it by the runtime enum protocol
    public colors: Map<TPart, string | null> = new Map<TPart, string | null>();
}

/**
 * @public
 */
export class NoteStyle extends Style<Part> {}
