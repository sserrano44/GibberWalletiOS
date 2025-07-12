//
//  GGWaveService.h
//  GibberWallet
//
//  Created by Claude Code on 2025-07-12.
//  Copyright © 2025 GibberWallet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GGWaveServiceDelegate <NSObject>
@optional
- (void)ggwaveService:(id)service didReceiveMessage:(NSString *)message;
- (void)ggwaveService:(id)service didStartListening:(BOOL)success;
- (void)ggwaveService:(id)service didStopListening:(BOOL)success;
- (void)ggwaveService:(id)service didStartTransmission:(BOOL)success;
- (void)ggwaveService:(id)service didCompleteTransmission:(BOOL)success error:(NSString * _Nullable)error;
- (void)ggwaveService:(id)service audioLevelDidChange:(float)level;
- (void)ggwaveService:(id)service didEncounterError:(NSString *)error;
@end

@interface GGWaveService : NSObject

// Configuration properties
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int payloadLength;
@property (nonatomic, assign) int protocolId;
@property (nonatomic, assign) int volume;

// State properties
@property (nonatomic, assign, readonly) BOOL isInitialized;
@property (nonatomic, assign, readonly) BOOL isListening;
@property (nonatomic, assign, readonly) BOOL isTransmitting;
@property (nonatomic, assign, readonly) float currentAudioLevel;

// Delegate
@property (nonatomic, weak) id<GGWaveServiceDelegate> delegate;

// Lifecycle methods
- (instancetype)initWithDelegate:(id<GGWaveServiceDelegate> _Nullable)delegate;
- (BOOL)initializeWithParameters:(NSDictionary * _Nullable)params;
- (void)cleanup;

// Audio operations
- (BOOL)startListening;
- (BOOL)stopListening;
- (BOOL)transmitMessage:(NSString *)message;

// Audio level monitoring
- (float)getAudioLevel;

@end

NS_ASSUME_NONNULL_END