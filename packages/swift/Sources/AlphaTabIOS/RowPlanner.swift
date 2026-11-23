// SheetMuse: which rows of a laid-out score to draw and which to free, for the part of the page on screen. Pure: no
// alphaTab, no UIKit, so it is tested on its own (rows and a scroll position in, two lists out).

/// One row (a staff system) of the page, in page points.
public struct RowFrame: Equatable, Sendable {
    public var top: Double
    public var height: Double
    public var isDrawn: Bool
    public init(top: Double, height: Double, isDrawn: Bool) {
        self.top = top
        self.height = height
        self.isDrawn = isDrawn
    }
    var bottom: Double { top + height }
}

/// What is on screen: the scroll offset and the height of the view, and where the playhead is on the page.
public struct RowViewport: Equatable, Sendable {
    public var offsetY: Double
    public var height: Double
    public var playheadY: Double?
    public init(offsetY: Double, height: Double, playheadY: Double? = nil) {
        self.offsetY = offsetY
        self.height = height
        self.playheadY = playheadY
    }
}

public struct RowPlan: Equatable, Sendable {
    public var draw: [Int] = []
    public var free: [Int] = []
    public var isEmpty: Bool { draw.isEmpty && free.isEmpty }
}

public enum RowPlanner {
    /// Rows on screen, and the row holding the playhead, are always drawn and never freed. Rows within `drawScreens`
    /// screens of the view are drawn ahead, nearest first, at most `maxAhead` per call. Drawn rows farther than
    /// `freeScreens` screens are freed. Between the two limits a row is left as it is, so a wobble at the edge does
    /// not draw and free the same row again and again.
    public static func plan(
        rows: [RowFrame],
        view: RowViewport,
        drawScreens: Double = 1,
        freeScreens: Double = 1.5,
        maxAhead: Int = 2
    )
        -> RowPlan {
        guard view.height > 0, !rows.isEmpty else { return RowPlan() }
        let top = view.offsetY
        let bottom = view.offsetY + view.height
        let drawTop = top - drawScreens * view.height
        let drawBottom = bottom + drawScreens * view.height
        let freeTop = top - freeScreens * view.height
        let freeBottom = bottom + freeScreens * view.height
        let middle = (top + bottom) / 2
        let playheadRow = view.playheadY.flatMap { y in rows.firstIndex { $0.top <= y && y < $0.bottom } }

        var plan = RowPlan()
        var ahead: [(index: Int, distance: Double)] = []
        for (index, row) in rows.enumerated() {
            let onScreen = row.bottom >= top && row.top <= bottom
            if onScreen || index == playheadRow {
                if !row.isDrawn { plan.draw.append(index) }
            } else if row.bottom >= drawTop && row.top <= drawBottom {
                if !row.isDrawn { ahead.append((index, abs((row.top + row.bottom) / 2 - middle))) }
            } else if row.isDrawn, row.bottom < freeTop || row.top > freeBottom {
                plan.free.append(index)
            }
        }
        plan.draw += ahead.sorted { $0.distance < $1.distance }.prefix(maxAhead).map(\.index)
        return plan
    }
}
