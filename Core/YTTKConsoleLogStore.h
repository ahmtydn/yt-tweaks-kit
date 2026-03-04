#ifndef YTTKConsoleLogStore_h
#define YTTKConsoleLogStore_h

#import <Foundation/Foundation.h>

@interface YTTKConsoleLogStore : NSObject

+ (instancetype)sharedStore;

- (void)setCaptureEnabled:(BOOL)enabled;
- (BOOL)isCaptureEnabled;

- (void)startCaptureIfNeeded;
- (void)stopCaptureIfNeeded;

- (NSString *)readLogTextForDisplay;

@end

#endif /* YTTKConsoleLogStore_h */
