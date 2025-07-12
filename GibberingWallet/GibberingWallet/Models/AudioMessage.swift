import Foundation

enum MessageType: String, Codable {
    case connect = "connect"
    case transaction = "transaction"
    case signedTransaction = "signed_transaction"
    case error = "error"
}

struct AudioMessage: Codable {
    let type: MessageType
    let data: Data
    let timestamp: Date
    
    init(type: MessageType, data: Data) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

struct ConnectMessage: Codable {
    let appName: String
    let appVersion: String
    let chainId: String
}

struct TransactionRequest: Codable {
    let transaction: Transaction
    let requestId: String
}

struct SignedTransactionResponse: Codable {
    let signedTransaction: String
    let requestId: String
}

struct ErrorMessage: Codable {
    let message: String
    let code: String
}