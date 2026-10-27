/**
 * @record
 * @public
 */
export interface SyncPoint {
    barIndex: number;
    barPosition: number;
    label?: string;
    barOccurence: number;
}

/**
 * @public
 */
export class Exporter {
    // labels follow the memberwise init (declaration order, optional last), not the literal's order
    public make(index: number): SyncPoint {
        return {
            label: 'x',
            barIndex: index,
            barOccurence: 0,
            barPosition: 0.5
        };
    }
}
