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

    static func snappedToDisplays(secondary: CGSize, proposed: CGPoint, otherScreens: [CGRect]) -> CGPoint? {
        let candidates = otherScreens.map { snapped(main: $0, secondary: secondary, proposed: proposed) }
        return candidates.filter { candidate in
            let rect = CGRect(origin: candidate, size: secondary)
            return !otherScreens.contains(where: { $0.intersects(rect) }) && allConnected(otherScreens + [rect])
        }.min { a, b in
            hypot(a.x - proposed.x, a.y - proposed.y) < hypot(b.x - proposed.x, b.y - proposed.y)
        }
    }
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

    // Place beyond screens already on the requested side, then avoid any other overlaps.
    static func nextAvailableOrigin(edge: Side, main: CGRect, target: CGRect, obstacles: [CGRect]) -> CGPoint {
        var origin = centeredOrigin(edge: edge, main: main, secondary: target)
        switch edge {
        case .left:
            if let boundary = obstacles.filter({ $0.maxX <= main.minX }).map(\.minX).min() { origin.x = boundary - target.width }
        case .right:
            if let boundary = obstacles.filter({ $0.minX >= main.maxX }).map(\.maxX).max() { origin.x = boundary }
        case .top:
            if let boundary = obstacles.filter({ $0.maxY <= main.minY }).map(\.minY).min() { origin.y = boundary - target.height }
        case .bottom:
            if let boundary = obstacles.filter({ $0.minY >= main.maxY }).map(\.maxY).max() { origin.y = boundary }
        }
        for _ in 0...obstacles.count {
            let rect = CGRect(origin: origin, size: target.size)
            let collisions = obstacles.filter { $0.intersects(rect) }
            guard !collisions.isEmpty else { break }
            switch edge {
            case .left: origin.x = collisions.map(\.minX).min()! - target.width
            case .right: origin.x = collisions.map(\.maxX).max()!
            case .top: origin.y = collisions.map(\.minY).min()! - target.height
            case .bottom: origin.y = collisions.map(\.maxY).max()!
            }
        }
        return origin
    }

    static func allConnected(_ screens: [CGRect]) -> Bool {
        guard !screens.isEmpty else { return false }
        func adjacent(_ a: CGRect, _ b: CGRect) -> Bool {
            let verticalOverlap = min(a.maxY, b.maxY) - max(a.minY, b.minY) > 0
            let horizontalOverlap = min(a.maxX, b.maxX) - max(a.minX, b.minX) > 0
            let horizontalTouch = abs(a.maxX - b.minX) < 1 || abs(b.maxX - a.minX) < 1
            let verticalTouch = abs(a.maxY - b.minY) < 1 || abs(b.maxY - a.minY) < 1
            return (horizontalTouch && verticalOverlap) || (verticalTouch && horizontalOverlap)
        }
        var seen: Set<Int> = [0]
        var pending = [0]
        while let current = pending.popLast() {
            for i in screens.indices where !seen.contains(i) && adjacent(screens[current], screens[i]) {
                seen.insert(i); pending.append(i)
            }
        }
        return seen.count == screens.count
    }
}

struct DisplayCycle<ID: Equatable> {
    private(set) var last: ID?
    func next(in ordered: [ID]) -> ID? {
        guard !ordered.isEmpty else { return nil }
        guard let last, let index = ordered.firstIndex(of: last) else { return ordered[0] }
        return ordered[(index + 1) % ordered.count]
    }
    mutating func didMove(_ id: ID) { last = id }
    mutating func reset() { last = nil }
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
