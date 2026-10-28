import SwiftUI

struct MenuBarIcon: View {
    let pushing: Bool

    var body: some View {
        Canvas { context, _ in
            // The larger rear screen reads as the primary display; the smaller
            // screen overlaps it from the front, like the app's arrangement view.
            let primary = CGRect(x: 1.1, y: 1.2, width: 11.8, height: 9.4)
            let secondary = CGRect(x: 6.0, y: 5.8, width: 10.8, height: 8.0)
            drawDisplay(primary, in: &context, opacity: 1)
            drawStand(for: primary, in: &context, opacity: 1)

            if pushing {
                context.fill(Path(roundedRect: secondary, cornerSize: CGSize(width: 1.4, height: 1.4)),
                             with: .color(.primary.opacity(0.22)))
            }
            drawDisplay(secondary, in: &context, opacity: 1)
            drawStand(for: secondary, in: &context, opacity: 1)
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("EdgeShift，主屏与副屏")
    }

    private func drawDisplay(_ rect: CGRect, in context: inout GraphicsContext, opacity: Double) {
        let path = Path(roundedRect: rect, cornerSize: CGSize(width: 1.4, height: 1.4))
        context.stroke(path, with: .color(.primary.opacity(opacity)), lineWidth: 1.25)
    }

    private func drawStand(for rect: CGRect, in context: inout GraphicsContext, opacity: Double) {
        var stand = Path()
        let center = rect.midX
        stand.move(to: CGPoint(x: center, y: rect.maxY))
        stand.addLine(to: CGPoint(x: center, y: rect.maxY + 1.2))
        stand.move(to: CGPoint(x: center - 1.5, y: rect.maxY + 1.3))
        stand.addLine(to: CGPoint(x: center + 1.5, y: rect.maxY + 1.3))
        context.stroke(stand, with: .color(.primary.opacity(opacity)), lineWidth: 1.15)
    }
}
