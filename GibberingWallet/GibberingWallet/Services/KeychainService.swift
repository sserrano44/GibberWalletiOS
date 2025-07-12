import Foundation
import Security

class KeychainService {
    private let service = "com.gibberwallet.wallet"
    private let account = "wallet-data"
    
    func saveWallet(_ wallet: Wallet) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(wallet)
        
        // Delete any existing wallet first
        deleteWalletSilently()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }
    
    func loadWallet() -> Wallet? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        
        guard status == errSecSuccess,
              let walletData = data as? Data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(Wallet.self, from: walletData)
    }
    
    func deleteWallet() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }
    
    private func deleteWalletSilently() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case unableToSave
    case unableToLoad
    case unableToDelete
    
    var errorDescription: String? {
        switch self {
        case .unableToSave:
            return "Unable to save wallet to keychain"
        case .unableToLoad:
            return "Unable to load wallet from keychain"
        case .unableToDelete:
            return "Unable to delete wallet from keychain"
        }
    }
}