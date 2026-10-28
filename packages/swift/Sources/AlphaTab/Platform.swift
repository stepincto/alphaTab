// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime
#if canImport(Foundation)
import Foundation
#endif

// Hand-written partials: the members the TS marks `@partial` or `@target web`, and the stand-ins for the
// platform pieces the Swift target does not have.

/// The `@partial` members of `Environment` (src/Environment.ts).
internal final class EnvironmentPartials {
    internal static func _createPlatformSpecificRenderEngines(_ engines: Map<String, RenderEngineFactory>) {
        // the Swift target has no engine of its own: SVG is the default
    }

    internal static func _printPlatformInfo(_ print: (String) -> Void) {
        let info = ProcessInfo.processInfo
        print("OS Name: \(info.operatingSystemVersionString)")
        print("Processor Count: \(info.processorCount)")
    }

    internal static func quoteJsonString(_ text: String) -> String {
        // Json.quoteJsonString throws only for a missing escape table entry, which cannot happen
        return try! Json.quoteJsonString(text)
    }

    internal static func sortDescending(_ list: List<Double>) {
        _ = list.sort { (a: Double, b: Double) -> Double in b - a }
    }
}

/// The `@partial` of `FontSizes` (src/platform/svg/FontSizes.ts): measuring a font that has no table.
internal final class FontSizesPartials {
    internal static func generateFontLookup(_ family: String) {
        if FontSizes.fontSizeLookupTables.has(family) {
            return
        }
        // shortcut: the Kotlin target measures through alphaSkia, a browser through a canvas; the Swift target has
        // neither, so a font without a prebuilt table gets the same 8x10 box the Kotlin target uses before alphaSkia
        // is loaded. Rendering text in such a font gives wrong widths; the families alphaTab ships have tables.
        Logger.warning("Rendering", "Generating font lookup without a text measurer, SVG sizes will be wrong")
        FontSizes.fontSizeLookupTables.set(family, FontSizeDefinition(Uint8Array(List<Double>(8.0)), Uint8Array(List<Double>(10.0))))
    }
}

/// Stand-in for `SkiaCanvas` (src/platform/skia/SkiaCanvas.ts): alphaSkia is a native rasterizer the Swift
/// target does not have. Environment registers the "skia" engine by name, so the type must exist.
internal final class SkiaCanvas: SvgCanvas {
    internal override init() {
        fatalError("The 'skia' render engine (alphaSkia) is not available in Swift; use the 'svg' engine")
    }

    internal static func enable(_ musicFontData: ArrayBuffer, _ alphaSkia: Any?) throws {
        throw JsError("alphaSkia is not available in Swift")
    }

    internal static func registerFont(_ fontData: Uint8Array) throws -> Font {
        throw JsError("alphaSkia is not available in Swift")
    }
}

/// Stand-in for `VersionInfo` (src/generated/VersionInfo.ts): that file is written per build with the build
/// date and git commit, which would change the generated output on every clone.
internal final class VersionInfo {
    internal static let version: String = "1.9.0"
    internal static let date: String = "unknown"
    internal static let commit: String = "unknown"

    internal static func print(_ print: (String) -> Void) {
        print("alphaTab \(VersionInfo.version)")
        print("commit: \(VersionInfo.commit)")
        print("build date: \(VersionInfo.date)")
    }
}

// Element types generated code sizes with `new Array<T>(n)` (see `JsArrayHole`).
extension TabBeatContainerGlyph: JsArrayHole {}
extension Int32Array: JsArrayHole {
    public static var hole: Int32Array { Int32Array(0.0) }
}
extension Spring: JsArrayHole {
    // BarLayoutingInfo.addBeatSpring reads a slot before it writes it and tests it for truthiness
    nonisolated(unsafe) internal static let holeSpring = Spring()
    public static var hole: Spring { holeSpring }
    public var isJsHole: Bool { self === Spring.holeSpring }
}

/// Stand-in for `ExternalMediaPlayer` (src/synth/ExternalMediaPlayer.ts): it extends the backing track player,
/// which extends the audio synth, and the Swift target has no audio synth. AlphaTabApiBase creates it for
/// `player.playerMode = EnabledExternalMedia`; that mode is not available here, so creating it traps and no
/// member below is ever reached.
internal final class ExternalMediaPlayer: IAlphaSynth {
    internal init(_ bufferTimeInMilliseconds: Double) {
        fatalError("The external media player needs the audio synth, which the Swift target does not have")
    }

    private func unavailable() -> Never {
        fatalError("The audio synth is not part of the Swift target")
    }

    var isReady: Bool { unavailable() }
    var isReadyForPlayback: Bool { unavailable() }
    var state: PlayerState { unavailable() }
    var logLevel: LogLevel { get { unavailable() } set { unavailable() } }
    var masterVolume: Double { get { unavailable() } set { unavailable() } }
    var metronomeVolume: Double { get { unavailable() } set { unavailable() } }
    var playbackSpeed: Double { get { unavailable() } set { unavailable() } }
    var tickPosition: Double { get { unavailable() } set { unavailable() } }
    var timePosition: Double { get { unavailable() } set { unavailable() } }
    var loadedMidiInfo: PositionChangedEventArgs? { unavailable() }
    var currentPosition: PositionChangedEventArgs { unavailable() }
    var playbackRange: PlaybackRange? { get { unavailable() } set { unavailable() } }
    var isLooping: Bool { get { unavailable() } set { unavailable() } }
    var countInVolume: Double { get { unavailable() } set { unavailable() } }
    var midiEventsPlayedFilter: List<MidiEventType> { get { unavailable() } set { unavailable() } }
    var output: any ISynthOutput { unavailable() }
    func destroy() throws { unavailable() }
    func play() throws -> Bool { unavailable() }
    func pause() throws { unavailable() }
    func playPause() throws { unavailable() }
    func stop() throws { unavailable() }
    func playOneTimeMidiFile(_ midi: MidiFile) throws { unavailable() }
    func loadSoundFont(_ data: Uint8Array, _ append: Bool) throws { unavailable() }
    func resetSoundFonts() throws { unavailable() }
    func loadMidiFile(_ midi: MidiFile) throws { unavailable() }
    func loadBackingTrack(_ score: Score) throws { unavailable() }
    func updateSyncPoints(_ syncPoints: List<BackingTrackSyncPoint>) { unavailable() }
    func applyTranspositionPitches(_ transpositionPitches: Map<Double, Double>) throws { unavailable() }
    func setChannelTranspositionPitch(_ channel: Double, _ semitones: Double) throws { unavailable() }
    func setChannelMute(_ channel: Double, _ mute: Bool) { unavailable() }
    func resetChannelStates() throws { unavailable() }
    func setChannelSolo(_ channel: Double, _ solo: Bool) { unavailable() }
    func setChannelVolume(_ channel: Double, _ volume: Double) { unavailable() }
    var ready: IEventEmitter { unavailable() }
    var readyForPlayback: IEventEmitter { unavailable() }
    var finished: IEventEmitter { unavailable() }
    var soundFontLoaded: IEventEmitter { unavailable() }
    var soundFontLoadFailed: IEventEmitterOfT<JsError> { unavailable() }
    var midiLoaded: IEventEmitterOfT<PositionChangedEventArgs> { unavailable() }
    var midiLoadFailed: IEventEmitterOfT<JsError> { unavailable() }
    var stateChanged: IEventEmitterOfT<PlayerStateChangedEventArgs> { unavailable() }
    var positionChanged: IEventEmitterOfT<PositionChangedEventArgs> { unavailable() }
    var midiEventsPlayed: IEventEmitterOfT<MidiEventsPlayedEventArgs> { unavailable() }
    var playbackRangeChanged: IEventEmitterOfT<PlaybackRangeChangedEventArgs> { unavailable() }
}
