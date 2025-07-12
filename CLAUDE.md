# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GibberWallet is an iOS offline wallet that uses sound-based communication for secure, airgapped Ethereum transaction signing. The app implements the ggwave protocol to transmit transaction data via audio instead of QR codes or network connections.

## Build and Development Commands

### Building the Project
- **Xcode**: Open `GibberingWallet/GibberingWallet.xcodeproj` in Xcode
- **Simple validation**: Run `./build.swift` to syntax-check Swift files
- **iOS Simulator**: Use Xcode's build and run functionality (requires proper Xcode project setup)

### Testing
- **Unit Tests**: Run via Xcode Test Navigator or `Cmd+U`
- **UI Tests**: Located in `GibberingWalletUITests/` directory
- **GGWave Testing**: Use `GGWaveTestUtility.swift` for audio communication testing

### Dependencies
- **CryptoSwift**: Cryptographic operations
- **web3.swift**: Ethereum utilities
- **ggwave**: Audio data transmission (C++ library with Objective-C++ bridge)

## Architecture Overview

The app follows **MVVM architecture** with SwiftUI:

### Core Components
- **Models** (`Models/`): `Wallet`, `Transaction`, `AudioMessage` - Core data structures
- **Views** (`Views/`): SwiftUI views for wallet setup, main interface, transaction approval, settings
- **Services** (`Services/`): Business logic and external integrations
  - `WalletManager.swift`: Central wallet state management with biometric auth
  - `AudioCommunicationService.swift`: ggwave integration for sound-based communication
  - `KeychainService.swift`: Secure storage using iOS Keychain
  - `CryptoService.swift`: Ethereum cryptographic operations
- **ViewModels**: Currently integrated into WalletManager

### Audio Communication Architecture
- **GGWave Integration**: C++ library (`Services/GGWave/`) with Objective-C++ bridge
- **Protocol**: Implements EIP draft specification for sound-based wallet communication
- **Message Flow**: 
  1. Connection establishment via audio handshake
  2. Transaction request received via sound
  3. User approval with biometric authentication
  4. Signed transaction transmitted back via sound

### Security Model
- **Airgapped**: No network connectivity - purely offline operation
- **Keychain Storage**: Private keys stored in iOS Keychain with hardware encryption
- **Biometric Auth**: Face ID/Touch ID required for transaction signing
- **Sound-only Communication**: Prevents remote network-based attacks

## Key Implementation Details

### Wallet Management
- Private key generation and import handled by `WalletManager`
- Secure storage via `KeychainService` using iOS Keychain APIs
- Biometric authentication using `LocalAuthentication` framework

### Audio Protocol Implementation
- Follows EIP draft specification in `EIP-Draft-Sound-Based-Offline-Wallet-Communication.markdown`
- JSON message format with versioning support
- Uses ggwave library for audio encoding/decoding (44.1kHz, audible frequencies)
- Bidirectional communication: connect → tx_request → tx_response

### C++/Objective-C++ Integration
- ggwave library integrated via Objective-C++ bridge (`GGWaveService.h/.mm`)
- Bridging header: `GibberWallet-Bridging-Header.h`
- Audio processing handled in C++ with Swift interface

## Development Notes

### ggwave Integration Status
- Core ggwave C++ files present in `temp/ggwave/` and `Services/GGWave/`
- Integration partially complete - may need additional configuration
- Reed-Solomon error correction included for reliable audio transmission

### File Structure
- Main iOS project: `GibberingWallet/GibberingWallet/`
- Swift source files organized by architectural layer
- C++ audio library in dedicated subdirectory
- Test files separated into unit and UI test targets

### Platform Requirements
- iOS 15.0+ target
- Requires device with microphone and speaker for audio communication
- Biometric authentication capabilities (Face ID/Touch ID) recommended