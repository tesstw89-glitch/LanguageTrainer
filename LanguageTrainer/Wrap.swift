import SwiftUI

// iOS 16+ flow layout using Layout protocol
private struct WrapLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {

        // ✅ Never allow 0-width fallback (causes “everything wraps instantly”)
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: nil, height: nil))

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let maxWidth = bounds.width

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: nil, height: nil))

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            sub.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// ✅ Public Wrap view (same name as before)
struct Wrap<Element: Hashable, Content: View>: View {

    let words: [Element]
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: (Element) -> Content

    init(
        words: [Element],
        spacing: CGFloat = 10,
        lineSpacing: CGFloat = 10,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.words = words
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        WrapLayout(spacing: spacing, lineSpacing: lineSpacing) {
            ForEach(words, id: \.self) { w in
                content(w)
            }
        }
    }
}
