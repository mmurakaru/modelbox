import SwiftUI
import AppKit

/// Procedural template icon: three stacked rounded bars (a stack of models).
@MainActor
enum MenuBarIcon {
    static let nsImage: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let viewBox: CGFloat = 100
            ctx.scaleBy(x: rect.width / viewBox, y: rect.height / viewBox)
            ctx.setFillColor(NSColor.black.cgColor)

            let barWidth: CGFloat = 72
            let barHeight: CGFloat = 20
            let x: CGFloat = (viewBox - barWidth) / 2
            let cornerRadius: CGFloat = 5
            for y in [CGFloat(13), 40, 67] {
                let path = CGPath(
                    roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight),
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
                ctx.addPath(path)
                ctx.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
