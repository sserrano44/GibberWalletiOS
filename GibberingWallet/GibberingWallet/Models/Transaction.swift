import Foundation

struct Transaction: Codable {
    let from: String
    let to: String
    let value: String
    let data: String?
    let gas: String?
    let gasPrice: String?
    let nonce: String?
    let chainId: String
    
    var displayValue: String {
        // Convert Wei to ETH
        guard let weiValue = Double(value) else { return "0 ETH" }
        let ethValue = weiValue / 1e18
        return String(format: "%.6f ETH", ethValue)
    }
}