//
//  GGWaveService.mm
//  GibberWallet
//
//  Created by Claude Code on 2025-07-12.
//  Copyright © 2025 GibberWallet. All rights reserved.
//

#import "GGWaveService.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioQueue.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "ggwave.h"

#define NUM_BUFFERS 3
#define NUM_BYTES_PER_BUFFER 16*1024

// Audio callback prototypes
void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer);

// Audio state structures
typedef struct {
    int ggwaveId;
    bool isCapturing;
    __weak GGWaveService * serviceRef;
    
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} AudioInputState;

typedef struct {
    bool isPlaying;
    int ggwaveId;
    int offset;
    int totalBytes;
    NSMutableData * waveform;
    __weak GGWaveService * serviceRef;
    
    AudioQueueRef queue;
    AudioStreamBasicDescription dataFormat;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
} AudioOutputState;

@interface GGWaveService () {
    // Audio session
    AVAudioSession *audioSession;
    
    // ggwave instances for RX and TX
    ggwave_Instance ggwaveRxInstance;
    ggwave_Instance ggwaveTxInstance;
    
    // Audio state structures
    AudioInputState audioInputState;
    AudioOutputState audioOutputState;
    
    // Audio level monitoring
    float currentAudioLevel;
    NSTimer *audioLevelTimer;
    
    // State management
    BOOL _isInitialized;
    BOOL _isListening;
    BOOL _isTransmitting;
}

@end

@implementation GGWaveService

// Synthesize readonly properties
@synthesize isInitialized = _isInitialized;
@synthesize isListening = _isListening;
@synthesize isTransmitting = _isTransmitting;

#pragma mark - Lifecycle

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<GGWaveServiceDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _isInitialized = NO;
        _isListening = NO;
        _isTransmitting = NO;
        currentAudioLevel = 0.0f;
        
        // Initialize ggwave instances as invalid
        ggwaveRxInstance = -1;
        ggwaveTxInstance = -1;
        
        // Initialize audio state structures
        memset(&audioInputState, 0, sizeof(AudioInputState));
        memset(&audioOutputState, 0, sizeof(AudioOutputState));
        audioInputState.ggwaveId = -1;
        audioOutputState.ggwaveId = -1;
        audioInputState.serviceRef = self;
        audioOutputState.serviceRef = self;
        
        // Set default parameters
        self.sampleRate = 48000;
        self.payloadLength = -1;
        self.protocolId = GGWAVE_PROTOCOL_AUDIBLE_FAST;
        self.volume = 15;
        
        // Initialize audio components
        [self setupAudioSession];
        [self setupNotificationObservers];
    }
    return self;
}

- (void)dealloc {
    [self removeNotificationObservers];
    [self cleanup];
}

#pragma mark - Audio Session Setup

- (void)setupAudioSession {
    audioSession = [AVAudioSession sharedInstance];
    
    NSError *error;
    BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                 withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                                       error:&error];
    
    if (!success) {
        NSLog(@"Failed to set audio session category: %@", error.localizedDescription);
        return;
    }
    
    success = [audioSession setMode:AVAudioSessionModeDefault error:&error];
    if (!success) {
        NSLog(@"Failed to set audio session mode: %@", error.localizedDescription);
        return;
    }
}

- (void)setupNotificationObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Audio session interruption notifications
    [center addObserver:self
               selector:@selector(handleAudioSessionInterruption:)
                   name:AVAudioSessionInterruptionNotification
                 object:audioSession];
    
    // Audio route change notifications
    [center addObserver:self
               selector:@selector(handleAudioSessionRouteChange:)
                   name:AVAudioSessionRouteChangeNotification
                 object:audioSession];
    
    // App lifecycle notifications
    [center addObserver:self
               selector:@selector(handleAppDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(handleAppWillEnterForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
}

- (void)removeNotificationObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Handlers

- (void)handleAudioSessionInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType interruptionType =
        (AVAudioSessionInterruptionType)[notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            NSLog(@"Audio session interruption began");
            if (_isListening) {
                [self stopAudioListening];
                [self.delegate ggwaveService:self didStopListening:YES];
            }
            if (_isTransmitting) {
                [self stopAudioPlayback];
                [self.delegate ggwaveService:self didCompleteTransmission:NO error:@"Interrupted"];
            }
            break;
            
        case AVAudioSessionInterruptionTypeEnded: {
            NSLog(@"Audio session interruption ended");
            AVAudioSessionInterruptionOptions options =
                (AVAudioSessionInterruptionOptions)[notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
            
            if (options & AVAudioSessionInterruptionOptionShouldResume) {
                NSLog(@"Audio session can resume");
            }
            break;
        }
    }
}

- (void)handleAudioSessionRouteChange:(NSNotification *)notification {
    AVAudioSessionRouteChangeReason reason =
        (AVAudioSessionRouteChangeReason)[notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"Audio route changed: %ld", (long)reason);
            break;
        default:
            break;
    }
}

- (void)handleAppDidEnterBackground:(NSNotification *)notification {
    NSLog(@"App entering background - pausing audio operations");
    
    if (_isListening) {
        [self stopAudioListening];
        [self.delegate ggwaveService:self didStopListening:YES];
    }
    
    if (_isTransmitting) {
        [self stopAudioPlayback];
        [self.delegate ggwaveService:self didCompleteTransmission:NO error:@"Backgrounded"];
    }
}

- (void)handleAppWillEnterForeground:(NSNotification *)notification {
    NSLog(@"App entering foreground - audio operations can resume");
}

#pragma mark - Public API

- (BOOL)initializeWithParameters:(NSDictionary *)params {
    if (_isInitialized) {
        return YES;
    }
    
    // Update parameters
    if (params[@"sampleRate"]) {
        self.sampleRate = [params[@"sampleRate"] intValue];
    }
    if (params[@"payloadLength"]) {
        self.payloadLength = [params[@"payloadLength"] intValue];
    }
    if (params[@"protocolId"]) {
        self.protocolId = [params[@"protocolId"] intValue];
    }
    if (params[@"volume"]) {
        self.volume = [params[@"volume"] intValue];
    }
    
    BOOL success = [self initializeGGWave];
    
    if (success) {
        _isInitialized = YES;
    }
    
    return success;
}

- (BOOL)startListening {
    if (!_isInitialized) {
        [self.delegate ggwaveService:self didEncounterError:@"GGWave not initialized"];
        return NO;
    }
    
    if (_isListening) {
        return YES;
    }
    
    BOOL success = [self startAudioListening];
    
    if (success) {
        _isListening = YES;
        [self.delegate ggwaveService:self didStartListening:YES];
    } else {
        [self.delegate ggwaveService:self didStartListening:NO];
    }
    
    return success;
}

- (BOOL)stopListening {
    if (!_isListening) {
        return YES;
    }
    
    BOOL success = [self stopAudioListening];
    
    if (success) {
        _isListening = NO;
        [self.delegate ggwaveService:self didStopListening:YES];
    } else {
        [self.delegate ggwaveService:self didStopListening:NO];
    }
    
    return success;
}

- (BOOL)transmitMessage:(NSString *)message {
    if (!_isInitialized) {
        [self.delegate ggwaveService:self didEncounterError:@"GGWave not initialized"];
        return NO;
    }
    
    if (_isTransmitting) {
        [self.delegate ggwaveService:self didEncounterError:@"Already transmitting"];
        return NO;
    }
    
    [self.delegate ggwaveService:self didStartTransmission:YES];
    _isTransmitting = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = [self transmitAudioMessage:message];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_isTransmitting = NO;
            [self.delegate ggwaveService:self didCompleteTransmission:success error:success ? nil : @"Transmission failed"];
        });
    });
    
    return YES;
}

- (float)getAudioLevel {
    return currentAudioLevel;
}

- (float)currentAudioLevel {
    return currentAudioLevel;
}

- (void)cleanup {
    [audioLevelTimer invalidate];
    audioLevelTimer = nil;
    
    if (_isListening) {
        [self stopAudioListening];
    }
    
    if (_isTransmitting) {
        [self stopAudioPlayback];
    }
    
    // Cleanup ggwave instances
    if (ggwaveRxInstance >= 0) {
        ggwave_free(ggwaveRxInstance);
        ggwaveRxInstance = -1;
        audioInputState.ggwaveId = -1;
    }
    
    if (ggwaveTxInstance >= 0) {
        ggwave_free(ggwaveTxInstance);
        ggwaveTxInstance = -1;
        audioOutputState.ggwaveId = -1;
    }
    
    _isInitialized = NO;
    _isListening = NO;
    _isTransmitting = NO;
}

#pragma mark - Private Implementation

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format {
    format->mSampleRate = self.sampleRate;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFramesPerPacket = 1;
    format->mChannelsPerFrame = 1;
    format->mBytesPerFrame = 2;
    format->mBytesPerPacket = 2;
    format->mBitsPerChannel = 16;
    format->mReserved = 0;
    format->mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
}

- (BOOL)initializeGGWave {
    NSLog(@"Initializing GGWave with sampleRate: %d, protocolId: %d, volume: %d",
          self.sampleRate, self.protocolId, self.volume);
    
    // Setup audio formats
    [self setupAudioFormat:&audioInputState.dataFormat];
    [self setupAudioFormat:&audioOutputState.dataFormat];
    
    // Initialize ggwave instances
    
    // RX (Receive) instance
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();
        parameters.sampleRateInp = audioInputState.dataFormat.mSampleRate;
        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.operatingMode = GGWAVE_OPERATING_MODE_RX;
        
        ggwaveRxInstance = ggwave_init(parameters);
        audioInputState.ggwaveId = ggwaveRxInstance;
        
        if (ggwaveRxInstance < 0) {
            NSLog(@"Failed to initialize ggwave RX instance");
            return NO;
        }
        
        NSLog(@"GGWave RX instance initialized - id: %d", ggwaveRxInstance);
    }
    
    // TX (Transmit) instance
    {
        ggwave_Parameters parameters = ggwave_getDefaultParameters();
        parameters.sampleRateOut = audioOutputState.dataFormat.mSampleRate;
        parameters.sampleFormatInp = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.sampleFormatOut = GGWAVE_SAMPLE_FORMAT_I16;
        parameters.operatingMode = GGWAVE_OPERATING_MODE_TX;
        
        ggwaveTxInstance = ggwave_init(parameters);
        audioOutputState.ggwaveId = ggwaveTxInstance;
        
        if (ggwaveTxInstance < 0) {
            NSLog(@"Failed to initialize ggwave TX instance");
            return NO;
        }
        
        NSLog(@"GGWave TX instance initialized - id: %d", ggwaveTxInstance);
    }
    
    // Start audio level monitoring
    [self startAudioLevelMonitoring];
    
    return YES;
}

- (BOOL)startAudioListening {
    NSLog(@"Starting audio listening");
    
    if (audioInputState.isCapturing) {
        NSLog(@"Already capturing audio");
        return YES;
    }
    
    // Check microphone permission
    // Use AVAudioSession API (suppress deprecation warning for iOS 17+)
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    AVAudioSessionRecordPermission permission = [audioSession recordPermission];
    if (permission == AVAudioSessionRecordPermissionDenied) {
        NSLog(@"Microphone permission denied");
        [self.delegate ggwaveService:self didEncounterError:@"Microphone permission denied"];
        return NO;
    }
    
    if (permission == AVAudioSessionRecordPermissionUndetermined) {
        // Request permission
        [audioSession requestRecordPermission:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self startAudioListening];
                });
            } else {
                NSLog(@"Microphone permission denied by user");
                [self.delegate ggwaveService:self didEncounterError:@"Microphone permission denied"];
            }
        }];
        return NO;
    }
    
    #pragma clang diagnostic pop
    
    // Activate audio session
    NSError *error;
    BOOL success = [audioSession setActive:YES error:&error];
    if (!success) {
        NSLog(@"Failed to activate audio session: %@", error.localizedDescription);
        return NO;
    }
    
    // Create audio queue for input
    OSStatus status = AudioQueueNewInput(&audioInputState.dataFormat,
                                         AudioInputCallback,
                                         &audioInputState,
                                         NULL,
                                         kCFRunLoopCommonModes,
                                         0,
                                         &audioInputState.queue);
    
    if (status != noErr) {
        NSLog(@"Failed to create audio input queue: %d", (int)status);
        return NO;
    }
    
    // Allocate and enqueue buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(audioInputState.queue, NUM_BYTES_PER_BUFFER, &audioInputState.buffers[i]);
        AudioQueueEnqueueBuffer(audioInputState.queue, audioInputState.buffers[i], 0, NULL);
    }
    
    // Start the audio queue
    audioInputState.isCapturing = true;
    status = AudioQueueStart(audioInputState.queue, NULL);
    
    if (status != noErr) {
        NSLog(@"Failed to start audio queue: %d", (int)status);
        [self stopAudioListening];
        return NO;
    }
    
    NSLog(@"Audio listening started successfully");
    return YES;
}

- (BOOL)stopAudioListening {
    NSLog(@"Stopping audio listening");
    
    if (!audioInputState.isCapturing) {
        NSLog(@"Not currently capturing audio");
        return YES;
    }
    
    audioInputState.isCapturing = false;
    
    // Stop the audio queue
    AudioQueueStop(audioInputState.queue, true);
    
    // Free buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(audioInputState.queue, audioInputState.buffers[i]);
    }
    
    // Dispose of the audio queue
    AudioQueueDispose(audioInputState.queue, true);
    
    NSLog(@"Audio listening stopped successfully");
    return YES;
}

- (BOOL)transmitAudioMessage:(NSString *)message {
    NSLog(@"Transmitting message: %@", message);
    
    if (ggwaveTxInstance < 0) {
        NSLog(@"TX instance not initialized");
        return NO;
    }
    
    if (audioOutputState.isPlaying) {
        NSLog(@"Already playing audio");
        return NO;
    }
    
    // Convert NSString to C string
    const char *messageBytes = [message UTF8String];
    int messageLength = (int)strlen(messageBytes);
    
    // Query the required waveform size
    int waveformSize = ggwave_encode(ggwaveTxInstance, messageBytes, messageLength,
                                     (ggwave_ProtocolId)self.protocolId, self.volume, NULL, 1);
    
    if (waveformSize <= 0) {
        NSLog(@"Failed to query waveform size: %d", waveformSize);
        return NO;
    }
    
    // Create mutable data for waveform
    audioOutputState.waveform = [NSMutableData dataWithLength:waveformSize];
    
    // Generate the waveform
    int actualSize = ggwave_encode(ggwaveTxInstance, messageBytes, messageLength,
                                   (ggwave_ProtocolId)self.protocolId, self.volume, [audioOutputState.waveform mutableBytes], 0);
    
    if (actualSize <= 0) {
        NSLog(@"Failed to encode message: %d", actualSize);
        return NO;
    }
    
    // Setup for playback
    audioOutputState.offset = 0;
    audioOutputState.totalBytes = actualSize;
    
    // Create audio queue for output
    OSStatus status = AudioQueueNewOutput(&audioOutputState.dataFormat,
                                          AudioOutputCallback,
                                          &audioOutputState,
                                          NULL,
                                          kCFRunLoopCommonModes,
                                          0,
                                          &audioOutputState.queue);
    
    if (status != noErr) {
        NSLog(@"Failed to create audio output queue: %d", (int)status);
        return NO;
    }
    
    // Setup buffers and start playback
    audioOutputState.isPlaying = true;
    for (int i = 0; i < NUM_BUFFERS && audioOutputState.isPlaying; i++) {
        AudioQueueAllocateBuffer(audioOutputState.queue, NUM_BYTES_PER_BUFFER, &audioOutputState.buffers[i]);
        AudioOutputCallback(&audioOutputState, audioOutputState.queue, audioOutputState.buffers[i]);
    }
    
    // Start the audio queue
    status = AudioQueueStart(audioOutputState.queue, NULL);
    if (status != noErr) {
        NSLog(@"Failed to start audio output queue: %d", (int)status);
        [self stopAudioPlayback];
        return NO;
    }
    
    NSLog(@"Audio transmission started successfully");
    return YES;
}

- (void)stopAudioPlayback {
    NSLog(@"Stopping audio playback");
    
    if (!audioOutputState.isPlaying) {
        return;
    }
    
    audioOutputState.isPlaying = false;
    
    // Stop the audio queue
    AudioQueueStop(audioOutputState.queue, true);
    
    // Free buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(audioOutputState.queue, audioOutputState.buffers[i]);
    }
    
    // Dispose of the audio queue
    AudioQueueDispose(audioOutputState.queue, true);
    
    // Clear waveform data
    audioOutputState.waveform = nil;
    audioOutputState.offset = 0;
    audioOutputState.totalBytes = 0;
    
    NSLog(@"Audio playback stopped successfully");
}

- (void)startAudioLevelMonitoring {
    audioLevelTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       target:self
                                                     selector:@selector(updateAudioLevel)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)updateAudioLevel {
    // This is a placeholder implementation.
    // A more accurate implementation would involve analyzing the audio buffer.
    currentAudioLevel = arc4random_uniform(100) / 100.0f;
    
    [self.delegate ggwaveService:self audioLevelDidChange:currentAudioLevel];
}

@end

//
// Audio Callback Implementations
//

void AudioInputCallback(void * inUserData,
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs)
{
    AudioInputState * state = (AudioInputState*)inUserData;
    
    if (!state->isCapturing) {
        return;
    }
    
    char decoded[256];
    
    // Analyze captured audio using ggwave
    int ret = ggwave_ndecode(state->ggwaveId, (char *)inBuffer->mAudioData, inBuffer->mAudioDataByteSize, decoded, 256);
    
    // Check if a message has been received
    if (ret > 0) {
        decoded[ret] = 0; // null terminate the string
        
        // Send delegate callback for received message
        GGWaveService * service = state->serviceRef;
        if (service && service.delegate) {
            NSString *receivedMessage = [NSString stringWithUTF8String:decoded];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [service.delegate ggwaveService:service didReceiveMessage:receivedMessage];
            });
            
            NSLog(@"Received message: %@", receivedMessage);
        }
    }
    
    // Put the buffer back in the queue
    AudioQueueEnqueueBuffer(state->queue, inBuffer, 0, NULL);
}

void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer)
{
    AudioOutputState* state = (AudioOutputState*)inUserData;
    
    if (!state->isPlaying) {
        return;
    }
    
    int nRemainingBytes = state->totalBytes - state->offset;
    
    // Check if there is any audio left to play
    if (nRemainingBytes > 0) {
        int nBytesToPush = MIN(nRemainingBytes, NUM_BYTES_PER_BUFFER);
        
        memcpy(outBuffer->mAudioData, (char*)[state->waveform mutableBytes] + state->offset, nBytesToPush);
        outBuffer->mAudioDataByteSize = nBytesToPush;
        
        OSStatus status = AudioQueueEnqueueBuffer(state->queue, outBuffer, 0, NULL);
        if (status != noErr) {
            NSLog(@"Failed to enqueue audio data: %d", (int)status);
        }
        
        state->offset += nBytesToPush;
    } else {
        // No audio left - stop playback
        if (state->isPlaying) {
            AudioQueueStop(state->queue, false);
            state->isPlaying = false;
            
            // Send delegate callback for transmission completed
            GGWaveService * service = state->serviceRef;
            if (service && service.delegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [service.delegate ggwaveService:service didCompleteTransmission:YES error:nil];
                });
            }
        }
        
        AudioQueueFreeBuffer(state->queue, outBuffer);
    }
}