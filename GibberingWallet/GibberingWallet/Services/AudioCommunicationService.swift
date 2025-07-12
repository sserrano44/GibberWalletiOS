import Foundation
import AVFoundation
import Combine

class AudioCommunicationService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var audioLevel: Float = 0.0
    
    var onTransactionReceived: ((Transaction) -> Void)?
    var onConnectionEstablished: (() -> Void)?
    var onError: ((String) -> Void)?
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // GGWave service for audio communication
    private var ggwaveService: GGWaveService?
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
    }
    
    override init() {
        super.init()
        setupGGWave()
    }
    
    private func setupGGWave() {
        ggwaveService = GGWaveService(delegate: self)
        
        // Initialize with default parameters
        let params: [String: Any] = [
            "sampleRate": 48000,
            "protocolId": 1, // GGWAVE_PROTOCOL_AUDIBLE_FAST
            "volume": 15,
            "payloadLength": -1 // Variable length
        ]
        
        let success = ggwaveService?.initialize(withParameters: params) ?? false
        if !success {
            print("Failed to initialize GGWave service")
            onError?("Failed to initialize audio communication")
        }
    }
    
    func startListening() {
        guard let ggwaveService = ggwaveService else {
            onError?("GGWave service not initialized")
            return
        }
        
        connectionStatus = .connecting
        
        let success = ggwaveService.startListening()
        if success {
            isListening = true
        } else {
            connectionStatus = .disconnected
            onError?("Failed to start listening")
        }
    }
    
    func stopListening() {
        guard let ggwaveService = ggwaveService else { return }
        
        let success = ggwaveService.stopListening()
        if success {
            isListening = false
            connectionStatus = .disconnected
        }
    }
    
    // Audio level monitoring
    func getAudioLevel() -> Float {
        return ggwaveService?.currentAudioLevel ?? 0.0
    }
    
    func sendSignedTransaction(_ signedTx: String, requestId: String) {
        let response = SignedTransactionResponse(
            signedTransaction: signedTx,
            requestId: requestId
        )
        
        do {
            let data = try encoder.encode(response)
            let message = AudioMessage(type: .signedTransaction, data: data)
            sendAudioMessage(message)
        } catch {
            print("Failed to encode response: \(error)")
            onError?("Failed to encode transaction response")
        }
    }
    
    func sendError(_ message: String, code: String) {
        let errorMsg = ErrorMessage(message: message, code: code)
        
        do {
            let data = try encoder.encode(errorMsg)
            let audioMessage = AudioMessage(type: .error, data: data)
            sendAudioMessage(audioMessage)
        } catch {
            print("Failed to encode error: \(error)")
            onError?("Failed to encode error message")
        }
    }
    
    private func sendAudioMessage(_ message: AudioMessage) {
        guard let ggwaveService = ggwaveService else {
            onError?("GGWave service not initialized")
            return
        }
        
        do {
            let messageData = try encoder.encode(message)
            // Convert to JSON string directly, matching Node implementation
            guard let messageString = String(data: messageData, encoding: .utf8) else {
                onError?("Failed to convert message to JSON string")
                return
            }
            
            let success = ggwaveService.transmitMessage(messageString)
            if !success {
                onError?("Failed to transmit audio message")
            }
        } catch {
            print("Failed to encode message: \(error)")
            onError?("Failed to encode audio message")
        }
    }
    
    private func handleReceivedMessage(_ data: Data) {
        do {
            let message = try decoder.decode(AudioMessage.self, from: data)
            
            switch message.type {
            case .connect:
                let connectMsg = try decoder.decode(ConnectMessage.self, from: message.data)
                handleConnection(connectMsg)
                
            case .transaction:
                let transactionRequest = try decoder.decode(TransactionRequest.self, from: message.data)
                onTransactionReceived?(transactionRequest.transaction)
                
            default:
                print("Unexpected message type: \(message.type)")
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func handleConnection(_ message: ConnectMessage) {
        connectionStatus = .connected
        onConnectionEstablished?()
        print("Connected to \(message.appName) v\(message.appVersion) on chain \(message.chainId)")
    }
}

// MARK: - GGWaveServiceDelegate

extension AudioCommunicationService: GGWaveServiceDelegate {
    func ggwaveService(_ service: Any, didReceiveMessage message: String) {
        // Parse JSON string directly, matching Node implementation
        guard let messageData = message.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return
        }
        
        handleReceivedMessage(messageData)
    }
    
    func ggwaveService(_ service: Any, didStartListening success: Bool) {
        DispatchQueue.main.async {
            if success {
                self.connectionStatus = .connecting
            } else {
                self.connectionStatus = .disconnected
                self.isListening = false
                self.onError?("Failed to start listening")
            }
        }
    }
    
    func ggwaveService(_ service: Any, didStopListening success: Bool) {
        DispatchQueue.main.async {
            self.isListening = false
            self.connectionStatus = .disconnected
        }
    }
    
    func ggwaveService(_ service: Any, didStartTransmission success: Bool) {
        if !success {
            onError?("Failed to start transmission")
        }
    }
    
    func ggwaveService(_ service: Any, didCompleteTransmission success: Bool, error: String?) {
        if !success {
            onError?(error ?? "Transmission failed")
        }
    }
    
    func ggwaveService(_ service: Any, audioLevelDidChange level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    func ggwaveService(_ service: Any, didEncounterError error: String) {
        DispatchQueue.main.async {
            self.onError?(error)
        }
    }
}