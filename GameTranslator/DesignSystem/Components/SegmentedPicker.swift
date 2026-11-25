import SwiftUI

/// An option shown in a `SegmentedPicker`.
protocol SegmentOption: Hashable, CaseIterable {
    var title: LocalizedStringResource { get }
}

struct SegmentedPicker<Option: SegmentOption>: View where Option.AllCases: RandomAccessCollection {
    let title: LocalizedStringResource
    @Binding var selection: Option

    var body: some View {
        Picker(selection: $selection) {
            ForEach(Option.allCases, id: \.self) { Text($0.title).tag($0) }
        } label: {
            Text(title)
        }
        .pickerStyle(.segmented)
    }
}
