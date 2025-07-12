import Foundation

struct Wallet: Codable {
    let privateKey: String
    let address: String
    let createdAt: Date
    
    var displayAddress: String {
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
}