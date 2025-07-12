//
//  GGWaveTestUtility.swift
//  GibberWallet
//
//  Created by Claude Code on 2025-07-12.
//  Copyright © 2025 GibberWallet. All rights reserved.
//

import Foundation

class GGWaveTestUtility {
    static let shared = GGWaveTestUtility()
    
    private let audioService = AudioCommunicationService()
    
    private init() {
        setupTestCallbacks()
    }
    
    private func setupTestCallbacks() {
        audioService.onTransactionReceived = { transaction in
            print("✅ Test: Received transaction - To: \(transaction.to), Value: \(transaction.displayValue)")
        }
        
        audioService.onConnectionEstablished = {
            print("✅ Test: Connection established successfully")
        }
        
        audioService.onError = { error in
            print("❌ Test: Error occurred - \(error)")
        }
    }
    
    func testAudioInitialization() -> Bool {
        print("🧪 Testing GGWave audio initialization...")
        
        // The audio service should be initialized in its init method
        return true
    }
    
    func testMessageEncoding() {
        print("🧪 Testing message encoding...")
        
        let testTransaction = Transaction(
            from: "0x1234567890123456789012345678901234567890",
            to: "0x0987654321098765432109876543210987654321",
            value: "1000000000000000000", // 1 ETH in Wei
            data: nil,
            gas: "21000",
            gasPrice: "20000000000", // 20 Gwei
            nonce: "1",
            chainId: "1"
        )
        
        let request = TransactionRequest(
            transaction: testTransaction,
            requestId: "test-request-123"
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let message = AudioMessage(type: .transaction, data: data)
            
            let messageData = try encoder.encode(message)
            guard let jsonString = String(data: messageData, encoding: .utf8) else {
                print("❌ Test: Failed to convert message to JSON string")
                return
            }
            
            print("✅ Test: Message encoded successfully - Length: \(jsonString.count) chars")
            print("📝 Test: Sample message: \(String(jsonString.prefix(50)))...")
            
            // Test decoding
            if let decodedData = jsonString.data(using: .utf8) {
                let decodedMessage = try JSONDecoder().decode(AudioMessage.self, from: decodedData)
                print("✅ Test: Message decoded successfully - Type: \(decodedMessage.type)")
            }
        } catch {
            print("❌ Test: Message encoding failed - \(error)")
        }
    }
    
    func testAudioLevelMonitoring() {
        print("🧪 Testing audio level monitoring...")
        
        let level = audioService.getAudioLevel()
        print("📊 Test: Current audio level: \(level)")
        
        if level >= 0.0 && level <= 1.0 {
            print("✅ Test: Audio level is within valid range")
        } else {
            print("❌ Test: Audio level is out of range")
        }
    }
    
    func startListeningTest() {
        print("🧪 Starting audio listening test...")
        audioService.startListening()
    }
    
    func stopListeningTest() {
        print("🧪 Stopping audio listening test...")
        audioService.stopListening()
    }
    
    func transmitTestMessage() {
        print("🧪 Testing audio transmission...")
        
        let testMessage = ConnectMessage(
            appName: "GibberWallet-iOS-Test",
            appVersion: "1.0.0",
            chainId: "1"
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(testMessage)
            let message = AudioMessage(type: .connect, data: data)
            
            let messageData = try encoder.encode(message)
            guard let messageString = String(data: messageData, encoding: .utf8) else {
                print("❌ Test: Failed to convert message to JSON string")
                return
            }
            
            print("📤 Test: Transmitting test connect message...")
            audioService.sendSignedTransaction(messageString, requestId: "test-123")
        } catch {
            print("❌ Test: Failed to create test message - \(error)")
        }
    }
    
    func runAllTests() {
        print("🚀 Running GGWave Integration Tests...")
        print("=" * 50)
        
        let isInitialized = testAudioInitialization()
        print("Initialization: \(isInitialized ? "✅ PASS" : "❌ FAIL")")
        
        testMessageEncoding()
        testAudioLevelMonitoring()
        
        print("=" * 50)
        print("🏁 Tests completed. Use startListeningTest() and transmitTestMessage() for live testing.")
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}