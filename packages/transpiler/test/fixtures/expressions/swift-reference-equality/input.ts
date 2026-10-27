/**
 * @public
 */
export class Voice {
    public index: number = 0;
}

/**
 * @public
 */
export class Beat {
    public voice: Voice | null = null;
    public name: string = '';

    // class instances compare by reference; values and nil checks stay ==
    public sameVoice(other: Beat): boolean {
        return this.voice === other.voice && this !== other && this.name === other.name && this.voice != null;
    }
}
