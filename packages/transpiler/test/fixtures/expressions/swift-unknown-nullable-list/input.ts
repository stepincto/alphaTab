/**
 * @public
 */
export class ListReader {
    public lyrics: string[] | null = null;
    public names: string[] = [];

    // `v as T[] | null` keeps a null, `v as T[]` does not
    public apply(lyrics: unknown, names: unknown): void {
        this.lyrics = lyrics as string[] | null;
        this.names = names as string[];
    }
}
