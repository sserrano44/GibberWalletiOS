import Foundation
import Combine
import LocalAuthentication

class WalletManager: ObservableObject {
    @Published var hasWallet = false
    @Published var currentWallet: Wallet?
    @Published var isAuthenticated = false
    
    private let keychainService = KeychainService()
    private let cryptoService = CryptoService()
    
    init() {
        loadWallet()
    }
    
    func loadWallet() {
        if let walletData = keychainService.loadWallet() {
            currentWallet = walletData
            hasWallet = true
        }
    }
    
    func createNewWallet() throws {
        let privateKey = cryptoService.generatePrivateKey()
        let address = try cryptoService.deriveAddress(from: privateKey)
        
        let wallet = Wallet(
            privateKey: privateKey,
            address: address,
            createdAt: Date()
        )
        
        try keychainService.saveWallet(wallet)
        currentWallet = wallet
        hasWallet = true
    }
    
    func importWallet(privateKey: String) throws {
        let address = try cryptoService.deriveAddress(from: privateKey)
        
        let wallet = Wallet(
            privateKey: privateKey,
            address: address,
            createdAt: Date()
        )
        
        try keychainService.saveWallet(wallet)
        currentWallet = wallet
        hasWallet = true
    }
    
    func deleteWallet() throws {
        try keychainService.deleteWallet()
        currentWallet = nil
        hasWallet = false
        isAuthenticated = false
    }
    
    func authenticate() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw WalletError.biometricNotAvailable
        }
        
        let reason = "Authenticate to access your wallet"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            await MainActor.run {
                self.isAuthenticated = success
            }
        } catch {
            throw WalletError.authenticationFailed
        }
    }
    
    func signTransaction(_ transaction: Transaction) throws -> String {
        guard let wallet = currentWallet else {
            throw WalletError.noWalletFound
        }
        
        guard isAuthenticated else {
            throw WalletError.notAuthenticated
        }
        
        return try cryptoService.signTransaction(transaction, with: wallet.privateKey)
    }
}

enum WalletError: LocalizedError {
    case noWalletFound
    case invalidPrivateKey
    case biometricNotAvailable
    case authenticationFailed
    case notAuthenticated
    case signingFailed
    
    var errorDescription: String? {
        switch self {
        case .noWalletFound:
            return "No wallet found"
        case .invalidPrivateKey:
            return "Invalid private key"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .authenticationFailed:
            return "Authentication failed"
        case .notAuthenticated:
            return "Please authenticate first"
        case .signingFailed:
            return "Failed to sign transaction"
        }
    }
}