import SwiftUI

/// A label on the left and a value on the right. At accessibility text sizes the two would squeeze each
/// other into narrow columns, so they stack instead, value under label.
struct SplitRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                leading
                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: alignment) {
                leading
                Spacer(minLength: Spacing.small)
                trailing
            }
        }
    }
}
