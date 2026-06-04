import SwiftUI

// MARK: - Wrapping Layout

/// A lightweight horizontal wrapping layout for natural pill/chip rows.
///
/// Use this when an `HStack` should wrap items onto additional rows instead of
/// scrolling horizontally or forcing equal-width grid columns.
public struct SagaWrappingHStack: Layout {
    public let horizontalSpacing: CGFloat
    public let verticalSpacing: CGFloat

    public init(
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 6
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(
            proposal: proposal,
            subviews: subviews
        )

        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.last.map { $0.y + $0.height } ?? 0
        )
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for row in rows(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        ) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + item.x,
                        y: bounds.minY + row.y
                    ),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func rows(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [Row] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [Row] = []
        var currentItems: [Item] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedX = currentItems.isEmpty ? 0 : currentX + horizontalSpacing

            if !currentItems.isEmpty, proposedX + size.width > maxWidth {
                rows.append(
                    Row(
                        y: currentY,
                        width: currentX,
                        height: currentHeight,
                        items: currentItems
                    )
                )
                currentY += currentHeight + verticalSpacing
                currentItems = []
                currentX = 0
                currentHeight = 0
            }

            let itemX = currentItems.isEmpty ? 0 : currentX + horizontalSpacing
            currentItems.append(
                Item(
                    index: index,
                    x: itemX,
                    size: size
                )
            )
            currentX = itemX + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(
                Row(
                    y: currentY,
                    width: currentX,
                    height: currentHeight,
                    items: currentItems
                )
            )
        }

        return rows
    }

    private struct Row {
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let items: [Item]
    }

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }
}

