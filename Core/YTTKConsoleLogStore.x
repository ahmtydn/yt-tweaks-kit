#import "YTTKConsoleLogStore.h"
#import "YTTKConstants.h"

#import <dispatch/dispatch.h>
#import <fcntl.h>
#import <unistd.h>

static NSString * const YTTKConsoleLogCaptureKey = @"YTTKConsoleLogCaptureEnabled";
static NSString * const YTTKConsoleLogFileName = @"YTTKConsole.log";
static const NSUInteger YTTKConsoleDisplayMaxCharacters = 12000;

@interface YTTKConsoleLogStore () {
    BOOL _isCapturing;

    int _logFileFD;

    int _originalStdoutFD;
    int _originalStderrFD;

    int _stdoutReadFD;
    int _stderrReadFD;

    dispatch_source_t _stdoutSource;
    dispatch_source_t _stderrSource;

    dispatch_queue_t _captureQueue;
}
@end

@implementation YTTKConsoleLogStore

+ (instancetype)sharedStore {
    static YTTKConsoleLogStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[YTTKConsoleLogStore alloc] init];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _captureQueue = dispatch_queue_create("dev.ahmtydn.yttk.console.capture", DISPATCH_QUEUE_SERIAL);
        _isCapturing = NO;
        _logFileFD = -1;
        _originalStdoutFD = -1;
        _originalStderrFD = -1;
        _stdoutReadFD = -1;
        _stderrReadFD = -1;

        [[NSUserDefaults standardUserDefaults] registerDefaults:@{YTTKConsoleLogCaptureKey: @NO}];
    }
    return self;
}

- (NSString *)logFilePath {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = paths.firstObject ?: NSTemporaryDirectory();
    return [cacheDir stringByAppendingPathComponent:YTTKConsoleLogFileName];
}

- (void)setCaptureEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:YTTKConsoleLogCaptureKey];
}

- (BOOL)isCaptureEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:YTTKConsoleLogCaptureKey];
}

- (void)startCaptureIfNeeded {
    if (_isCapturing || ![self isCaptureEnabled]) {
        return;
    }

    NSString *path = [self logFilePath];
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];

    _logFileFD = open(path.UTF8String, O_WRONLY | O_APPEND);
    if (_logFileFD < 0) {
        return;
    }

    _originalStdoutFD = dup(STDOUT_FILENO);
    _originalStderrFD = dup(STDERR_FILENO);
    if (_originalStdoutFD < 0 || _originalStderrFD < 0) {
        [self stopCaptureIfNeeded];
        return;
    }

    int stdoutPipe[2] = {-1, -1};
    int stderrPipe[2] = {-1, -1};

    if (pipe(stdoutPipe) != 0 || pipe(stderrPipe) != 0) {
        if (stdoutPipe[0] >= 0) close(stdoutPipe[0]);
        if (stdoutPipe[1] >= 0) close(stdoutPipe[1]);
        if (stderrPipe[0] >= 0) close(stderrPipe[0]);
        if (stderrPipe[1] >= 0) close(stderrPipe[1]);
        [self stopCaptureIfNeeded];
        return;
    }

    fflush(stdout);
    fflush(stderr);

    dup2(stdoutPipe[1], STDOUT_FILENO);
    dup2(stderrPipe[1], STDERR_FILENO);

    close(stdoutPipe[1]);
    close(stderrPipe[1]);

    _stdoutReadFD = stdoutPipe[0];
    _stderrReadFD = stderrPipe[0];

    _stdoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _stdoutReadFD, 0, _captureQueue);
    _stderrSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _stderrReadFD, 0, _captureQueue);

    __weak __typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(_stdoutSource, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf consumeReadFD:strongSelf->_stdoutReadFD andMirrorToFD:strongSelf->_originalStdoutFD];
    });

    dispatch_source_set_event_handler(_stderrSource, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf consumeReadFD:strongSelf->_stderrReadFD andMirrorToFD:strongSelf->_originalStderrFD];
    });

    dispatch_resume(_stdoutSource);
    dispatch_resume(_stderrSource);

    _isCapturing = YES;
}

- (void)stopCaptureIfNeeded {
    if (_originalStdoutFD >= 0) {
        dup2(_originalStdoutFD, STDOUT_FILENO);
    }
    if (_originalStderrFD >= 0) {
        dup2(_originalStderrFD, STDERR_FILENO);
    }

    if (_stdoutSource) {
        dispatch_source_cancel(_stdoutSource);
        _stdoutSource = nil;
    }
    if (_stderrSource) {
        dispatch_source_cancel(_stderrSource);
        _stderrSource = nil;
    }

    if (_stdoutReadFD >= 0) {
        close(_stdoutReadFD);
        _stdoutReadFD = -1;
    }
    if (_stderrReadFD >= 0) {
        close(_stderrReadFD);
        _stderrReadFD = -1;
    }

    if (_originalStdoutFD >= 0) {
        close(_originalStdoutFD);
        _originalStdoutFD = -1;
    }
    if (_originalStderrFD >= 0) {
        close(_originalStderrFD);
        _originalStderrFD = -1;
    }

    if (_logFileFD >= 0) {
        close(_logFileFD);
        _logFileFD = -1;
    }

    _isCapturing = NO;
}

- (void)consumeReadFD:(int)readFD andMirrorToFD:(int)mirrorFD {
    if (readFD < 0 || _logFileFD < 0) {
        return;
    }

    char buffer[2048];
    ssize_t bytesRead = read(readFD, buffer, sizeof(buffer));
    if (bytesRead <= 0) {
        return;
    }

    write(_logFileFD, buffer, (size_t)bytesRead);
    if (mirrorFD >= 0) {
        write(mirrorFD, buffer, (size_t)bytesRead);
    }
}

- (NSString *)readLogTextForDisplay {
    NSString *path = [self logFilePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || data.length == 0) {
        return @"";
    }

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: @"";
    }

    if (text.length > YTTKConsoleDisplayMaxCharacters) {
        NSRange suffixRange = NSMakeRange(text.length - YTTKConsoleDisplayMaxCharacters, YTTKConsoleDisplayMaxCharacters);
        text = [text substringWithRange:suffixRange];
    }

    return text;
}

@end
