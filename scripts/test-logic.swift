import Foundation
import CoreGraphics

@main struct LogicTests {
    static func main() {
        let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let size = CGSize(width: 1000, height: 800)
        precondition(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: -990, y: 100)) == CGPoint(x: -1000, y: 100))
        precondition(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 1915, y: 100)) == CGPoint(x: 1920, y: 100))
        precondition(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 300, y: -790)) == CGPoint(x: 300, y: -800))
        precondition(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 300, y: 1075)) == CGPoint(x: 300, y: 1080))
        precondition(LayoutGeometry.snapped(main: main, secondary: size, proposed: CGPoint(x: 1920, y: 9000)) == CGPoint(x: 1920, y: 1079))
        let other = CGRect(x: 1920, y: 200, width: 1000, height: 800)
        precondition(LayoutGeometry.traversable(edge: .right, at: CGPoint(x: 1919, y: 300), main: main, secondary: other))
        precondition(!LayoutGeometry.traversable(edge: .right, at: CGPoint(x: 1919, y: 100), main: main, secondary: other))
        let odd = CGRect(x: -301, y: 57, width: 1001, height: 801)
        let small = CGRect(x: 0, y: 0, width: 400, height: 600)
        precondition(LayoutGeometry.centeredOrigin(edge: .left, main: odd, secondary: small) == CGPoint(x: -701, y: 158))
        precondition(LayoutGeometry.centeredOrigin(edge: .right, main: odd, secondary: small) == CGPoint(x: 700, y: 158))
        precondition(LayoutGeometry.centeredOrigin(edge: .top, main: odd, secondary: small) == CGPoint(x: -1, y: -543))
        precondition(LayoutGeometry.centeredOrigin(edge: .bottom, main: odd, secondary: small) == CGPoint(x: -1, y: 858))
        let above = CGRect(x: 200, y: -800, width: 1000, height: 800)
        let below = CGRect(x: 200, y: 1080, width: 1000, height: 800)
        precondition(LayoutGeometry.traversable(edge: .top, at: CGPoint(x: 300, y: 0), main: main, secondary: above))
        precondition(!LayoutGeometry.traversable(edge: .top, at: CGPoint(x: 100, y: 0), main: main, secondary: above))
        precondition(LayoutGeometry.traversable(edge: .bottom, at: CGPoint(x: 300, y: 1079), main: main, secondary: below))
        precondition(!LayoutGeometry.traversable(edge: .bottom, at: CGPoint(x: 1300, y: 1079), main: main, secondary: below))
        precondition(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 0), deltaX: -2, deltaY: -3, main: main) == .top)
        precondition(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 0), deltaX: -3, deltaY: -3, main: main) == .left)
        precondition(LayoutGeometry.outwardEdge(point: CGPoint(x: 0, y: 500), deltaX: 1, deltaY: 0, main: main) == nil)
        precondition(LayoutGeometry.outwardEdge(point: CGPoint(x: 800, y: 1079), deltaX: 0, deltaY: 1, main: main) == .bottom)
        var tracker = PushTracker()
        precondition(tracker.update(edge: .left, time: 10, duration: 2) == 0)
        for i in 1...20 { _ = tracker.update(edge: .left, time: 10 + Double(i) * 0.1, duration: 2) }
        precondition(tracker.update(edge: .left, time: 12.01, duration: 2) == 1)
        precondition(tracker.update(edge: .left, time: 12.3, duration: 2) == 0)
        precondition(tracker.update(edge: .right, time: 12.4, duration: 2) == 0)
        print("Layout and push logic checks passed.")
    }
}
