// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Stands in for test/visualTests/VisualTestHelper.ts when the visual tests run under vitest.svg-goldens.config.ts:
// instead of drawing with alphaSkia and comparing PNGs, it renders with the SVG engine and writes the SVG
// as a golden file for the Swift port to match. Run by `npm run svg-goldens`; never run against Swift output.
import fs from 'node:fs';
import path from 'node:path';
import { AlphaTabApiBase } from '@coderline/alphatab/AlphaTabApiBase';
import { AlphaTabError, AlphaTabErrorType } from '@coderline/alphatab/AlphaTabError';
import { Environment } from '@coderline/alphatab/Environment';
import { AlphaTexImporter } from '@coderline/alphatab/importer/AlphaTexImporter';
import { ScoreLoader } from '@coderline/alphatab/importer/ScoreLoader';
import { ByteBuffer } from '@coderline/alphatab/io/ByteBuffer';
import { JsonConverter } from '@coderline/alphatab/model/JsonConverter';
import { Score } from '@coderline/alphatab/model/Score';
import type { RenderFinishedEventArgs } from '@coderline/alphatab/rendering/RenderFinishedEventArgs';
import { Settings } from '@coderline/alphatab/Settings';
import { TestPlatform } from 'test/TestPlatform';
import { TestUiFacade } from 'test/visualTests/TestUiFacade';

/** Where the goldens go: the Swift test target reads them from here. */
const goldenRoot = process.env.SVG_GOLDEN_ROOT ?? path.resolve(process.cwd(), '../swift/Tests/AlphaTabTests/SvgGoldens');

/** Between the renderings in one golden file; the Swift side splits on the same text. */
const variantSeparator = '\n--- another test renders the same reference image ---\n';

export class VisualTestRun {
    public width: number;
    public referenceFileName: string;
    public constructor(width: number, referenceFileName: string) {
        this.width = width === -1 ? 1300 : width;
        this.referenceFileName = referenceFileName;
    }
}

export class VisualTestOptions {
    public score: Score;
    public runs: VisualTestRun[];
    public settings: Settings;
    public tracks?: number[];
    public tolerancePercent?: number;
    public prepareFullImage?: (run: VisualTestRun, api: AlphaTabApiBase<unknown>, fullImage: unknown) => void;

    public constructor(score: Score, runs: VisualTestRun[], settings: Settings | undefined) {
        this.score = score;
        this.runs = runs;
        this.settings = settings ?? new Settings();
    }

    public static async file(inputFile: string, runs: VisualTestRun[], settings?: Settings) {
        const inputFileData = await TestPlatform.loadFile(`test-data/visual-tests/${inputFile}`);
        const score: Score = ScoreLoader.loadScoreFromBytes(inputFileData, settings);
        return new VisualTestOptions(score, runs, settings);
    }

    public static tex(tex: string, referenceFileName: string, settings?: Settings) {
        if (!settings) {
            settings = new Settings();
        }
        const importer = new AlphaTexImporter();
        importer.init(ByteBuffer.fromString(tex), settings);
        const score: Score = importer.readScore();
        return new VisualTestOptions(score, [new VisualTestRun(1300, referenceFileName)], settings);
    }
}

export class VisualTestHelper {
    public static async runVisualTest(
        inputFile: string,
        settings?: Settings,
        configure?: (o: VisualTestOptions) => void
    ): Promise<void> {
        inputFile = `test-data/visual-tests/${inputFile}`;
        const inputFileData = await TestPlatform.loadFile(inputFile);
        const referenceFileName = TestPlatform.changeExtension(inputFile, '.png');
        const score: Score = ScoreLoader.loadScoreFromBytes(inputFileData, settings);

        const o = new VisualTestOptions(score, [new VisualTestRun(-1, referenceFileName)], settings);
        if (configure) {
            configure(o);
        }
        await VisualTestHelper.runVisualTestFull(o);
    }

    public static runVisualTestTex(
        tex: string,
        referenceFileName: string,
        settings?: Settings,
        configure?: (o: VisualTestOptions) => void
    ): Promise<void> {
        const o = VisualTestOptions.tex(tex, referenceFileName, settings);
        if (configure) {
            configure(o);
        }
        return VisualTestHelper.runVisualTestFull(o);
    }

    public static async prepareAlphaSkia() {}

    /** The settings the Swift VisualTestHelper applies too: same fonts, scale 1, SVG engine. */
    public static prepareSettingsForTest(settings: Settings) {
        settings.core.engine = 'svg';
        Environment.highDpiFactor = 1;
        settings.core.enableLazyLoading = false;

        const noto = ['Noto Sans', 'Noto Music', 'Noto Color Emoji'];
        settings.display.resources.tablatureFont.families = noto.slice();
        settings.display.resources.graceFont.families = noto.slice();
        settings.display.resources.numberedNotationFont.families = noto.slice();
        settings.display.resources.numberedNotationGraceFont.families = noto.slice();

        for (const f of settings.display.resources.elementFonts.values()) {
            if (f.families.includes('sans-serif')) {
                f.families = noto.slice();
            } else {
                f.families = ['Noto Serif', 'Noto Music', 'Noto Color Emoji'];
            }
        }
    }

    public static async runVisualTestFull(options: VisualTestOptions): Promise<void> {
        const settings = options.settings ?? new Settings();
        const tracks = options.tracks ?? [0];
        const runs = options.runs;
        let runIndex = 0;

        VisualTestHelper.prepareSettingsForTest(settings);

        const results: RenderFinishedEventArgs[][] = [];
        const totalWidths: number[] = [];
        const totalHeights: number[] = [];
        const uiFacade = new TestUiFacade();
        uiFacade.rootContainer.width = runs[runIndex++].width;

        const api = new AlphaTabApiBase<unknown>(uiFacade, settings);

        const render = new Promise<void>((resolve, reject) => {
            api.renderStarted.on(_ => {
                results.push([]);
                totalWidths.push(0);
                totalHeights.push(0);
            });
            api.renderer.partialRenderFinished.on(e => {
                if (e) {
                    results[results.length - 1].push(e);
                }
            });
            api.renderer.renderFinished.on(e => {
                totalWidths[totalWidths.length - 1] = e.totalWidth;
                totalHeights[totalHeights.length - 1] = e.totalHeight;
                results[results.length - 1].push(e);
            });
            api.renderer.postRenderFinished.on(() => {
                if (runIndex < runs.length) {
                    uiFacade.rootContainer.width = runs[runIndex++].width;
                    api.triggerResize();
                } else {
                    resolve();
                }
            });
            api.error.on(e => {
                reject(
                    new AlphaTabError(AlphaTabErrorType.General, `Failed to render image (${e.message} ${e.stack})`, e)
                );
            });

            // the render ids (`class="b12"`) count up from the last import: start from zero, as the Swift helper does
            Score.resetIds();
            const renderScore = JsonConverter.jsObjectToScore(JsonConverter.scoreToJsObject(options.score), settings);
            api.renderScore(renderScore, tracks);
        });

        const timeout = 2000 * runs.length;
        await Promise.race([
            render,
            new Promise<void>((_, reject) => {
                setTimeout(() => {
                    reject(new Error(`Rendering did not complete after ${timeout}ms`));
                }, timeout);
            })
        ] as Promise<void>[]);

        try {
            for (let i = 0; i < results.length; i++) {
                VisualTestHelper.writeGolden(runs[i], totalWidths[i], totalHeights[i], results[i]);
            }
        } finally {
            api.destroy();
        }
    }

    /**
     * The golden text (also produced by the Swift VisualTestHelper, see Tests/AlphaTabTests/Runtime/VisualTestHelper.swift):
     * the size line, then one header line and the SVG per partial result.
     */
    public static goldenText(totalWidth: number, totalHeight: number, result: RenderFinishedEventArgs[]): string {
        let text = `total ${totalWidth} ${totalHeight}\n`;
        for (const partial of result) {
            text += `partial ${partial.x} ${partial.y} ${partial.width} ${partial.height}\n`;
            text += `${partial.renderResult}\n`;
        }
        return text;
    }

    private static writeGolden(
        run: VisualTestRun,
        totalWidth: number,
        totalHeight: number,
        result: RenderFinishedEventArgs[]
    ) {
        const file = path.join(goldenRoot, VisualTestHelper.goldenName(run.referenceFileName));
        fs.mkdirSync(path.dirname(file), { recursive: true });
        // several tests may name one reference image (they assert the same picture from different inputs, e.g. a
        // file and its alphaTex source) while their SVG differs in render ids: the golden then holds every distinct
        // rendering, and the Swift side accepts any of them. The run is serial and starts from an empty directory.
        const text = VisualTestHelper.goldenText(totalWidth, totalHeight, result);
        const variants = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').split(variantSeparator) : [];
        if (!variants.includes(text)) {
            variants.push(text);
        }
        fs.writeFileSync(file, variants.join(variantSeparator));
    }

    /** `test-data/visual-tests/layout/foo.png` -> `layout/foo.svg.txt` */
    public static goldenName(referenceFileName: string): string {
        return referenceFileName
            .split('\\')
            .join('/')
            .replace(/^test-data\/visual-tests\//, '')
            .replace(/\.png$/, '.svg.txt');
    }
}
