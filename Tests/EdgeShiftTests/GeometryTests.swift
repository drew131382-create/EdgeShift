import XCTest
@testable import EdgeShift

final class GeometryTests: XCTestCase {
    let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    func testSnapAllSides() {
        let size = CGSize(width: 1000, height: 800)
        XCTAssertEqual(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: -990, y: 100)), CGPoint(x: -1000, y: 100))
        XCTAssertEqual(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 1915, y: 100)), CGPoint(x: 1920, y: 100))
        XCTAssertEqual(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 300, y: -790)), CGPoint(x: 300, y: -800))
        XCTAssertEqual(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 300, y: 1075)), CGPoint(x: 300, y: 1080))
    }
    func testSnapMaintainsOverlap() {
        let p = LayoutGeometry.snapped(main: main, secondary: CGSize(width: 1000, height: 800), proposed: CGPoint(x: 1920, y: 9000))
        XCTAssertEqual(p, CGPoint(x: 1920, y: 1079))
    }
    func testTraversabilityUsesPointerHeight() {
        let secondary = CGRect(x: 1920, y: 200, width: 1000, height: 800)
        XCTAssertTrue(LayoutGeometry.traversable(edge: .right, at: CGPoint(x: 1919, y: 300), main: main, secondary: secondary))
        XCTAssertFalse(LayoutGeometry.traversable(edge: .right, at: CGPoint(x: 1919, y: 100), main: main, secondary: secondary))
        XCTAssertFalse(LayoutGeometry.traversable(edge: .left, at: CGPoint(x: 1919, y: 300), main: main, secondary: secondary))
    }
    func testCenteredOriginsWithOddDimensionsAndOffset() {
        let a = CGRect(x: -301, y: 57, width: 1001, height: 801)
        let b = CGRect(x: 0, y: 0, width: 400, height: 600)
        XCTAssertEqual(LayoutGeometry.centeredOrigin(edge: .left, main: a, secondary: b), CGPoint(x: -701, y: 158))
        XCTAssertEqual(LayoutGeometry.centeredOrigin(edge: .right, main: a, secondary: b), CGPoint(x: 700, y: 158))
        XCTAssertEqual(LayoutGeometry.centeredOrigin(edge: .top, main: a, secondary: b), CGPoint(x: -1, y: -543))
        XCTAssertEqual(LayoutGeometry.centeredOrigin(edge: .bottom, main: a, secondary: b), CGPoint(x: -1, y: 858))
    }
    func testVerticalTraversabilityAndCornerDirection() {
        let top = CGRect(x: 200, y: -800, width: 1000, height: 800)
        let bottom = CGRect(x: 200, y: 1080, width: 1000, height: 800)
        XCTAssertTrue(LayoutGeometry.traversable(edge: .top, at: CGPoint(x: 300, y: 0), main: main, secondary: top))
        XCTAssertFalse(LayoutGeometry.traversable(edge: .top, at: CGPoint(x: 100, y: 0), main: main, secondary: top))
        XCTAssertTrue(LayoutGeometry.traversable(edge: .bottom, at: CGPoint(x: 300, y: 1079), main: main, secondary: bottom))
        XCTAssertFalse(LayoutGeometry.traversable(edge: .bottom, at: CGPoint(x: 1300, y: 1079), main: main, secondary: bottom))
        XCTAssertEqual(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 0), deltaX: -2, deltaY: -3, main: main), .top)
        XCTAssertEqual(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 0), deltaX: -3, deltaY: -3, main: main), .left)
        XCTAssertNil(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 500), deltaX: 1, deltaY: 0, main: main))
    }
    func testPushDurationAndGap() {
        var tracker = PushTracker()
        XCTAssertEqual(tracker.update(edge: .left, time: 10, duration: 2), 0)
        for i in 1...20 { _ = tracker.update(edge: .left, time: 10 + Double(i) * 0.1, duration: 2) }
        XCTAssertEqual(tracker.update(edge: .left, time: 12.01, duration: 2), 1)
        XCTAssertEqual(tracker.update(edge: .left, time: 12.3, duration: 2), 0)
        XCTAssertEqual(tracker.update(edge: .right, time: 12.4, duration: 2), 0)
    }
}
