import SwiftUI

struct WalletSetupView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingImportSheet = false
    @State private var privateKeyInput = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "wallet.pass")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to GibberWallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your secure offline wallet for sound-based transactions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: createNewWallet) {
                        Label("Create New Wallet", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("Import Existing Wallet", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportWalletSheet(privateKeyInput: $privateKeyInput) {
                importWallet()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createNewWallet() {
        do {
            try walletManager.createNewWallet()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func importWallet() {
        do {
            try walletManager.importWallet(privateKey: privateKeyInput)
            showingImportSheet = false
            privateKeyInput = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct ImportWalletSheet: View {
    @Binding var privateKeyInput: String
    @Environment(\.dismiss) var dismiss
    let onImport: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Import Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your private key to import an existing wallet")
                    .foregroundColor(.secondary)
                
                SecureField("Private Key", text: $privateKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("Your private key will be stored securely in the iOS Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onImport) {
                    Text("Import Wallet")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(privateKeyInput.isEmpty)
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }
            )
        }
    }
}