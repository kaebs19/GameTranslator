import SwiftUI

/// Position inside a paged view.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            ForEach(0..<count, id: \.self) { position in
                Circle()
                    .fill(position == index ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}
