//
//  PadPcKeysView.m
//  iMoonlight
//
//  A port of ThorPad's PcKeysView (Android) to UIKit.
//

#import "PadPcKeysView.h"
#import "PadOutput.h"
#import "PadHaptics.h"
#import "PadSettings.h"

typedef NS_ENUM(NSInteger, PcKeyType) {
    PcKeyNormal, PcKeyFn, PcKeyShortcut, PcKeyModifier, PcKeyEscape, PcKeyLetters, PcKeyClose, PcKeyPaste
};

static const NSTimeInterval REPEAT_DELAY = 0.400, REPEAT_EVERY = 0.055;
static const CGFloat STRIP_HEIGHT = 44;

static UIColor* rgb(int r, int g, int b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1];
}

@interface PcKey : NSObject
@property (nonatomic, copy) NSString* label;
@property (nonatomic, copy, nullable) NSString* sub;
@property (nonatomic) PcKeyType type;
@property (nonatomic) CGFloat weight;
@property (nonatomic) BOOL repeats;
@property (nonatomic, copy) NSArray<NSNumber*>* codes;
@property (nonatomic) CGRect rect;
@end

@implementation PcKey
@end

static PcKey* key(NSString* label, NSString* sub, PcKeyType type, CGFloat weight, BOOL repeats, NSArray<NSNumber*>* codes) {
    PcKey* k = [[PcKey alloc] init];
    k.label = label;
    k.sub = sub;
    k.type = type;
    k.weight = weight;
    k.repeats = repeats;
    k.codes = codes;
    return k;
}

@implementation PadPcKeysView {
    NSArray<NSArray<PcKey*>*>* _rows;
    PcKey* _letters;
    PcKey* _close;
    CGRect _stripRect;
    NSMapTable<UITouch*, id>* _down;
    /// Modifiers tapped and waiting for the next key, in the order they were tapped.
    NSMutableArray<PcKey*>* _held;
    PcKey* _repeating;
    CGFloat _rowHeight;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor blackColor];
        self.contentMode = UIViewContentModeRedraw;
        _down = [NSMapTable strongToStrongObjectsMapTable];
        _held = [NSMutableArray array];
        _letters = key(@"ABC", nil, PcKeyLetters, 0, NO, @[]);
        _close = key(@"✕ Fechar", nil, PcKeyClose, 0, NO, @[]);

        [self buildRows];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged) name:PadSettingsChangedNotification object:nil];
    }
    return self;
}

- (void)buildRows {
    NSMutableArray* r1 = [NSMutableArray arrayWithObject:key(@"Esc", nil, PcKeyEscape, 1, NO, @[@(PadVkEscape)])];
    NSMutableArray* r2 = [NSMutableArray arrayWithObject:key(@"Tab", nil, PcKeyNormal, 1, NO, @[@(PadVkTab)])];
    for (int i = 0; i < 12; i++) {
        [(i < 6 ? r1 : r2) addObject:key([NSString stringWithFormat:@"F%d", i + 1], nil, PcKeyFn, 1, NO, @[@(PadVkF1 + i)])];
    }
    NSMutableArray* rows = [@[
        r1,
        r2,
        // Atalhos do KDE Plasma (KWin) deste PC.
        @[key(@"Alt+Tab", @"trocar janela", PcKeyShortcut, 1, NO, @[@(PadVkAlt), @(PadVkTab)]),
          key(@"Super+W", @"visão geral", PcKeyShortcut, 1, NO, @[@(PadVkWin), @(PadVkW)]),
          key(@"Super+D", @"área de trabalho", PcKeyShortcut, 1, NO, @[@(PadVkWin), @(PadVkD)]),
          key(@"Super", @"menu", PcKeyShortcut, 0.8, NO, @[@(PadVkWin)])],
        @[key(@"Alt+F4", @"fechar janela", PcKeyShortcut, 1, NO, @[@(PadVkAlt), @(PadVkF4)]),
          key(@"Ctrl+Shift+Esc", @"monitor do sistema", PcKeyShortcut, 1.45, NO, @[@(PadVkCtrl), @(PadVkShift), @(PadVkEscape)]),
          key(@"PrtSc", @"Spectacle", PcKeyShortcut, 1, NO, @[@(PadVkPrintScreen)]),
          key(@"Super+V", @"área de transf.", PcKeyShortcut, 1, NO, @[@(PadVkWin), @(PadVkV)])],
        // O Sunshine troca o monitor transmitido com Ctrl+Alt+Shift+F1/F2 e mostra o cursor com +N.
        @[key(@"Principal", @"monitor AOC", PcKeyShortcut, 1, NO, @[@(PadVkCtrl), @(PadVkAlt), @(PadVkShift), @(PadVkF2)]),
          key(@"Vertical", @"monitor Samsung", PcKeyShortcut, 1, NO, @[@(PadVkCtrl), @(PadVkAlt), @(PadVkShift), @(PadVkF1)]),
          key(@"Cursor", @"mostrar/ocultar", PcKeyShortcut, 1, NO, @[@(PadVkCtrl), @(PadVkAlt), @(PadVkShift), @(PadVkN)])],
        @[key(@"Home", nil, PcKeyNormal, 1, NO, @[@(PadVkHome)]),
          key(@"End", nil, PcKeyNormal, 1, NO, @[@(PadVkEnd)]),
          key(@"PgUp", nil, PcKeyNormal, 1, YES, @[@(PadVkPageUp)]),
          key(@"PgDn", nil, PcKeyNormal, 1, YES, @[@(PadVkPageDown)]),
          key(@"Del", nil, PcKeyNormal, 1, YES, @[@(PadVkDelete)]),
          key(@"↑", nil, PcKeyNormal, 1, YES, @[@(PadVkUp)]),
          key(@"⌫", nil, PcKeyNormal, 1, YES, @[@(PadVkBackspace)])],
        @[key(@"Ctrl", nil, PcKeyModifier, 1, NO, @[@(PadVkCtrl)]),
          key(@"Alt", nil, PcKeyModifier, 1, NO, @[@(PadVkAlt)]),
          key(@"Shift", nil, PcKeyModifier, 1, NO, @[@(PadVkShift)]),
          key(@"Super", nil, PcKeyModifier, 1, NO, @[@(PadVkWin)]),
          key(@"←", nil, PcKeyNormal, 1, YES, @[@(PadVkLeft)]),
          key(@"↓", nil, PcKeyNormal, 1, YES, @[@(PadVkDown)]),
          key(@"→", nil, PcKeyNormal, 1, YES, @[@(PadVkRight)])],
    ] mutableCopy];
    // Lpz Remote: mídia e volume
    [rows insertObject:@[key(@"⏮", nil, PcKeyNormal, 1, NO, @[@(PadVkMediaPrev)]),
                         key(@"⏯", nil, PcKeyNormal, 1, NO, @[@(PadVkMediaPlayPause)]),
                         key(@"⏭", nil, PcKeyNormal, 1, NO, @[@(PadVkMediaNext)]),
                         key(@"🔇", nil, PcKeyNormal, 1, NO, @[@(PadVkVolumeMute)]),
                         key(@"🔉", nil, PcKeyNormal, 1, YES, @[@(PadVkVolumeDown)]),
                         key(@"🔊", nil, PcKeyNormal, 1, YES, @[@(PadVkVolumeUp)])] atIndex:2];
    // Colar do iPhone + atalhos personalizados (Ajustes > Atalhos personalizados)
    NSMutableArray* custom = [NSMutableArray arrayWithObject:key(@"Colar", @"do iPhone", PcKeyPaste, 1, NO, @[])];
    NSUInteger customRows = 0;
    for (NSString* line in [[PadSettings shortcuts] componentsSeparatedByString:@"\n"]) {
        NSRange eq = [line rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString* label = [[line substringToIndex:eq.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString* combo = [[line substringFromIndex:eq.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSArray* codes = [PadOutput codesForCombo:combo];
        if (label.length == 0 || codes == nil) continue;
        if (custom.count == 4) {
            if (customRows == 1) break;   // no máximo duas linhas de atalhos
            [rows insertObject:custom atIndex:3 + customRows++];
            custom = [NSMutableArray array];
        }
        [custom addObject:key(label, combo, PcKeyShortcut, 1, NO, codes)];
    }
    if (custom.count) [rows insertObject:custom atIndex:3 + customRows];
    _rows = rows;
}

- (void)settingsChanged {
    [self buildRows];
    [self setNeedsLayout];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)reset {
    [_held removeAllObjects];
    [_down removeAllObjects];
    _repeating = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatKey) object:nil];
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat closeW = MAX(80, w * 220 / 1240), lettersW = MAX(80, w * 250 / 1240);
    _stripRect = CGRectMake(0, 0, w - closeW - lettersW, STRIP_HEIGHT);
    _letters.rect = CGRectMake(CGRectGetMaxX(_stripRect), 0, lettersW, STRIP_HEIGHT);
    _close.rect = CGRectMake(w - closeW, 0, closeW, STRIP_HEIGHT);
    _rowHeight = (h - STRIP_HEIGHT) / _rows.count;
    for (NSUInteger r = 0; r < _rows.count; r++) {
        CGFloat total = 0;
        for (PcKey* k in _rows[r]) total += k.weight;
        CGFloat x = 0, top = STRIP_HEIGHT + r * _rowHeight;
        for (PcKey* k in _rows[r]) {
            CGFloat kw = w * k.weight / total;
            k.rect = CGRectMake(x, top, kw, _rowHeight);
            x += kw;
        }
    }
    [self setNeedsDisplay];
}

#pragma mark - Drawing

static CGSize drawCenteredAt(NSString* text, CGPoint center, UIFont* font, UIColor* color) {
    NSDictionary* attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: color};
    CGSize size = [text sizeWithAttributes:attrs];
    [text drawAtPoint:CGPointMake(center.x - size.width / 2, center.y - size.height / 2) withAttributes:attrs];
    return size;
}

- (void)drawRect:(CGRect)rect {
    [[UIColor blackColor] setFill];
    UIRectFill(self.bounds);
    CGFloat hair = 1;
    [rgb(0x16, 0x11, 0x0f) setFill];
    UIRectFill(CGRectMake(_stripRect.origin.x, _stripRect.origin.y, _stripRect.size.width - hair, _stripRect.size.height - hair));
    [self drawStrip];
    [self drawKey:_letters hair:hair];
    [self drawKey:_close hair:hair];
    for (NSArray<PcKey*>* row in _rows) {
        for (PcKey* k in row) [self drawKey:k hair:hair];
    }
}

- (void)drawStrip {
    CGFloat h = _stripRect.size.height;
    CGFloat x = h * 0.3, cy = CGRectGetMidY(_stripRect);
    CGFloat maxX = CGRectGetMaxX(_stripRect) - 6;
    NSString* text;
    UIFont* font;
    UIColor* color;
    if (_held.count == 0) {
        text = @"Ctrl, Alt, Shift e Super ficam presos até a próxima tecla";
        font = [UIFont systemFontOfSize:h * 0.27];
        color = rgb(0x7d, 0x70, 0x68);
    } else {
        NSMutableString* combo = [NSMutableString string];
        for (PcKey* k in _held) {
            [combo appendFormat:@"%@ + ", k.label];
        }
        [combo appendString:@"…"];
        text = combo;
        font = [UIFont boldSystemFontOfSize:h * 0.38];
        color = rgb(0xc8, 0xa1, 0x5a);
    }
    [text drawWithRect:CGRectMake(x, cy - font.lineHeight, maxX - x, font.lineHeight * 2)
               options:NSStringDrawingUsesLineFragmentOrigin
            attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: color,
                         NSParagraphStyleAttributeName: ({
                             NSMutableParagraphStyle* p = [[NSMutableParagraphStyle alloc] init];
                             p.lineBreakMode = NSLineBreakByWordWrapping;
                             p;
                         })}
               context:nil];
}

- (BOOL)isDown:(PcKey*)k {
    for (UITouch* t in _down) {
        if ([_down objectForKey:t] == k) return YES;
    }
    return NO;
}

- (void)drawKey:(PcKey*)k hair:(CGFloat)hair {
    UIColor* bg;
    UIColor* fg;
    UIColor* subFg = rgb(0x9a, 0x8c, 0x82);
    CGFloat rh = MIN(_rowHeight, 100);
    CGFloat size = rh * 0.26;
    BOOL bold = NO;
    switch (k.type) {
        case PcKeyClose:
            bg = rgb(0x4a, 0x16, 0x1a);
            fg = rgb(0xff, 0xb8, 0xb0);
            size = STRIP_HEIGHT * 0.36;
            bold = YES;
            break;
        case PcKeyLetters:
            bg = rgb(0x33, 0x29, 0x25);
            fg = rgb(0xe0, 0xd5, 0xc8);
            size = STRIP_HEIGHT * 0.34;
            bold = YES;
            break;
        case PcKeyEscape:
            bg = rgb(0x3a, 0x2a, 0x2e);
            fg = rgb(0xff, 0xc7, 0xcd);
            break;
        case PcKeyShortcut:
            bg = rgb(0x2b, 0x21, 0x16);
            fg = rgb(0xef, 0xe7, 0xde);
            subFg = rgb(0xb0, 0x92, 0x5e);
            size = rh * (k.label.length > 10 ? 0.17 : 0.21);
            break;
        case PcKeyModifier: {
            BOOL on = [_held containsObject:k];
            bg = on ? rgb(0x7a, 0x1c, 0x21) : rgb(0x33, 0x29, 0x25);
            fg = on ? [UIColor whiteColor] : rgb(0xe0, 0xd5, 0xc8);
            subFg = rgb(0xef, 0xe7, 0xde);
            size = rh * 0.22;
            break;
        }
        case PcKeyFn:
            bg = rgb(0x24, 0x1d, 0x1a);
            fg = rgb(0xef, 0xe7, 0xde);
            size = rh * 0.22;
            break;
        default:
            bg = rgb(0x24, 0x1d, 0x1a);
            fg = [UIColor whiteColor];
            if (k.label.length == 1) size = rh * 0.3;
            else size = rh * 0.2;
            break;
    }
    if ([self isDown:k]) {
        bg = rgb(0xc8, 0xa1, 0x5a);
        fg = subFg = [UIColor blackColor];
    }
    [bg setFill];
    UIRectFill(CGRectMake(k.rect.origin.x, k.rect.origin.y, k.rect.size.width - hair, k.rect.size.height - hair));
    // Long labels shrink to fit narrow keys.
    UIFont* font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    CGFloat fit = [k.label sizeWithAttributes:@{NSFontAttributeName: font}].width;
    if (fit > k.rect.size.width - 8) {
        size *= (k.rect.size.width - 8) / fit;
        font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    }
    NSString* sub = (k.type == PcKeyModifier && [_held containsObject:k]) ? @"preso" : k.sub;
    CGPoint c = CGPointMake(CGRectGetMidX(k.rect), CGRectGetMidY(k.rect));
    if (sub == nil) {
        drawCenteredAt(k.label, c, font, fg);
    } else {
        drawCenteredAt(k.label, CGPointMake(c.x, c.y - k.rect.size.height * 0.11), font, fg);
        CGFloat subSize = MIN(rh * 0.13, 12);
        UIFont* subFont = [UIFont systemFontOfSize:subSize];
        CGFloat subFit = [sub sizeWithAttributes:@{NSFontAttributeName: subFont}].width;
        if (subFit > k.rect.size.width - 6) subFont = [UIFont systemFontOfSize:subSize * (k.rect.size.width - 6) / subFit];
        drawCenteredAt(sub, CGPointMake(c.x, c.y + k.rect.size.height * 0.15), subFont, subFg);
    }
}

#pragma mark - Touch

- (PcKey*)keyAt:(CGPoint)p {
    if (CGRectContainsPoint(_close.rect, p)) return _close;
    if (CGRectContainsPoint(_letters.rect, p)) return _letters;
    if (p.y < CGRectGetMaxY(_stripRect)) return nil;
    PcKey* best = nil;
    CGFloat bestD = CGFLOAT_MAX;
    for (NSArray<PcKey*>* row in _rows) {
        for (PcKey* k in row) {
            if (CGRectContainsPoint(k.rect, p)) return k;
            CGFloat dx = MAX(MAX(CGRectGetMinX(k.rect) - p.x, 0), p.x - CGRectGetMaxX(k.rect));
            CGFloat dy = MAX(MAX(CGRectGetMinY(k.rect) - p.y, 0), p.y - CGRectGetMaxY(k.rect));
            CGFloat d = dx * dx + dy * dy;
            if (d < bestD) {
                bestD = d;
                best = k; // edges snap to the nearest key
            }
        }
    }
    return best;
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    for (UITouch* touch in touches) {
        PcKey* k = [self keyAt:[touch locationInView:self]];
        [_down setObject:(k ?: [NSNull null]) forKey:touch];
        if (k == nil) continue;
        [PadHaptics play:PadHapticKey];
        if (k.type != PcKeyClose && k.type != PcKeyLetters) [self fire:k];
        if (k.repeats && _held.count == 0) {
            _repeating = k;
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatKey) object:nil];
            [self performSelector:@selector(repeatKey) withObject:nil afterDelay:REPEAT_DELAY];
        }
    }
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    for (UITouch* touch in touches) {
        id value = [_down objectForKey:touch];
        [_down removeObjectForKey:touch];
        if (value == _repeating) {
            _repeating = nil;
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatKey) object:nil];
        }
        if ([value isKindOfClass:[PcKey class]]) {
            PcKey* k = value;
            if (k.type == PcKeyClose) [self.delegate pcKeysViewDidClose:self];
            else if (k.type == PcKeyLetters) [self.delegate pcKeysViewWantsLetters:self];
        }
    }
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [_down removeAllObjects];
    _repeating = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(repeatKey) object:nil];
    [self setNeedsDisplay];
}

- (void)repeatKey {
    if (_repeating == nil) return;
    [self fire:_repeating];
    [self performSelector:@selector(repeatKey) withObject:nil afterDelay:REPEAT_EVERY];
}

- (void)fire:(PcKey*)k {
    if (k.type == PcKeyPaste) {
        NSString* text = UIPasteboard.generalPasteboard.string;
        if (text.length) [[PadOutput shared] typeText:text];
        else [PadHaptics play:PadHapticKey];
        return;
    }
    if (k.type == PcKeyModifier) {
        // Tap to hold for the next key; tap again to let go.
        if ([_held containsObject:k]) [_held removeObject:k];
        else [_held addObject:k];
        return;
    }
    NSMutableArray<NSNumber*>* codes = [NSMutableArray array];
    for (PcKey* m in _held) [codes addObject:m.codes.firstObject];
    [codes addObjectsFromArray:k.codes];
    [_held removeAllObjects];
    [[PadOutput shared] pressKeys:codes];
}

@end
