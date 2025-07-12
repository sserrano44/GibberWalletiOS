import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingPrivateKey = false
    @State private var isAuthenticated = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Wallet") {
                    HStack {
                        Text("Address")
                        Spacer()
                        Text(walletManager.currentWallet?.displayAddress ?? "")
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    }
                    
                    Button(action: showPrivateKey) {
                        HStack {
                            Text("Show Private Key")
                            Spacer()
                            Image(systemName: "key")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Security") {
                    HStack {
                        Text("Biometric Authentication")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Button(action: testAuthentication) {
                        HStack {
                            Text("Test Authentication")
                            Spacer()
                            Image(systemName: "faceid")
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Protocol")
                        Spacer()
                        Text("ggwave")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/ggerganov/ggwave")!) {
                        HStack {
                            Text("Learn More")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                
                Section {
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Delete Wallet")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
        .alert("Delete Wallet", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteWallet()
            }
        } message: {
            Text("Are you sure you want to delete your wallet? This action cannot be undone. Make sure you have backed up your private key.")
        }
        .sheet(isPresented: $showingPrivateKey) {
            if isAuthenticated {
                PrivateKeyView()
            }
        }
    }
    
    private func showPrivateKey() {
        Task {
            do {
                try await walletManager.authenticate()
                isAuthenticated = true
                showingPrivateKey = true
            } catch {
                print("Authentication failed: \(error)")
            }
        }
    }
    
    private func testAuthentication() {
        Task {
            do {
                try await walletManager.authenticate()
                print("Authentication successful")
            } catch {
                print("Authentication failed: \(error)")
            }
        }
    }
    
    private func deleteWallet() {
        do {
            try walletManager.deleteWallet()
            dismiss()
        } catch {
            print("Failed to delete wallet: \(error)")
        }
    }
}

struct PrivateKeyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) var dismiss
    @State private var copiedToClipboard = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Private Key")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Keep this secret and never share it with anyone")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack {
                    Text(walletManager.currentWallet?.privateKey ?? "")
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .onTapGesture {
                            copyToClipboard()
                        }
                    
                    if copiedToClipboard {
                        Text("Copied to clipboard")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                trailing: Button("Done") { dismiss() }
            )
        }
    }
    
    private func copyToClipboard() {
        if let privateKey = walletManager.currentWallet?.privateKey {
            UIPasteboard.general.string = privateKey
            copiedToClipboard = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copiedToClipboard = false
            }
        }
    }
}