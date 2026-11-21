import AlphaTabRuntime
import Testing

@testable import AlphaTab

/// A squeezed bar must keep the gap alphaTab already measured between lyric rods.
/// Neighbouring rods are one spring apart. A beat between two rods is several springs,
/// and giving width back must not pull that pair together (#760).
@Suite
struct LyricOverlayGapTests {
    @Test
    func neighbouringRodsKeepTheMeasuredGap() throws {
        let positions = try positionsFor(
            times: [0, 120],
            rods: [Rod(time: 0, left: 20, right: 20), Rod(time: 120, left: 20, right: 20)]
        )
        let gap = try span(positions, 0, 120)
        #expect(gap + 0.05 >= 43)
    }

    @Test
    func aBeatBetweenRodsKeepsTheMeasuredGap() throws {
        let positions = try positionsFor(
            times: [0, 120, 240],
            rods: [Rod(time: 0, left: 30, right: 30), Rod(time: 240, left: 30, right: 30)]
        )
        let gap = try span(positions, 0, 240)
        #expect(gap + 0.05 >= 63)
    }
}

private struct Rod {
    var time: Double
    var left: Double
    var right: Double
}

private func span(_ positions: Map<Double, Double>, _ start: Double, _ end: Double) throws -> Double {
    let left = try #require(positions.get(start))
    let right = try #require(positions.get(end))
    return right - left
}

private func positionsFor(times: [Double], rods: [Rod]) throws -> Map<Double, Double> {
    let info = BarLayoutingInfo()
    for time in times {
        _ = try info.addSpring(time, 120, 0, 0, 0)
    }
    for rod in rods {
        try info.addOverlayRod("lyrics", rod.time, rod.left, rod.right)
    }
    info.finish()
    return info.buildOnTimePositions(1)
}
