# GibberWallet iOS

Offline wallet component for the GibberWallet sound-based airgap wallet system. This iOS app enables secure transaction signing using audio transmission instead of QR codes.

## Features

- 🔐 Secure wallet generation and import
- 🎵 Sound-based communication using ggwave protocol  
- 📱 iOS Keychain integration for secure storage
- 🔏 Biometric authentication (Face ID/Touch ID)
- ✍️ Transaction signing
- 🔊 Bidirectional audio communication

## Architecture

The app follows MVVM architecture with SwiftUI:

- **Models**: Wallet, Transaction, AudioMessage
- **Views**: WalletSetupView, MainWalletView, TransactionApprovalView, SettingsView
- **ViewModels**: WalletManager
- **Services**: KeychainService, CryptoService, AudioCommunicationService

## Setup

1. Open `GibberWallet.xcodeproj` in Xcode
2. Install dependencies using Swift Package Manager
3. Build and run on iOS 15.0+

## Dependencies

- CryptoSwift: Cryptographic operations
- web3.swift: Ethereum utilities
- ggwave: Audio data transmission (to be integrated)

## Audio Protocol

The app implements the sound-based communication protocol defined in the EIP specification:

1. **Connection**: Establishes communication with web wallet
2. **Transaction Request**: Receives transaction data via audio
3. **User Approval**: Displays transaction for user review
4. **Signed Response**: Transmits signed transaction back via audio

## Security

- Private keys stored in iOS Keychain with hardware encryption
- Biometric authentication required for transaction signing
- No network connectivity - fully airgapped
- Sound-based transmission prevents remote attacks

## Integration

Works with:
- GibberWeb: Web-based hot wallet client
- Any EVM-compatible blockchain
- ggwave protocol for cross-platform compatibility

## Development

To integrate ggwave:
1. Add ggwave-objc as a dependency
2. Replace placeholder audio processing in AudioCommunicationService
3. Implement actual encoding/decoding logic

## License

MIT