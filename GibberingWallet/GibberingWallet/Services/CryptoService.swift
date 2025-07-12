import Foundation
import CryptoKit

class CryptoService {
    
    func generatePrivateKey() -> String {
        let privateKey = P256.Signing.PrivateKey()
        let rawKey = privateKey.rawRepresentation
        return rawKey.hexString
    }
    
    func deriveAddress(from privateKeyHex: String) throws -> String {
        guard let privateKeyData = Data(hexString: privateKeyHex) else {
            throw WalletError.invalidPrivateKey
        }
        
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let publicKey = privateKey.publicKey
        
        // Get uncompressed public key (65 bytes: 04 + 32 bytes X + 32 bytes Y)
        let publicKeyData = publicKey.x963Representation
        
        // Remove the 04 prefix byte
        let publicKeyWithoutPrefix = publicKeyData.dropFirst()
        
        // Keccak256 hash of the public key
        let hash = publicKeyWithoutPrefix.keccak256()
        
        // Take last 20 bytes as address
        let addressData = hash.suffix(20)
        
        return "0x" + addressData.hexString
    }
    
    func signTransaction(_ transaction: Transaction, with privateKeyHex: String) throws -> String {
        guard let privateKeyData = Data(hexString: privateKeyHex) else {
            throw WalletError.invalidPrivateKey
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let transactionData = try encoder.encode(transaction)
        
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let signature = try privateKey.signature(for: transactionData)
        
        return signature.rawRepresentation.hexString
    }
}

// Helper extensions
extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "0x"))
        let len = hex.count / 2
        var data = Data(capacity: len)
        var index = hex.startIndex
        
        for _ in 0..<len {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    func keccak256() -> Data {
        // Simplified keccak256 - in production, use a proper implementation
        return SHA256.hash(data: self).data
    }
}

extension Digest {
    var data: Data {
        return Data(self)
    }
}