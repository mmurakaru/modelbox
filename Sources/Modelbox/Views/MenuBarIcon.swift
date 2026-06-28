import SwiftUI
import AppKit

/// Procedural template icon mirroring the brand mark (`Resources/AppIcon.svg`):
/// rounded squares laid out as the modelbox "boxes" motif. Monochrome so it
/// adapts to the menu bar's light/dark appearance.
@MainActor
enum MenuBarIcon {
    static let nsImage: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // The mark spans ~209 units; a small `padding` insets it so it sits with a
            // little breathing room in the menu bar (tune `padding` to taste).
            let markExtent: CGFloat = 209.3
            let padding: CGFloat = 16
            let viewBox = markExtent + padding * 2
            context.scaleBy(x: rect.width / viewBox, y: rect.height / viewBox)
            context.translateBy(x: padding, y: padding)
            context.setFillColor(NSColor.black.cgColor)

            let squareSize: CGFloat = 63.0782
            let cornerRadius: CGFloat = 8
            // (pivotX, pivotY, rotationDegrees) — same transforms as AppIcon.svg.
            let marks: [(CGFloat, CGFloat, CGFloat)] = [
                (0, 63.0782, -90),
                (146, 63.0792, -90),
                (0.0639648, 136.384, -90),
                (146.064, 136.158, -90),
                (0, 209.078, -90),
                (146, 209.236, -90),
                (73.1758, 94.2549, -90.1598),
            ]
            for (pivotX, pivotY, degrees) in marks {
                context.saveGState()
                context.translateBy(x: pivotX, y: pivotY)
                context.rotate(by: degrees * .pi / 180)
                context.addPath(CGPath(
                    roundedRect: CGRect(x: 0, y: 0, width: squareSize, height: squareSize),
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                ))
                context.fillPath()
                context.restoreGState()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
