/**
 * @public
 */
export class AssetLoader {
    // an optional function whose return type is itself optional keeps both `?`
    public loadAsset?: (fileName: string) => Uint8Array | undefined;

    public load(name: string): Uint8Array | undefined {
        const loadAsset = this.loadAsset;
        if (loadAsset) {
            return loadAsset(name);
        }
        return undefined;
    }
}
