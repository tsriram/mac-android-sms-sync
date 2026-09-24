import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: SyncViewModel

    var body: some View {
        MainWindowView(viewModel: viewModel)
            .sheet(isPresented: $viewModel.showPairingSheet) {
                PairingView(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }
}

struct PairingView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var enteredPin = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair with Android")
                .font(.title2)

            if let error = viewModel.pairingError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Text("Enter the 6-digit PIN shown on your phone:")
                .foregroundStyle(.secondary)

            TextField("PIN", text: $enteredPin)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 220)
                .onChange(of: enteredPin) { newValue in
                    enteredPin = String(newValue.filter { $0.isNumber }.prefix(6))
                }

            Text("Keep the SMSync app open on your phone.\nThe PIN expires after 2 minutes.")
                .foregroundStyle(.secondary)
                .font(.caption)
                .multilineTextAlignment(.center)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Pair") {
                    viewModel.completePairing(pin: enteredPin)
                }
                .disabled(enteredPin.count != 6)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 350)
    }
}