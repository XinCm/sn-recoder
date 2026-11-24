import CoreGraphics
import Foundation

/// Geometry and placement for the hover "quick look" card. Kept in the model
/// layer so the no-overlap guarantee can be unit tested without SwiftUI.
enum HoverPreviewLayout {
    static let width: CGFloat = 360
    static let maxItemsHeight: CGFloat = 360
    static let chromeHeight: CGFloat = 116
    static let gap: CGFloat = 24
    static let margin: CGFloat = 14

    /// Rough content height, used only to place the card before the actual
    /// scroll area has laid out.
    static func estimatedItemsHeight(for items: [MemoItem]) -> CGFloat {
        guard !items.isEmpty else { return 30 }
        let usableWidth = width - 32 - 14 - 8
        let charsPerLine = max(12, usableWidth / 12.5)

        var lineCount: CGFloat = 0
        for item in items {
            let visualLength = item.text.reduce(CGFloat(0)) { length, character in
                length + (character.isASCII ? 0.55 : 1)
            }
            lineCount += max(1, ceil(visualLength / charsPerLine))
        }
        return lineCount * 18 + CGFloat(items.count) * 9 + 20
    }

    static func cardHeight(for items: [MemoItem]) -> CGFloat {
        let itemsHeight = min(
            max(estimatedItemsHeight(for: items), 1),
            maxItemsHeight
        )
        return chromeHeight + itemsHeight
    }

    /// Top-left origin for the card in panel coordinates. The card is placed to
    /// the right or left of the day box with a gap, and only falls back to
    /// above/below if neither side fits. It therefore never covers the hovered
    /// day box.
    static func cardOrigin(anchor: CGRect, panelSize: CGSize, cardSize: CGSize) -> CGPoint {
        let cardWidth = cardSize.width
        let cardHeight = cardSize.height
        let rightSpace = panelSize.width - anchor.maxX - margin
        let leftSpace = anchor.minX - margin
        let required = cardWidth + gap

        var x: CGFloat
        if rightSpace >= required {
            x = anchor.maxX + gap
        } else if leftSpace >= required {
            x = anchor.minX - gap - cardWidth
        } else {
            // Keep the card on the roomier side; with the 360 pt card on a
            // 920 pt panel this branch is normally unreachable.
            x = rightSpace >= leftSpace
                ? panelSize.width - margin - cardWidth
                : margin
        }
        x = min(max(x, margin), panelSize.width - margin - cardWidth)

        var y = anchor.midY - cardHeight / 2
        y = min(max(y, margin), panelSize.height - margin - cardHeight)

        var frame = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)

        // Safety net: if clamping ever produced an overlap, move the card above
        // or below the anchor instead of covering it.
        if frame.intersects(anchor) {
            let centeredX = min(
                max(anchor.midX - cardWidth / 2, margin),
                panelSize.width - margin - cardWidth
            )
            let below = anchor.maxY + gap
            let above = anchor.minY - gap - cardHeight
            if below + cardHeight <= panelSize.height - margin {
                frame.origin = CGPoint(x: centeredX, y: below)
            } else if above >= margin {
                frame.origin = CGPoint(x: centeredX, y: above)
            }
        }

        return frame.origin
    }

    static func cardFrame(anchor: CGRect, panelSize: CGSize, cardSize: CGSize) -> CGRect {
        CGRect(
            origin: cardOrigin(anchor: anchor, panelSize: panelSize, cardSize: cardSize),
            size: cardSize
        )
    }
}
