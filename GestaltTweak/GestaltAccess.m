//
//  GestaltAccess.m
//  GestaltTweak
//
//  bad_query path traversal (iOS 26 / 27):
//       class 13, MobileGestalt SystemGroup, part 3, target absolute path,
//       flags 0x8000000000; directly consumes the sandbox token
//
//  Licensed under the MIT License. Portions derived from frs0n/GestaltEdit.
//

#import "GestaltAccess.h"
#import "BadQueryBridge.h"
#import "GestaltTweak-Swift.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

static NSString * const kMobileGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";
static NSString * const kBadQueryMobileGestaltCacheDirectory =
    @"/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestalttweak.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

static BOOL GestaltCanOpenReadWrite(NSString *path)
{
    int fd = open(path.fileSystemRepresentation,
                  O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

static BOOL GestaltWriteAll(int fd, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess
{
    BadQueryLease *_activeBadQueryLease;
    NSString *_lastMethod;
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

+ (NSString *)currentOSBuild
{
    size_t length = 0;
    if (sysctlbyname("kern.osversion", NULL, &length, NULL, 0) != 0 ||
        length == 0) {
        return @"";
    }

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("kern.osversion", data.mutableBytes, &length, NULL, 0) != 0)
        return @"";

    return [NSString stringWithUTF8String:data.bytes] ?: @"";
}

+ (BOOL)isRunningSupportedOS
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *build = self.currentOSBuild;

    return version.majorVersion == 27 && (
        [build isEqualToString:@"24A5355q"] || // iOS / iPadOS 27 beta 1
        [build isEqualToString:@"24A5370h"] || // iOS / iPadOS 27 beta 2
        [build isEqualToString:@"24A5380h"] || // iOS / iPadOS 27 beta 3
        [build isEqualToString:@"24A5380i"] || // iPadOS 27 beta 3 v2
        [build isEqualToString:@"24A5380l"] || // iOS / iPadOS 27 Public Beta 1 (revised beta 3)
        [build isEqualToString:@"24A5390f"]    // iOS / iPadOS 27 beta 4
    );
}

/// The selected exploit method, read from UserDefaults ("bad_query" or "cmg").
+ (NSString *)currentMethod
{
    NSString *method = [[NSUserDefaults standardUserDefaults] stringForKey:@"method"];
    return method.length > 0 ? method : @"bad_query";
}

/// Whether the current plist writes should be done in-place on the same inode.
/// Mirrors mond's "Persist after reboot" toggle: ON (default) writes in-place
/// to try to survive a reboot; OFF uses atomic file replacement instead.
+ (BOOL)writesInPlace
{
    NSNumber *setting = [[NSUserDefaults standardUserDefaults] objectForKey:@"atomic_write"];
    return setting ? setting.boolValue : YES;
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    if (!GestaltAccess.isRunningSupportedOS) {
        if (error) *error = GestaltError(0,
            @"GestaltTweak currently supports only iOS and iPadOS 27 beta 1 through beta 4.");
        return NO;
    }

    NSString *method = GestaltAccess.currentMethod;
    BOOL usesCmg = [method isEqualToString:@"cmg"];

    if (![_lastMethod isEqualToString:method]) {
        [_activeBadQueryLease invalidate];
        _activeBadQueryLease = nil;
        self.isConnected = NO;
        self.plistPath = nil;
        _lastMethod = [method copy];
    }

    if (self.isConnected) {
        if (error) *error = nil;
        return YES;
    }

    NSString *plistPath = [kMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];

    if (usesCmg) {
        if ([CmgExploit run] < 0) {
            if (error) *error = GestaltError(2,
                @"cmg exploit failed (unsupported build or the ContainerManager API is unavailable).");
            return NO;
        }
        if (!GestaltCanOpenReadWrite(plistPath)) {
            if (error) *error = GestaltError(3,
                @"cmg acquired a sandbox extension, but the MobileGestalt plist is not writable.");
            return NO;
        }

        self.plistPath = plistPath;
        self.isConnected = YES;
        if (error) *error = nil;
        return YES;
    }

    if (!BadQueryBridgeAvailable()) {
        if (error) *error = GestaltError(1,
            @"bad_query is unavailable (required ContainerManager or sandbox extension APIs are missing).");
        return NO;
    }

    [_activeBadQueryLease invalidate];
    _activeBadQueryLease = nil;
    self.isConnected = NO;
    self.plistPath = nil;

    NSString *badQueryTarget = [kBadQueryMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryDetail = nil;
    BadQueryLease *badQueryLease = [BadQueryLease leaseForPath:badQueryTarget
                                                        error:&badQueryDetail];
    if (!badQueryLease) {
        if (error) *error = GestaltError(2,
            badQueryDetail ?: @"bad_query failed.");
        return NO;
    }
    if (!GestaltCanOpenReadWrite(plistPath)) {
        [badQueryLease invalidate];
        if (error) *error = GestaltError(3,
            @"bad_query acquired a sandbox extension, but the MobileGestalt plist is not writable.");
        return NO;
    }

    _activeBadQueryLease = badQueryLease;
    self.isConnected = YES;
    self.plistPath = plistPath;
    if (error) *error = nil;
    return YES;
}

#pragma mark - Read / Write

- (NSData *)readGestaltDataWithError:(NSError **)error
{
    if (![self connectWithError:error]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
        if (error) *error = GestaltError(3,
            [NSString stringWithFormat:@"The plist does not exist: %@", self.plistPath]);
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(4, @"Failed to read the plist.");
        return nil;
    }
    if (error) *error = nil;
    return data;
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(5,
            @"The plist top level is not a dictionary.");
        return nil;
    }
    self.lastReadFormat = format;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    if (![self connectWithError:error]) return NO;
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(6, @"The content to save is not a dictionary.");
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 &&
        format != NSPropertyListBinaryFormat_v1_0)
        format = NSPropertyListBinaryFormat_v1_0;

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:format
                                                             options:0
                                                               error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(7, @"Failed to serialize the plist.");
        return NO;
    }

    NSString *targetPath = self.plistPath;
    NSError *readError = nil;
    NSData *original = [NSData dataWithContentsOfFile:targetPath
                                              options:0
                                                error:&readError];
    if (!original) {
        if (error) *error = readError ?: GestaltError(8, @"Failed to read the original plist.");
        return NO;
    }

    if (GestaltAccess.writesInPlace) {
        int fd = open(targetPath.fileSystemRepresentation,
                      O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
        if (fd < 0) {
            if (error) *error = GestaltError(9,
                [NSString stringWithFormat:@"Failed to open the plist (errno=%d).", errno]);
            return NO;
        }

        BOOL wrote = ftruncate(fd, 0) == 0 &&
            lseek(fd, 0, SEEK_SET) == 0 &&
            GestaltWriteAll(fd, data) &&
            fsync(fd) == 0;
        int writeErrno = errno;

        if (!wrote) {
            ftruncate(fd, 0);
            lseek(fd, 0, SEEK_SET);
            GestaltWriteAll(fd, original);
            fsync(fd);
            close(fd);
            if (error) *error = GestaltError(10,
                [NSString stringWithFormat:@"Failed to write the plist (errno=%d).", writeErrno]);
            return NO;
        }
        close(fd);
    } else {
        NSString *directory = [targetPath stringByDeletingLastPathComponent];
        NSString *tempPath = [NSString stringWithFormat:@"%@/.%@.%@.tmp",
            directory, [targetPath lastPathComponent], [NSUUID UUID].UUIDString];

        NSError *tempError = nil;
        if (![data writeToFile:tempPath
                       options:NSDataWritingWithoutOverwriting
                         error:&tempError]) {
            if (error) *error = tempError ?: GestaltError(10,
                @"Failed to write the temporary plist.");
            return NO;
        }

        NSError *replaceError = nil;
        if (![[NSFileManager defaultManager] replaceItemAtURL:
                [NSURL fileURLWithPath:targetPath]
                                                withItemAtURL:
                [NSURL fileURLWithPath:tempPath]
                                               backupItemName:nil
                                                      options:0
                                             resultingItemURL:NULL
                                                        error:&replaceError]) {
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            if (error) *error = replaceError ?: GestaltError(10,
                @"Failed to replace the plist.");
            return NO;
        }
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
    }

    NSData *verification = [NSData dataWithContentsOfFile:targetPath];
    if (![verification isEqualToData:data]) {
        if (error) *error = GestaltError(11, @"Post-write verification failed.");
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

@end