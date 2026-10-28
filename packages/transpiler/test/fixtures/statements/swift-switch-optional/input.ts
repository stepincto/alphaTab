/**
 * @public
 */
export enum Placement {
    All = 0,
    Primary = 1
}

/**
 * @public
 */
export class Display {
    public placement: Placement | undefined;
    public shows(): boolean {
        switch (this.placement) {
            case Placement.All:
                return true;
            case Placement.Primary:
                return false;
            default:
                return false;
        }
    }
}
