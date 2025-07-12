import SwiftUI

struct TransactionApprovalView: View {
    let transaction: Transaction
    let onApprove: () -> Void
    let onReject: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Transaction Request")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Review and approve this transaction")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 30)
                
                // Transaction Details
                VStack(alignment: .leading, spacing: 20) {
                    TransactionDetailRow(
                        label: "To",
                        value: formatAddress(transaction.to),
                        isMonospaced: true
                    )
                    
                    TransactionDetailRow(
                        label: "Amount",
                        value: transaction.displayValue,
                        isHighlighted: true
                    )
                    
                    if let gas = transaction.gas, let gasPrice = transaction.gasPrice {
                        TransactionDetailRow(
                            label: "Estimated Gas",
                            value: calculateGasFee(gas: gas, gasPrice: gasPrice)
                        )
                    }
                    
                    TransactionDetailRow(
                        label: "Network",
                        value: getNetworkName(chainId: transaction.chainId)
                    )
                    
                    if transaction.data != nil && transaction.data != "0x" {
                        Button(action: { showingDetails.toggle() }) {
                            HStack {
                                Text("Contract Interaction")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showingDetails {
                            Text(transaction.data ?? "")
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding()
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onApprove()
                        dismiss()
                    }) {
                        Text("Approve & Sign")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onReject()
                        dismiss()
                    }) {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }
    
    private func calculateGasFee(gas: String, gasPrice: String) -> String {
        guard let gasValue = Double(gas),
              let gasPriceValue = Double(gasPrice) else {
            return "Unable to calculate"
        }
        
        let fee = (gasValue * gasPriceValue) / 1e18
        return String(format: "%.6f ETH", fee)
    }
    
    private func getNetworkName(chainId: String) -> String {
        switch chainId {
        case "1": return "Ethereum Mainnet"
        case "5": return "Goerli Testnet"
        case "11155111": return "Sepolia Testnet"
        case "137": return "Polygon"
        case "80001": return "Mumbai Testnet"
        default: return "Chain ID: \(chainId)"
        }
    }
}

struct TransactionDetailRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isHighlighted ? .bold : .regular)
                .fontDesign(isMonospaced ? .monospaced : .default)
                .foregroundColor(isHighlighted ? .primary : .secondary)
        }
    }
}