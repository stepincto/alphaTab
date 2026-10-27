// alphaTab
// Copyright (c) Daniel Kuschny and Contributors, All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import AlphaTabRuntime

// shortcut: until the filter drops. A hand-written stand-in for src/Settings.ts with only the members
// the tier-"model" code names (its import closure is the whole library, see scripts/transpile.ts).
// Delete this file, and SettingsSerializer.swift, when the filter takes in Settings.

/// Stand-in for `Settings` (src/Settings.ts).
public final class Settings {
    public var core: CoreSettings = CoreSettings()
    public var display: DisplaySettings = DisplaySettings()
    public var notation: NotationSettings = NotationSettings()

    public init() {}
}

/// Stand-in for `CoreSettings` (src/CoreSettings.ts).
public final class CoreSettings {
    public var enableLazyLoading: Bool = true
    public var logLevel: LogLevel = LogLevel.Info

    public init() {}
}

/// Stand-in for `DisplaySettings` (src/DisplaySettings.ts).
public final class DisplaySettings {
    public var scale: Double = 1.0
    public var layoutMode: LayoutMode = LayoutMode.Page
    public var startBar: Double = 1.0
    public var barCount: Double = -1.0
    public var resources: RenderingResources = RenderingResources()

    public init() {}
}

/// Stand-in for `RenderingResources` (src/RenderingResources.ts).
public final class RenderingResources {
    public var engravingSettings: EngravingSettings = EngravingSettings()
    public var mainGlyphColor: Color = Color(0.0, 0.0, 0.0, 255.0)

    public init() {}
}

/// Stand-in for `EngravingSettings` (src/EngravingSettings.ts).
public final class EngravingSettings {
    public init() {}

    // shortcut: no SMuFL metadata yet, so every symbol counts as present (JS: width and height > 0 in
    // the Bravura defaults); upgrade when EngravingSettings is generated with its metadata.
    public func hasSymbol(_ symbol: MusicFontSymbol) -> Bool {
        return true
    }
}
