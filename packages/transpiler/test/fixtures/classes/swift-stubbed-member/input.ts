/**
 * @public
 */
export interface IPlayer {
    start(): number;
}

/**
 * @public
 */
export class Facade {
    public createPlayer(): IPlayer | null {
        return { start: () => 1 };
    }

    public name(): string {
        return 'facade';
    }
}
