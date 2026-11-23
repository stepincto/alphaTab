import AlphaTabIOS
import Testing

/// 20 rows of 100 pt, none drawn.
private func rows(_ count: Int = 20, drawn: Set<Int> = []) -> [RowFrame] {
    (0..<count).map { RowFrame(top: Double($0) * 100, height: 100, isDrawn: drawn.contains($0)) }
}

@Suite struct RowPlannerTests {
    private let view = RowViewport(offsetY: 1000, height: 400)

    @Test func rowsOnScreenAreDrawn() {
        let plan = RowPlanner.plan(rows: rows(), view: view, maxAhead: 0)
        #expect(plan.draw.sorted() == [9, 10, 11, 12, 13, 14])
        #expect(plan.free.isEmpty)
    }

    @Test func rowsOnScreenAreNotCappedButRowsAheadAre() {
        let plan = RowPlanner.plan(rows: rows(), view: view, maxAhead: 2)
        #expect(plan.draw.count == 6 + 2)
    }

    @Test func aheadRowsComeNearestFirst() {
        let drawn = Set(9...14)
        let plan = RowPlanner.plan(rows: rows(drawn: drawn), view: view, maxAhead: 2)
        #expect(plan.draw.count == 2)
        #expect(Set(plan.draw) == [8, 15])
    }

    @Test func farRowsAreFreed() {
        // the view is 1000...1400; the free limit is 1.5 screens, so 400...2000 is kept
        let plan = RowPlanner.plan(rows: rows(40, drawn: [0, 1, 2, 39]), view: view)
        #expect(plan.free.sorted() == [0, 1, 2, 39])
    }

    @Test func betweenTheTwoLimitsARowIsLeftAlone() {
        // row 5 (500...600) is below the draw limit (600) and above the free limit (400): neither drawn nor freed
        let plan = RowPlanner.plan(rows: rows(drawn: [5]), view: view)
        #expect(!plan.draw.contains(5) && !plan.free.contains(5))
    }

    @Test func thePlayheadRowIsDrawnAndNeverFreed() {
        let withPlayhead = RowViewport(offsetY: 1000, height: 400, playheadY: 1950)
        let drawPlan = RowPlanner.plan(rows: rows(), view: withPlayhead, maxAhead: 0)
        #expect(drawPlan.draw.contains(19))
        let freePlan = RowPlanner.plan(rows: rows(drawn: [19]), view: withPlayhead)
        #expect(!freePlan.free.contains(19))
    }

    @Test func aPlanAppliedAgainPlansNothing() {
        var current = rows()
        var plan = RowPlanner.plan(rows: current, view: view, maxAhead: .max)
        for i in plan.draw { current[i].isDrawn = true }
        plan = RowPlanner.plan(rows: current, view: view, maxAhead: .max)
        #expect(plan.isEmpty)
    }

    @Test func noViewOrNoRowsPlansNothing() {
        #expect(RowPlanner.plan(rows: rows(), view: RowViewport(offsetY: 0, height: 0)).isEmpty)
        #expect(RowPlanner.plan(rows: [], view: view).isEmpty)
    }

    @Test func scrollingAWholeSongKeepsAboutFifteenRowsDrawn() {
        var current = rows(70)
        var peak = 0
        var offset = 0.0
        while offset < 7000 - 400 {
            let plan = RowPlanner.plan(rows: current, view: RowViewport(offsetY: offset, height: 400), maxAhead: .max)
            for i in plan.draw { current[i].isDrawn = true }
            for i in plan.free { current[i].isDrawn = false }
            peak = max(peak, current.filter(\.isDrawn).count)
            offset += 25
        }
        #expect(peak <= 16)
    }
}
