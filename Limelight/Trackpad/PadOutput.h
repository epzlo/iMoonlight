//
//  PadOutput.h
//  iMoonlight
//
//  Sends trackpad gestures and keyboard keys to the PC as mouse and keyboard input,
//  through moonlight-common-c.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// Windows virtual-key codes, which is what Moonlight hosts expect.
enum {
    PadVkBackspace = 0x08,
    PadVkTab = 0x09,
    PadVkEnter = 0x0D,
    PadVkEscape = 0x1B,
    PadVkSpace = 0x20,
    PadVkPageUp = 0x21,
    PadVkPageDown = 0x22,
    PadVkEnd = 0x23,
    PadVkHome = 0x24,
    PadVkLeft = 0x25,
    PadVkUp = 0x26,
    PadVkRight = 0x27,
    PadVkDown = 0x28,
    PadVkPrintScreen = 0x2C,
    PadVkDelete = 0x2E,
    PadVkA = 0x41,
    PadVkC = 0x43,
    PadVkD = 0x44,
    PadVkL = 0x4C,
    PadVkN = 0x4E,
    PadVkQ = 0x51,
    PadVkT = 0x54,
    PadVkV = 0x56,
    PadVkW = 0x57,
    PadVkX = 0x58,
    PadVkZ = 0x5A,
    /// Super / Meta no Linux (a tecla Windows).
    PadVkWin = 0x5B,
    PadVkF1 = 0x70,
    PadVkF2 = 0x71,
    PadVkF4 = 0x73,
    PadVkShift = 0xA0,
    PadVkCtrl = 0xA2,
    PadVkAlt = 0xA4,
};

/// Keys on the on-screen keyboard that aren't characters.
typedef NS_ENUM(NSInteger, PadSpecialKey) {
    PadSpecialEnter,
    PadSpecialBackspace,
    PadSpecialTab,
    PadSpecialEscape,
    PadSpecialLeft,
    PadSpecialRight,
    PadSpecialUp,
    PadSpecialDown,
    /// Deletes all the text in the selected text box (Ctrl+A, then Backspace).
    PadSpecialClearAll,
};

@interface PadOutput : NSObject

+ (instancetype)shared;

/// Pointer movement, in host pixels. Fractions carry over to the next call.
/// Lpz Remote: once the stream size is known (startCursorTrackingWidth:height:), the app
/// keeps the cursor position itself and sends absolute positions, so it always knows where
/// the cursor is (the cursor stays inside the streamed monitor).
- (void)moveByX:(float)dx y:(float)dy;
/// Starts tracking the cursor for a stream of this size and puts it in the centre.
- (void)startCursorTrackingWidth:(int)width height:(int)height;
- (void)stopCursorTracking;
/// YES while the app knows where the cursor is.
@property (nonatomic, readonly) BOOL tracksCursor;
/// Cursor position in stream pixels (valid while tracksCursor).
@property (nonatomic, readonly) CGPoint cursorPosition;
@property (nonatomic, readonly) CGSize streamSize;
/// Puts the cursor at this point, in stream pixels.
- (void)moveCursorTo:(CGPoint)point;
- (void)click;
- (void)rightClick;
- (void)dragBegin;
- (void)dragEnd;
/// High-resolution wheel units (120 = one notch). Positive scrolls up.
- (void)scrollBy:(float)amount;
- (void)scrollEnd;
/// Pinch zoom: holds Ctrl and turns the wheel, which zooms text in browsers and most apps.
/// Positive notches zoom in (bigger). Ctrl stays down until zoomEnd.
- (void)zoomBy:(int)notches;
- (void)zoomEnd;

/// Presses these keys together (modifiers first), then lets go in reverse order.
- (void)pressKeys:(NSArray<NSNumber*>*)codes;
/// Digita o texto. Com o layout "EUA internacional" (PadSettings deadKeys), acentos e ç saem
/// como teclas mortas (' + a = á, ~ + a = ã, ^ + e = ê, ' + c = ç) e as próprias ' " ` ~ ^
/// como tecla + espaço, o que funciona em qualquer app do KDE; o resto vai como texto UTF-8.
- (void)typeText:(NSString*)text;
- (void)special:(PadSpecialKey)key;

/// Lets go of anything still held, e.g. when the stream ends mid-drag.
- (void)releaseAll;

@end

NS_ASSUME_NONNULL_END
