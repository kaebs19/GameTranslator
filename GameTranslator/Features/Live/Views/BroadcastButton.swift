import ReplayKit
import SwiftUI

/// App-styled button whose taps land on the system broadcast picker,
/// because only the system view may start a broadcast.
struct BroadcastButton: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppGradient.action, in: .rect(cornerRadius: AppRadius.medium))
            .accessibilityHidden(true)
            .overlay {
                BroadcastPicker(accessibilityLabel: String(localized: title))
            }
    }
}

private struct BroadcastPicker: UIViewRepresentable {
    let accessibilityLabel: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = Bundle.main.bundleIdentifier.map { "\($0).BroadcastExtension" }
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ picker: RPSystemBroadcastPickerView, context: Context) {
        guard let button = picker.subviews.compactMap({ $0 as? UIButton }).first else { return }
        // The label underneath replaces the system icon; the button still fills the area.
        button.setImage(nil, for: .normal)
        button.setImage(nil, for: .selected)
        button.frame = picker.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.accessibilityLabel = accessibilityLabel
    }
}
