import Foundation

import CoreGraphics

enum Side { case left, right, top, bottom }

enum LayoutGeometry {
    // Snap to the closest edge, preserving an overlap of at least one logical point.
    static func snapped(main: CGRect, secondary: CGSize, proposed: CGPoint) -> CGPoint {
        let candidates: [(CGFloat, CGPoint)] = [
            (abs(proposed.x + secondary.width - main.minX), CGPoint(x: main.minX - secondary.width, y: clamp(proposed.y, main.minY - secondary.height + 1, main.maxY - 1))),
            (abs(proposed.x - main.maxX), CGPoint(x: main.maxX, y: clamp(proposed.y, main.minY - secondary.height + 1, main.maxY - 1))),
            (abs(proposed.y + secondary.height - main.minY), CGPoint(x: clamp(proposed.x, main.minX - secondary.width + 1, main.maxX - 1), y: main.minY - secondary.height)),
            (abs(proposed.y - main.maxY), CGPoint(x: clamp(proposed.x, main.minX - secondary.width + 1, main.maxX - 1), y: main.maxY))
        ]
        return candidates.min(by: { $0.0 < $1.0 })!.1
    }
    static func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(x, lo), hi) }
    static func traversable(edge: Side, at point: CGPoint, main: CGRect, secondary: CGRect) -> Bool {
        switch edge {
        case .left:
            return abs(secondary.maxX - main.minX) < 1 && point.y >= secondary.minY && point.y < secondary.maxY
        case .right:
            return abs(secondary.minX - main.maxX) < 1 && point.y >= secondary.minY && point.y < secondary.maxY
        case .top:
            return abs(secondary.maxY - main.minY) < 1 && point.x >= secondary.minX && point.x < secondary.maxX
        case .bottom:
            return abs(secondary.minY - main.maxY) < 1 && point.x >= secondary.minX && point.x < secondary.maxX
        }
    }

    // Core Graphics uses a downward-positive Y axis. Ties favor horizontal edges.
    static func outwardEdge(point: CGPoint, deltaX: CGFloat, deltaY: CGFloat, main: CGRect) -> Side? {
        guard point.x >= main.minX - 1, point.x < main.maxX + 1,
              point.y >= main.minY - 1, point.y < main.maxY + 1 else { return nil }
        var candidates: [(Side, CGFloat)] = []
        if point.x <= main.minX + 1 && deltaX < 0 { candidates.append((.left, -deltaX)) }
        if point.x >= main.maxX - 2 && deltaX > 0 { candidates.append((.right, deltaX)) }
        if point.y <= main.minY + 1 && deltaY < 0 { candidates.append((.top, -deltaY)) }
        if point.y >= main.maxY - 2 && deltaY > 0 { candidates.append((.bottom, deltaY)) }
        return candidates.reduce(nil as (Side, CGFloat)?) { best, candidate in
            guard let best else { return candidate }
            return candidate.1 > best.1 ? candidate : best
        }?.0
    }

    static func centeredOrigin(edge: Side, main: CGRect, secondary: CGRect) -> CGPoint {
        switch edge {
        case .left: return CGPoint(x: main.minX - secondary.width, y: (main.midY - secondary.height / 2).rounded())
        case .right: return CGPoint(x: main.maxX, y: (main.midY - secondary.height / 2).rounded())
        case .top: return CGPoint(x: (main.midX - secondary.width / 2).rounded(), y: main.minY - secondary.height)
        case .bottom: return CGPoint(x: (main.midX - secondary.width / 2).rounded(), y: main.maxY)
        }
    }
}

struct PushTracker {
    var edge: Side?
    var started: TimeInterval = 0
    var last: TimeInterval = 0
    mutating func reset() { edge = nil; started = 0; last = 0 }
    mutating func update(edge newEdge: Side, time: TimeInterval, duration: TimeInterval, gap: TimeInterval = 0.2) -> Double {
        if edge != newEdge || time - last > gap || time < last { edge = newEdge; started = time }
        last = time
        return min(1, max(0, (time - started) / duration))
    }
}
