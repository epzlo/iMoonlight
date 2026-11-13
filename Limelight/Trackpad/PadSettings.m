//
//  PadSettings.m
//  iMoonlight
//

#import "PadSettings.h"
#import <Network/Network.h>

NSString* const PadKeySensitivity = @"pad.sensitivity";
NSString* const PadKeyAcceleration = @"pad.acceleration";
NSString* const PadKeyScrollSpeed = @"pad.scrollSpeed";
NSString* const PadKeyInvertScroll = @"pad.invertScroll";
NSString* const PadKeyZoomSpeed = @"pad.zoomSpeed";
NSString* const PadKeySwapScreens = @"pad.swapScreens";
NSString* const PadKeyDimWhenIdle = @"pad.dimWhenIdle";
NSString* const PadKeyAutocorrect = @"pad.autocorrect";
NSString* const PadKeyTypeOnRelease = @"pad.typeOnRelease";
NSString* const PadKeyAutoCapitalize = @"pad.autoCapitalize";
NSString* const PadKeyDoubleSpacePeriod = @"pad.doubleSpacePeriod";

NSString* const PadKeyShowHints = @"pad.showHints";
NSString* const PadKeyPortuguese = @"pad.portuguese";
NSString* const PadKeyDeadKeys = @"pad.deadKeys";
NSString* const PadKeyVideoShare = @"pad.videoShare";
NSString* const PadKeyShortcuts = @"lpz.shortcuts";
NSString* const PadKeyCursorMarker = @"lpz.cursorMarker";
NSString* const PadKeyNetworkProfile = @"lpz.networkProfile";
NSString* const PadKeyAutoReconnect = @"lpz.autoReconnect";

NSString* const PadSettingsChangedNotification = @"PadSettingsChangedNotification";

@implementation PadSettings

+ (void)initialize {
    if (self == [PadSettings class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            PadKeySensitivity: @1.8f,
            PadKeyAcceleration: @0.6f,
            PadKeyScrollSpeed: @2.0f,
            PadKeyInvertScroll: @NO,
            PadKeyZoomSpeed: @1.0f,
            PadKeySwapScreens: @NO,
            PadKeyDimWhenIdle: @YES,
            PadKeyAutocorrect: @YES,
            PadKeyTypeOnRelease: @NO,
            PadKeyAutoCapitalize: @YES,
            PadKeyDoubleSpacePeriod: @YES,
            PadKeyShowHints: @NO,
            PadKeyPortuguese: @YES,
            PadKeyDeadKeys: @YES,
            PadKeyVideoShare: @0.0f,
            PadKeyShortcuts: @"Konsole = Ctrl+Alt+T\nArquivos = Super+E\nBloquear = Super+L",
            PadKeyCursorMarker: @YES,
            PadKeyNetworkProfile: @0,
            PadKeyAutoReconnect: @YES,
        }];
    }
}

+ (float)sensitivity { return [self floatForKey:PadKeySensitivity]; }
+ (float)acceleration { return [self floatForKey:PadKeyAcceleration]; }
+ (float)scrollSpeed { return [self floatForKey:PadKeyScrollSpeed]; }
+ (float)zoomSpeed { return [self floatForKey:PadKeyZoomSpeed]; }
+ (BOOL)invertScroll { return [self boolForKey:PadKeyInvertScroll]; }
+ (BOOL)swapScreens { return [self boolForKey:PadKeySwapScreens]; }
+ (BOOL)dimWhenIdle { return [self boolForKey:PadKeyDimWhenIdle]; }
+ (BOOL)autocorrect { return [self boolForKey:PadKeyAutocorrect]; }
+ (BOOL)typeOnRelease { return [self boolForKey:PadKeyTypeOnRelease]; }
+ (BOOL)autoCapitalize { return [self boolForKey:PadKeyAutoCapitalize]; }
+ (BOOL)doubleSpacePeriod { return [self boolForKey:PadKeyDoubleSpacePeriod]; }

+ (BOOL)showHints { return [self boolForKey:PadKeyShowHints]; }
+ (BOOL)portuguese { return [self boolForKey:PadKeyPortuguese]; }
+ (BOOL)deadKeys { return [self boolForKey:PadKeyDeadKeys]; }
+ (float)videoShare { return [self floatForKey:PadKeyVideoShare]; }
+ (NSString*)shortcuts { return [[NSUserDefaults standardUserDefaults] stringForKey:PadKeyShortcuts] ?: @""; }
+ (void)setShortcuts:(NSString*)text {
    [[NSUserDefaults standardUserDefaults] setObject:text forKey:PadKeyShortcuts];
    [[NSNotificationCenter defaultCenter] postNotificationName:PadSettingsChangedNotification object:nil];
}
+ (BOOL)cursorMarker { return [self boolForKey:PadKeyCursorMarker]; }
+ (PadNetworkProfile)networkProfile { return (PadNetworkProfile)[self integerForKey:PadKeyNetworkProfile fallback:0]; }
+ (BOOL)autoReconnect { return [self boolForKey:PadKeyAutoReconnect]; }

static nw_path_monitor_t lpzMonitor;
static volatile BOOL lpzCellular;

+ (void)startNetworkWatch {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lpzMonitor = nw_path_monitor_create();
        nw_path_monitor_set_queue(lpzMonitor, dispatch_get_main_queue());
        nw_path_monitor_set_update_handler(lpzMonitor, ^(nw_path_t path) {
            // Com a Tailscale ligada o caminho passa por um túnel; o que importa é a interface por baixo.
            BOOL wifi = nw_path_uses_interface_type(path, nw_interface_type_wifi) ||
                        nw_path_uses_interface_type(path, nw_interface_type_wired);
            lpzCellular = !wifi && nw_path_uses_interface_type(path, nw_interface_type_cellular);
        });
        nw_path_monitor_start(lpzMonitor);
    });
}

+ (BOOL)onCellular {
    [self startNetworkWatch];
    return lpzCellular;
}

+ (BOOL)useSaverQuality {
    PadNetworkProfile p = [self networkProfile];
    return p == PadNetworkSaver || (p == PadNetworkAuto && [self onCellular]);
}

+ (void)setNetworkProfile:(PadNetworkProfile)profile {
    [self setInteger:profile forKey:PadKeyNetworkProfile];
}

+ (float)floatForKey:(NSString*)key {
    return [[NSUserDefaults standardUserDefaults] floatForKey:key];
}

+ (void)setFloat:(float)value forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:PadSettingsChangedNotification object:nil];
}

+ (BOOL)boolForKey:(NSString*)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

+ (void)setBool:(BOOL)value forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:PadSettingsChangedNotification object:nil];
}

+ (NSInteger)integerForKey:(NSString*)key fallback:(NSInteger)fallback {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return value != nil ? [value integerValue] : fallback;
}

+ (void)setInteger:(NSInteger)value forKey:(NSString*)key {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:PadSettingsChangedNotification object:nil];
}

@end
