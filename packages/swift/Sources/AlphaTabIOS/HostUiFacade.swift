// SheetMuse: the iOS host of alphaTab's API object. Same shape as the generated TestUiFacade (the Swift
// counterpart of alphaTab's per-platform UiFacade: web `BrowserUiFacade`, Android `AndroidUiFacade`), except that
// the containers are plain data: the app's view reads their bounds and scroll offsets and draws them.
#if canImport(CoreGraphics)
import AlphaTab
import AlphaTabRuntime
import CoreGraphics
import Foundation

/// A rectangle in the page the host view draws: the cursors, the selection, the canvas and each render partial.
public final class HostContainer: IContainer {
    public var children: [HostContainer] = []
    public var left: Double = 0
    public var top: Double = 0
    /// A render partial's image (a `CGImage`), set by `beginUpdateRenderResults`.
    public var body: Any?
    public var layoutResultId = ""
    public var isVisible = true
    /// Called after a scroll or bounds change, so the host view follows.
    public var onChange: (() -> Void)?
    /// Called for each scroll alphaTab asks for: the offset and the milliseconds to glide there (0 = jump).
    public var onScroll: ((_ to: Double, _ duration: Double) -> Void)?

    private var _width: Double = 0
    private var _height: Double = 0
    private var _scrollTop: Double = 0
    private var _scrollLeft: Double = 0
    private var lastBounds = CGRect.zero

    public var resize: any IEventEmitter = EventEmitter()
    public var mouseDown: any IEventEmitterOfT<any IMouseEventArgs> = EventEmitterOfT<any IMouseEventArgs>()
    public var mouseMove: any IEventEmitterOfT<any IMouseEventArgs> = EventEmitterOfT<any IMouseEventArgs>()
    public var mouseUp: any IEventEmitterOfT<any IMouseEventArgs> = EventEmitterOfT<any IMouseEventArgs>()

    public init() {}

    public var width: Double {
        get { _width }
        set {
            guard newValue != _width else { return }
            _width = newValue
            try? (resize as? EventEmitter)?.trigger()
            onChange?()
        }
    }

    public var height: Double {
        get { _height }
        set {
            guard newValue != _height else { return }
            _height = newValue
            try? (resize as? EventEmitter)?.trigger()
            onChange?()
        }
    }

    public var scrollTop: Double {
        get { _scrollTop }
        set { _scrollTop = newValue; onChange?() }
    }

    public var scrollLeft: Double {
        get { _scrollLeft }
        set { _scrollLeft = newValue; onChange?() }
    }

    public var frame: CGRect { CGRect(x: left, y: top, width: _width, height: _height) }

    public func appendChild(_ child: any IContainer) throws {
        if let host = child as? HostContainer { children.append(host) }
    }

    public func stopAnimation() {}

    public func setBounds(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        animation = nil // a jump, not a glide
        left = x.isNaN ? left : x
        top = y.isNaN ? top : y
        if !w.isNaN { _width = w }
        if !h.isNaN { _height = h }
        onChange?()
    }

    /// The beat cursor glides to `x` over `duration` ms; the host view animates `left` itself from `animation`.
    public var animation: (from: Double, to: Double, duration: Double)?

    public func transitionToX(_ duration: Double, _ x: Double) {
        animation = (left, x, duration)
        left = x
        onChange?()
    }

    public func clear() { children = [] }
}

/// A press or tap on the page, in page points, for `beatMouseDown` and friends.
public final class HostMouseEvent: IMouseEventArgs {
    private let point: CGPoint
    public let isLeftMouseButton = true
    public init(_ point: CGPoint) { self.point = point }
    public func getX(_ relativeTo: any IContainer) throws -> Double { point.x - ((relativeTo as? HostContainer)?.left ?? 0) }
    public func getY(_ relativeTo: any IContainer) throws -> Double { point.y - ((relativeTo as? HostContainer)?.top ?? 0) }
    public func preventDefault() {}
}

/// alphaTab is single-threaded by contract: its closures only ever run on the main queue.
private final class MainBox: @unchecked Sendable {
    let action: () throws -> Void
    init(_ action: @escaping () throws -> Void) { self.action = action }
}

public final class HostUiFacade: IUiFacade {
    public let root = HostContainer()
    public var rootContainer: any IContainer { root }
    public let areWorkersSupported = false
    public var canRender = true
    public let resizeThrottle: Double = 10
    public var canRenderChanged: any IEventEmitter = EventEmitter()
    public var rootContainerBecameVisible: any IEventEmitter = EventEmitter()

    /// The cursors alphaTab drives; the host view draws them.
    public private(set) var cursors: Cursors?
    private var api: AlphaTabApiBase<Any?>!
    private var placeholders: [String: HostContainer] = [:]
    private var resultCount = 0

    public init() {}

    public func initialize(_ api: AlphaTabApiBase<Any?>, _ raw: Any?) throws {
        self.api = api
        api.settings = (raw as? Settings) ?? Settings()
    }

    public func destroy() throws {}
    public func createCanvasElement() -> any IContainer { HostContainer() }
    public func triggerEvent(_ container: any IContainer, _ eventName: String, _ details: Any?, _ originalEvent: (any IMouseEventArgs)?) throws {}

    public func initialRender() throws {
        _ = try api.renderer.preRender.on { (_: Bool) in
            self.resultCount = 0
            self.placeholders.removeAll()
        }
        api.renderer.width = root.width
        try api.renderer.updateSettings(api.settings)
    }

    public func beginAppendRenderResults(_ renderResult: RenderFinishedEventArgs?) throws {
        guard let canvas = api.canvasElement as? HostContainer else { return }
        guard let result = renderResult else {
            // a null result ends the list: drop placeholders left over from a longer previous layout
            if canvas.children.count > resultCount { canvas.children.removeLast(canvas.children.count - resultCount) }
            canvas.onChange?()
            return
        }
        let placeholder: HostContainer
        if resultCount < canvas.children.count {
            placeholder = canvas.children[resultCount]
        } else {
            placeholder = HostContainer()
            canvas.children.append(placeholder)
        }
        placeholder.left = result.x
        placeholder.top = result.y
        placeholder.width = result.width
        placeholder.height = result.height
        placeholder.layoutResultId = result.id
        placeholders[result.id] = placeholder
        try api.renderer.renderResult(result.id)
        resultCount += 1
    }

    public func beginUpdateRenderResults(_ renderResult: RenderFinishedEventArgs) throws {
        guard let placeholder = placeholders[renderResult.id] else { return }
        placeholder.body = renderResult.renderResult
        placeholder.onChange?()
    }

    public func createWorkerRenderer() throws -> any IScoreRenderer { throw JsError("Not supported") }
    public func createWorkerAudioExporter(_ synth: (any IAlphaSynth)?) throws -> any IAudioExporterWorker { throw JsError("Not supported") }
    public func createWorkerPlayer() throws -> (any IAlphaSynth)? { nil }
    public func createBackingTrackPlayer() throws -> (any IAlphaSynth)? { nil }

    public func createCursors() throws -> Cursors? {
        cursors = cursors ?? Cursors(HostContainer(), HostContainer(), HostContainer(), HostContainer())
        return cursors
    }

    public func destroyCursors() throws {}

    public func beginInvoke(_ action: @escaping () throws -> Void) throws {
        let box = MainBox(action)
        DispatchQueue.main.async { try? box.action() }
    }

    public func throttle(_ action: @escaping () throws -> Void, _ delay: Double) throws -> () -> Void {
        let box = MainBox(action)
        var pending: DispatchWorkItem?
        return {
            pending?.cancel()
            let item = DispatchWorkItem { try? box.action() }
            pending = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000, execute: item)
        }
    }

    public func removeHighlights() {}
    public func highlightElements(_ groupId: String, _ masterBarIndex: Double) throws {}
    public func createSelectionElement() -> (any IContainer)? { HostContainer() }
    public func getScrollContainer() throws -> any IContainer { root }

    public func getOffset(_ scrollElement: (any IContainer)?, _ container: any IContainer) throws -> Bounds {
        let element = container as! HostContainer
        var top = element.top
        var left = element.left
        if let scroll = scrollElement as? HostContainer {
            let origin = try getOffset(nil, scroll)
            top += scroll.scrollTop - origin.y
            left += scroll.scrollLeft - origin.x
        }
        let b = Bounds()
        b.x = left
        b.y = top
        b.w = element.width
        b.h = element.height
        return b
    }

    public func scrollToY(_ scrollElement: any IContainer, _ offset: Double, _ speed: Double) throws {
        scrollElement.scrollTop = offset
        (scrollElement as? HostContainer)?.onScroll?(offset, speed)
    }
    public func scrollToX(_ scrollElement: any IContainer, _ offset: Double, _ speed: Double) throws { scrollElement.scrollLeft = offset }
    /// Overflow the smooth-scroll needs so the end can reach the target; the page view sizes its own content.
    public private(set) var canvasOverflow: Double = 0
    public func setCanvasOverflow(_ canvasElement: any IContainer, _ overflow: Double, _ isVertical: Bool) throws {
        canvasOverflow = overflow
        root.onChange?()
    }
    public func stopScrolling(_ scrollElement: any IContainer) throws {}

    public func load(_ data: Any?, _ success: @escaping (Score) throws -> Void, _ error: @escaping (JsError) throws -> Void) throws -> Bool {
        if let score = data as? Score {
            try success(score)
            return true
        }
        if let bytes = data as? Uint8Array {
            try success(ScoreLoader.loadScoreFromBytes(bytes, api.settings))
            return true
        }
        return false
    }

    public func loadSoundFont(_ data: Any?, _ append: Bool) throws -> Bool { false }
}

/// The host side of `PlayerMode.EnabledExternalMedia`: alphaTab tells the clock to play, pause and seek, and the
/// host tells alphaTab where the clock is (`ExternalClock.update`). Times are milliseconds.
public final class ExternalClock: IExternalMediaHandler {
    public var backingTrackDuration: Double
    public var playbackRate: Double = 1
    public var masterVolume: Double = 1
    public var onSeek: ((Double) -> Void)?
    public var onPlay: (() -> Void)?
    public var onPause: (() -> Void)?

    public init(duration: Double) { backingTrackDuration = duration }
    public func seekTo(_ time: Double) { onSeek?(time) }
    public func play() { onPlay?() }
    public func pause() { onPause?() }
}
#endif
