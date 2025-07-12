import SwiftUI

struct MainWalletView: View {
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var audioService = AudioCommunicationService()
    @State private var isListening = false
    @State private var showingTransaction = false
    @State private var currentTransaction: Transaction?
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Wallet Info Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wallet Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(walletManager.currentWallet?.displayAddress ?? "")
                                .font(.headline)
                                .fontDesign(.monospaced)
                        }
                        
                        Spacer()
                        
                        Button(action: copyAddress) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
                
                // Connection Status
                VStack(spacing: 20) {
                    if isListening {
                        VStack(spacing: 16) {
                            AudioWaveAnimation()
                                .frame(height: 100)
                            
                            Text("Listening for transactions...")
                                .font(.headline)
                            
                            Text("Audio Level: \(String(format: "%.2f", audioService.audioLevel))")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text("Place your device near the computer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Ready to connect")
                                .font(.headline)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Action Button
                Button(action: toggleListening) {
                    HStack {
                        Image(systemName: isListening ? "stop.circle.fill" : "play.circle.fill")
                        Text(isListening ? "Stop Listening" : "Start Listening")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isListening ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("GibberWallet")
            .navigationBarItems(
                trailing: Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            )
        }
        .sheet(isPresented: $showingTransaction) {
            if let transaction = currentTransaction {
                TransactionApprovalView(
                    transaction: transaction,
                    onApprove: { signAndSendTransaction(transaction) },
                    onReject: { rejectTransaction() }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            setupAudioService()
        }
    }
    
    private func setupAudioService() {
        audioService.onTransactionReceived = { transaction in
            currentTransaction = transaction
            showingTransaction = true
        }
        
        audioService.onError = { error in
            print("Audio service error: \(error)")
        }
        
        audioService.onConnectionEstablished = {
            print("Audio connection established")
        }
    }
    
    private func toggleListening() {
        if isListening {
            audioService.stopListening()
        } else {
            Task {
                try? await walletManager.authenticate()
                if walletManager.isAuthenticated {
                    audioService.startListening()
                }
            }
        }
        isListening.toggle()
    }
    
    private func copyAddress() {
        if let address = walletManager.currentWallet?.address {
            UIPasteboard.general.string = address
        }
    }
    
    private func signAndSendTransaction(_ transaction: Transaction) {
        do {
            let signedTx = try walletManager.signTransaction(transaction)
            audioService.sendSignedTransaction(signedTx, requestId: "123") // TODO: Use actual request ID
            showingTransaction = false
            currentTransaction = nil
        } catch {
            // Handle error
            print("Signing error: \(error)")
        }
    }
    
    private func rejectTransaction() {
        audioService.sendError("Transaction rejected by user", code: "USER_REJECTED")
        showingTransaction = false
        currentTransaction = nil
    }
}

struct AudioWaveAnimation: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4)
                    .scaleEffect(y: animating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}