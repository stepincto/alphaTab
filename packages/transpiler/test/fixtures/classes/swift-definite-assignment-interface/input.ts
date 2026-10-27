/**
 * @public
 */
export class Score {
    public title: string = '';
}

/**
 * @public
 */
export interface IState {
    score: Score;
}

/**
 * `score!` implements a non-optional requirement: a `Score!` store behind a `Score` property.
 * `other!` is not a requirement and stays `Score!`.
 * @public
 */
export class State implements IState {
    public score!: Score;
    public other!: Score;
}
