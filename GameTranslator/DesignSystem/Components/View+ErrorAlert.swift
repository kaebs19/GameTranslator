import SwiftUI

extension View {
    /// Shows an alert while `error` is set and clears it on dismissal.
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        let isPresented = Binding { error.wrappedValue != nil } set: { if !$0 { error.wrappedValue = nil } }
        return alert(Text(.errorTitle), isPresented: isPresented, presenting: error.wrappedValue) { _ in
            AppButton(.commonOk, role: .cancel) {}
        } message: {
            Text($0.message)
        }
    }
}
