/**
 * @public
 */
export interface IRunner {
    run(action: () => void): void;
}

/**
 * @public
 */
export class Runner implements IRunner {
    public run(action: () => void): void {
        action();
    }
}

/**
 * @public
 */
export class Caller {
    public go(runner: IRunner, value: string | null): void {
        runner.run(() => {
            value!.toString();
        });
    }
}
