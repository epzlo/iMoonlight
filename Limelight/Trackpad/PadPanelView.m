//
//  PadPanelView.m
//  iMoonlight
//

#import "PadPanelView.h"
#import "PadTrackpadView.h"
#import "PadKeyboardView.h"
#import "PadPcKeysView.h"
#import "PadOutput.h"
#import "PadSettings.h"
#import "PadHaptics.h"
#import <Speech/Speech.h>
#import "PadAutocorrect.h"
#import <AVFoundation/AVFoundation.h>

static const CGFloat BAR_HEIGHT = 40;
static const CGFloat BAR_PAD = 6;
/// After this long without a touch the trackpad dims; the next touch only wakes it.
static const NSTimeInterval DIM_AFTER = 30;
/// With less trackpad than this left above the keyboard, the keyboard takes the whole panel.
static const CGFloat MIN_PAD_HEIGHT = 120;
/// Side by side, the keyboard's share of the width; the trackpad gets the rest.
static const CGFloat SIDE_KEYBOARD_SHARE = 0.775;
/// Side by side, the strip along the top of the trackpad where a swipe down shows the bar.
static const CGFloat GRABBER_HEIGHT = 28;
/// How far the swipe must travel to show the bar.
static const CGFloat GRABBER_SWIPE = 20;
/// Side by side, the bar hides itself again after this long.
static const NSTimeInterval BAR_SHOWN_FOR = 4;

@interface PadPanelView () <PadKeyboardViewDelegate, PadPcKeysViewDelegate>
@end

@implementation PadPanelView {
    UIStackView* _bar;
    PadTrackpadView* _pad;
    PadKeyboardView* _keyboard;
    PadPcKeysView* _pcKeys;
    UIButton* _videoButton;
    /// Side by side the bar is hidden; a swipe down on this strip shows it.
    UIView* _grabber;
    BOOL _barRevealed;
    BOOL _dimmed;
    /// The touch that wakes a dimmed panel only wakes it.
    BOOL _swallowing;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.multipleTouchEnabled = YES;

        _bar = [[UIStackView alloc] init];
        _bar.axis = UILayoutConstraintAxisHorizontal;
        _bar.distribution = UIStackViewDistributionFillEqually;
        _bar.spacing = 8;
        _bar.spacing = 6;
        [_bar addArrangedSubview:[self barButton:@"Teclado" symbol:@"keyboard" action:@selector(keyboardTapped)]];
        [_bar addArrangedSubview:[self barButton:@"Teclas" symbol:@"command" action:@selector(pcKeysTapped)]];
        [_bar addArrangedSubview:[self barButton:@"Voz" symbol:@"mic" action:@selector(voiceTapped)]];
        _videoButton = [self barButton:@"" symbol:@"video.slash" action:@selector(videoTapped)];
        [_bar addArrangedSubview:_videoButton];
        [self updateVideoButton];
        [_bar addArrangedSubview:[self barButton:@"Ajustes" symbol:@"gearshape" action:@selector(settingsTapped)]];
        UIButton* leave = [self barButton:@"Sair" symbol:@"xmark" action:@selector(disconnectTapped)];
        leave.tintColor = [UIColor colorWithRed:0xff / 255.0 green:0xb8 / 255.0 blue:0xb0 / 255.0 alpha:1];
        [leave setTitleColor:leave.tintColor forState:UIControlStateNormal];
        leave.backgroundColor = [UIColor colorWithRed:0x4a / 255.0 green:0x16 / 255.0 blue:0x1a / 255.0 alpha:1];
        [_bar addArrangedSubview:leave];
        [self addSubview:_bar];

        _pad = [[PadTrackpadView alloc] initWithFrame:CGRectZero];
        [self addSubview:_pad];

        _keyboard = [[PadKeyboardView alloc] initWithFrame:CGRectZero];
        _keyboard.delegate = self;
        _keyboard.hidden = YES;
        [self addSubview:_keyboard];

        _grabber = [[UIView alloc] init];
        _grabber.hidden = YES;
        UIView* handle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 4)];
        handle.backgroundColor = [UIColor colorWithWhite:1 alpha:70 / 255.0];
        handle.layer.cornerRadius = 2;
        handle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        handle.tag = 1;
        [_grabber addSubview:handle];
        [_grabber addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(grabberPanned:)]];
        [_grabber addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revealBar)]];
        [self addSubview:_grabber];

        _pcKeys = [[PadPcKeysView alloc] initWithFrame:CGRectZero];
        _pcKeys.delegate = self;
        _pcKeys.hidden = YES;
        [self addSubview:_pcKeys];

        [self restartIdleTimer];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged)
                                                     name:PadSettingsChangedNotification object:nil];
    }
    return self;
}

- (void)settingsChanged {
    [self setNeedsLayout];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (UIButton*)barButton:(NSString*)title symbol:(NSString*)symbol action:(SEL)action {
    UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:title forState:UIControlStateNormal];
    UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor = [UIColor colorWithRed:0xc8 / 255.0 green:0xa1 / 255.0 blue:0x5a / 255.0 alpha:1];
    b.imageEdgeInsets = UIEdgeInsetsMake(0, -3, 0, 3);
    b.accessibilityLabel = title;
    [b setTitleColor:[UIColor colorWithWhite:1 alpha:200 / 255.0] forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithRed:0xc8 / 255.0 green:0xa1 / 255.0 blue:0x5a / 255.0 alpha:1] forState:UIControlStateHighlighted];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.6;
    b.backgroundColor = [UIColor colorWithRed:0x24 / 255.0 green:0x1d / 255.0 blue:0x1a / 255.0 alpha:1];
    b.layer.cornerRadius = 10;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 4);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat left = 0;
    BOOL keyboardCoversPad = NO;
    CGFloat padTop = BAR_PAD + BAR_HEIGHT;
    CGFloat padHeight = b.size.height - padTop;
    if (_sideBySide) {
        // Keyboard down the whole left side, the trackpad on the right, and the bar hidden
        // until a swipe down from the top of the trackpad.
        if (!_keyboard.hidden) {
            CGFloat kbWidth = round(b.size.width * SIDE_KEYBOARD_SHARE);
            _keyboard.frame = CGRectMake(_keyboardInset, 0, kbWidth - _keyboardInset, b.size.height);
            left = kbWidth + 1;
        }
        padTop = 0;
        padHeight = b.size.height;
    }
    else if (!_keyboard.hidden) {
        // The keyboard takes up as much of the screen as the iPhone's own (above the home
        // indicator), leaving the bar and the trackpad above it.
        CGFloat kbHeight = [PadKeyboardView preferredHeight];
        CGFloat bottomInset = self.safeAreaInsets.bottom;
        if (padHeight - kbHeight - bottomInset >= MIN_PAD_HEIGHT) {
            padHeight -= kbHeight + bottomInset;
            _keyboard.frame = CGRectMake(0, b.size.height - bottomInset - kbHeight, b.size.width, kbHeight);
        } else {
            _keyboard.frame = b;
            keyboardCoversPad = YES;
        }
    }
    CGFloat width = b.size.width - left;
    if (_sideBySide) {
        // When shown, the bar spans the whole top, over the keyboard's strip.
        _bar.frame = CGRectMake(_keyboardInset + BAR_PAD, BAR_PAD, b.size.width - _keyboardInset - 2 * BAR_PAD, BAR_HEIGHT);
        _bar.hidden = !_barRevealed;
        _grabber.frame = CGRectMake(left, 0, width, GRABBER_HEIGHT);
        [_grabber viewWithTag:1].center = CGPointMake(width / 2, 8);
        _grabber.hidden = _barRevealed;
        [self bringSubviewToFront:_grabber];
        [self bringSubviewToFront:_bar];
        [self bringSubviewToFront:_pcKeys];
    }
    else {
        _bar.frame = CGRectMake(left + BAR_PAD, BAR_PAD, width - 2 * BAR_PAD, BAR_HEIGHT);
        _bar.hidden = NO;
        _grabber.hidden = YES;
    }
    _pad.frame = CGRectMake(left, padTop, width, padHeight);
    _pad.showHints = !_sideBySide && [PadSettings showHints];
    _keyboard.handEnabled = !_sideBySide && !keyboardCoversPad;
    _pad.active = _pcKeys.hidden && !keyboardCoversPad;
    _pcKeys.frame = b;
}

- (void)setKeyboardInset:(CGFloat)keyboardInset {
    if (_keyboardInset == keyboardInset) return;
    _keyboardInset = keyboardInset;
    [self setNeedsLayout];
}

- (void)setSideBySide:(BOOL)sideBySide {
    if (_sideBySide == sideBySide) return;
    _sideBySide = sideBySide;
    [self hideBar];
    [self updateVideoButton];
    [self setNeedsLayout];
}

#pragma mark - Hidden bar (side by side)

- (void)grabberPanned:(UIPanGestureRecognizer*)pan {
    if (pan.state == UIGestureRecognizerStateChanged && [pan translationInView:self].y > GRABBER_SWIPE) {
        [self revealBar];
    }
}

- (void)revealBar {
    if (!_sideBySide || _barRevealed) return;
    [PadHaptics play:PadHapticBar];
    _barRevealed = YES;
    _bar.backgroundColor = [UIColor blackColor];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    _bar.alpha = 0;
    [UIView animateWithDuration:0.15 animations:^{ self->_bar.alpha = 1; }];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideBar) object:nil];
    [self performSelector:@selector(hideBar) withObject:nil afterDelay:BAR_SHOWN_FOR];
}

- (void)hideBar {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideBar) object:nil];
    if (!_barRevealed) return;
    _barRevealed = NO;
    _bar.alpha = 1;
    [self setNeedsLayout];
}

- (void)setVideoOff:(BOOL)videoOff {
    _videoOff = videoOff;
    [self updateVideoButton];
}

- (void)updateVideoButton {
    [_videoButton setTitle:_videoOff ? @"Ligar" : @"Vídeo" forState:UIControlStateNormal];
    [_videoButton setImage:[UIImage systemImageNamed:_videoOff ? @"video" : @"video.slash"
                                   withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]]
                  forState:UIControlStateNormal];
    _videoButton.accessibilityLabel = _videoOff ? @"Ligar o vídeo" : @"Desligar o vídeo";
    _pad.note = !_videoOff ? nil : _sideBySide ? @"Vídeo desligado" : @"Vídeo desligado · continua conectado";
    // Lit while the video is off, so it's clear why the screen is dark.
    _videoButton.backgroundColor = _videoOff
        ? [UIColor colorWithRed:0xa3 / 255.0 green:0x24 / 255.0 blue:0x2a / 255.0 alpha:1]
        : [UIColor colorWithRed:0x24 / 255.0 green:0x1d / 255.0 blue:0x1a / 255.0 alpha:1];
}

#pragma mark - Bar

- (void)keyboardTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self openKeyboard];
}

- (void)pcKeysTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self openPcKeys];
}

- (void)videoTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self.delegate padPanelWantsVideoToggled:self];
}

- (void)settingsTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self.delegate padPanelWantsSettings:self];
}

- (void)voiceTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self resetInput];
    [self.delegate padPanelWantsDictation:self];
}

- (void)disconnectTapped {
    [self hideBar];
    [PadHaptics play:PadHapticBar];
    [self.delegate padPanelWantsDisconnect:self];
}

- (void)openKeyboard {
    _pcKeys.hidden = YES;
    [_pcKeys reset];
    [_keyboard reset];
    _keyboard.hidden = NO;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)openPcKeys {
    _keyboard.hidden = YES;
    [_pcKeys reset];
    _pcKeys.hidden = NO;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)showTrackpad {
    _keyboard.hidden = YES;
    _pcKeys.hidden = YES;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)resetInput {
    [_keyboard reset];
    [_pcKeys reset];
    [self showTrackpad];
    [[PadOutput shared] releaseAll];
}

- (void)keyboardView:(PadKeyboardView*)view handHeld:(BOOL)held {
    _pad.handHeld = held;
}

- (void)keyboardViewDidClose:(PadKeyboardView*)view {
    [self showTrackpad];
}

- (void)pcKeysViewWantsLetters:(PadPcKeysView*)view {
    [self openKeyboard];
}

- (void)pcKeysViewDidClose:(PadPcKeysView*)view {
    [_pcKeys reset];
    [self showTrackpad];
}

#pragma mark - Dim when idle

- (void)restartIdleTimer {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(idleTimerFired) object:nil];
    [self performSelector:@selector(idleTimerFired) withObject:nil afterDelay:DIM_AFTER];
}

- (void)idleTimerFired {
    if ([PadSettings dimWhenIdle] && self.window != nil) {
        [self setDimmed:YES];
    }
}

- (void)setDimmed:(BOOL)dimmed {
    if (_dimmed == dimmed) return;
    _dimmed = dimmed;
    [UIView animateWithDuration:dimmed ? 0.6 : 0.15 animations:^{
        self.alpha = dimmed ? 0.25 : 1;
    }];
}

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    if (hit == nil) return nil;
    [self restartIdleTimer];
    if (_dimmed || _swallowing) {
        // Wake up, and keep the rest of this touch away from the trackpad.
        [self setDimmed:NO];
        _swallowing = YES;
        return self;
    }
    return hit;
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self endSwallowIfDone:event];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self endSwallowIfDone:event];
}

- (void)endSwallowIfDone:(UIEvent*)event {
    for (UITouch* t in [event touchesForView:self]) {
        if (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled) return;
    }
    _swallowing = NO;
}

@end


#pragma mark - Celular deitado

static UIColor* pantera(int hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xff) / 255.0 green:((hex >> 8) & 0xff) / 255.0 blue:(hex & 0xff) / 255.0 alpha:alpha];
}

typedef NS_ENUM(NSInteger, PadStripItem) {
    PadStripNone = -1,
    PadStripKeyboard, PadStripPcKeys, PadStripVoice, PadStripTrackpad, PadStripZoom, PadStripMonitor,
    PadStripNetwork, PadStripSettings, PadStripLeave,
};

static const CGFloat STRIP_W = 62;

@interface PadLandscapeView () <PadKeyboardViewDelegate, PadPcKeysViewDelegate>
@end

@implementation PadLandscapeView {
    UIView* _strip;
    NSArray<UIButton*>* _items;
    PadStripItem _open;
    PadKeyboardView* _keyboard;
    PadPcKeysView* _pcKeys;
    PadTrackpadView* _pad;
    UIView* _zoomCard;
    UILabel* _zoomLabel;
    UIView* _monitorCard;
    UIView* _networkCard;
    UILabel* _networkLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.multipleTouchEnabled = YES;
        _open = PadStripNone;
        _zoom = 1;

        _strip = [[UIView alloc] init];
        _strip.backgroundColor = pantera(0x0b0908, 0.94);
        [self addSubview:_strip];
        NSArray* spec = @[@[@"Teclado", @"keyboard"], @[@"Teclas", @"command"], @[@"Voz", @"mic"],
                          @[@"Touchpad", @"hand.point.up.left"], @[@"Zoom", @"plus.magnifyingglass"],
                          @[@"Monitor", @"display.2"], @[@"Imagem", @"slider.horizontal.3"],
                          @[@"Ajustes", @"gearshape"], @[@"Sair", @"xmark"]];
        NSMutableArray* items = [NSMutableArray array];
        for (NSUInteger i = 0; i < spec.count; i++) {
            UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.tag = i;
            b.accessibilityLabel = spec[i][0];
            UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
            UIImageView* icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:spec[i][1] withConfiguration:cfg]];
            icon.contentMode = UIViewContentModeCenter;
            icon.tag = 100;
            icon.userInteractionEnabled = NO;
            [b addSubview:icon];
            UILabel* text = [[UILabel alloc] init];
            text.text = spec[i][0];
            text.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightSemibold];
            text.textAlignment = NSTextAlignmentCenter;
            text.adjustsFontSizeToFitWidth = YES;
            text.minimumScaleFactor = 0.7;
            text.tag = 101;
            text.userInteractionEnabled = NO;
            [b addSubview:text];
            b.layer.cornerRadius = 10;
            [b addTarget:self action:@selector(itemTapped:) forControlEvents:UIControlEventTouchUpInside];
            [_strip addSubview:b];
            [items addObject:b];
        }
        _items = items;

        _pad = [[PadTrackpadView alloc] initWithFrame:CGRectZero];
        _pad.alpha = 0.62;
        _pad.hidden = YES;
        [self addSubview:_pad];

        _keyboard = [[PadKeyboardView alloc] initWithFrame:CGRectZero];
        _keyboard.delegate = self;
        _keyboard.hidden = YES;
        [self addSubview:_keyboard];

        _pcKeys = [[PadPcKeysView alloc] initWithFrame:CGRectZero];
        _pcKeys.delegate = self;
        _pcKeys.hidden = YES;
        [self addSubview:_pcKeys];

        _zoomCard = [self card];
        _zoomLabel = [self cardTitle:@"Zoom da imagem · 1,0×"];
        [_zoomCard addSubview:_zoomLabel];
        NSArray* zooms = @[@1.0, @1.5, @2.0, @3.0];
        for (NSUInteger i = 0; i < zooms.count; i++) {
            UIButton* b = [self cardButton:[NSString stringWithFormat:@"%@×", [[self class] decimal:[zooms[i] floatValue]]]
                                       sub:i == 0 ? @"inteira" : nil action:@selector(zoomTapped:)];
            b.tag = (NSInteger)([zooms[i] floatValue] * 10);
            [_zoomCard addSubview:b];
        }
        [_zoomCard addSubview:[self cardNote:@"Na imagem: pince para aproximar e arraste com dois dedos para mover."]];
        _zoomCard.hidden = YES;
        [self addSubview:_zoomCard];

        _monitorCard = [self card];
        [_monitorCard addSubview:[self cardTitle:@"Monitor transmitido"]];
        UIButton* main = [self cardButton:@"Principal" sub:@"AOC 2560×1440" action:@selector(monitorTapped:)];
        main.tag = 2;
        UIButton* vertical = [self cardButton:@"Vertical" sub:@"Samsung em pé" action:@selector(monitorTapped:)];
        vertical.tag = 1;
        UIButton* cursor = [self cardButton:@"Cursor" sub:@"mostrar/ocultar" action:@selector(monitorTapped:)];
        cursor.tag = 0;
        [_monitorCard addSubview:main];
        [_monitorCard addSubview:vertical];
        [_monitorCard addSubview:cursor];
        [_monitorCard addSubview:[self cardNote:@"No modo celular as janelas ficam no Principal; o Vertical aparece vazio."]];
        _monitorCard.hidden = YES;
        [self addSubview:_monitorCard];

        _networkCard = [self card];
        _networkLabel = [self cardTitle:@"Imagem e rede"];
        [_networkCard addSubview:_networkLabel];
        NSArray* nets = @[@[@"Automática", @"Wi-Fi alta, 4G leve"], @[@"Alta", @"dos ajustes"], @[@"Econômica", @"720p · 6 Mbps"],
                          @[@"Aplicar", @"reconecta já"], @[@"Desligar vídeo", @"só touchpad"]];
        for (NSUInteger i = 0; i < nets.count; i++) {
            UIButton* b = [self cardButton:nets[i][0] sub:nets[i][1] action:@selector(networkTapped:)];
            b.tag = i < 3 ? (NSInteger)i : i == 3 ? 9 : 8;
            [_networkCard addSubview:b];
        }
        [_networkCard addSubview:[self cardNote:@"A qualidade vale a partir da próxima conexão; Aplicar reconecta agora, em cerca de 3 segundos. Sem vídeo, quase não gasta dados."]];
        _networkCard.hidden = YES;
        [self addSubview:_networkCard];

        [self updateItems];
    }
    return self;
}

+ (NSString*)decimal:(CGFloat)v {
    return [[NSString stringWithFormat:@"%.1f", v] stringByReplacingOccurrencesOfString:@"." withString:@","];
}

- (UIView*)card {
    UIView* c = [[UIView alloc] init];
    c.backgroundColor = pantera(0x16110f, 0.96);
    c.layer.cornerRadius = 16;
    c.layer.borderWidth = 1;
    c.layer.borderColor = pantera(0xc8a15a, 0.35).CGColor;
    return c;
}

- (UILabel*)cardTitle:(NSString*)text {
    UILabel* l = [[UILabel alloc] init];
    l.text = text;
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.textColor = pantera(0xc8a15a, 1);
    l.tag = 900;
    return l;
}

- (UILabel*)cardNote:(NSString*)text {
    UILabel* l = [[UILabel alloc] init];
    l.text = text;
    l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:11];
    l.textColor = pantera(0x9a8c82, 1);
    l.tag = 901;
    return l;
}

- (UIButton*)cardButton:(NSString*)title sub:(nullable NSString*)sub action:(SEL)action {
    UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = pantera(0x332925, 1);
    b.layer.cornerRadius = 10;
    b.titleLabel.numberOfLines = 2;
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    NSMutableAttributedString* t = [[NSMutableAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: pantera(0xefe7de, 1)}];
    if (sub != nil) {
        [t appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:sub] attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:10.5],
            NSForegroundColorAttributeName: pantera(0x9a8c82, 1)}]];
    }
    [b setAttributedTitle:t forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (CGFloat)stripWidth {
    return self.safeAreaInsets.left + STRIP_W;
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat sw = self.stripWidth;
    _strip.frame = CGRectMake(0, 0, sw, b.size.height);
    CGFloat top = MAX(safe.top, 6), bottom = MAX(safe.bottom, 6);
    CGFloat itemH = (b.size.height - top - bottom) / _items.count;
    for (UIButton* item in _items) {
        // Cada botão ocupa a fatia inteira (sem vão), para o alvo de toque ficar o maior possível.
        item.frame = CGRectMake(safe.left + 4, top + item.tag * itemH, STRIP_W - 8, itemH);
        CGFloat ih = item.bounds.size.height;
        [item viewWithTag:100].frame = CGRectMake(0, ih * 0.08, item.bounds.size.width, ih * 0.55);
        [item viewWithTag:101].frame = CGRectMake(2, ih * 0.6, item.bounds.size.width - 4, ih * 0.32);
    }

    // A área à direita da faixa, onde os painéis abrem.
    CGRect area = CGRectMake(sw, 0, b.size.width - sw, b.size.height);
    CGFloat kbH = round(b.size.height * 0.56);
    _keyboard.frame = CGRectMake(area.origin.x, CGRectGetMaxY(area) - kbH, area.size.width - safe.right, kbH);
    CGFloat pcH = round(b.size.height * 0.72);
    _pcKeys.frame = CGRectMake(area.origin.x, CGRectGetMaxY(area) - pcH, area.size.width - safe.right, pcH);
    CGFloat padW = round(area.size.width * 0.46);
    _pad.frame = CGRectMake(CGRectGetMaxX(area) - padW, 0, padW, b.size.height);

    [self layoutCard:_zoomCard columns:4 width:MIN(360, area.size.width - 24)];
    [self layoutCard:_monitorCard columns:3 width:MIN(380, area.size.width - 24)];
    [self layoutCard:_networkCard columns:3 width:MIN(400, area.size.width - 24)];
}

- (void)layoutCard:(UIView*)card columns:(NSInteger)columns width:(CGFloat)w {
    CGFloat pad = 14, y = pad;
    UIView* title = [card viewWithTag:900];
    title.frame = CGRectMake(pad, y, w - 2 * pad, 18);
    y += 26;
    NSMutableArray<UIButton*>* buttons = [NSMutableArray array];
    for (UIView* v in card.subviews) if ([v isKindOfClass:[UIButton class]]) [buttons addObject:(UIButton*)v];
    CGFloat gap = 8, bw = (w - 2 * pad - gap * (columns - 1)) / columns;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        buttons[i].frame = CGRectMake(pad + (i % columns) * (bw + gap), y + (i / columns) * 58, bw, 50);
    }
    y += ((buttons.count + columns - 1) / columns) * 58 + 2;
    UILabel* note = (UILabel*)[card viewWithTag:901];
    CGSize ns = [note sizeThatFits:CGSizeMake(w - 2 * pad, CGFLOAT_MAX)];
    note.frame = CGRectMake(pad, y, w - 2 * pad, ns.height);
    y += ns.height + pad;
    card.frame = CGRectMake(self.stripWidth + 12, 12 + self.safeAreaInsets.top, w, y);
}

- (void)updateItems {
    for (UIButton* item in _items) {
        BOOL on = item.tag == _open;
        BOOL leave = item.tag == PadStripLeave;
        UIColor* fg = on ? pantera(0xefe7de, 1) : leave ? pantera(0xffb8b0, 1) : pantera(0xc8a15a, 1);
        item.backgroundColor = on ? pantera(0xa3242a, 1) : [UIColor clearColor];
        ((UIImageView*)[item viewWithTag:100]).tintColor = fg;
        ((UILabel*)[item viewWithTag:101]).textColor = on ? fg : pantera(0xe0d5c8, 0.85);
    }
    _keyboard.hidden = _open != PadStripKeyboard;
    _pcKeys.hidden = _open != PadStripPcKeys;
    _pad.hidden = _open != PadStripTrackpad;
    _pad.active = !_pad.hidden;
    _zoomCard.hidden = _open != PadStripZoom;
    _monitorCard.hidden = _open != PadStripMonitor;
    _networkCard.hidden = _open != PadStripNetwork;
    PadNetworkProfile profile = [PadSettings networkProfile];
    _networkLabel.text = [NSString stringWithFormat:@"Imagem e rede · agora em %@", [PadSettings onCellular] ? @"dados móveis" : @"Wi-Fi"];
    for (UIView* v in _networkCard.subviews) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        v.backgroundColor = v.tag == profile ? pantera(0x7a1c21, 1) : v.tag >= 8 ? pantera(0x4a161a, 1) : pantera(0x332925, 1);
    }
    _zoomLabel.text = [NSString stringWithFormat:@"Zoom da imagem · %@×", [[self class] decimal:_zoom]];
    for (UIView* v in _zoomCard.subviews) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        BOOL current = fabs(v.tag / 10.0 - _zoom) < 0.05;
        v.backgroundColor = current ? pantera(0x7a1c21, 1) : pantera(0x332925, 1);
    }
}

- (void)setZoom:(CGFloat)zoom {
    _zoom = zoom;
    [self updateItems];
}

- (void)itemTapped:(UIButton*)item {
    [PadHaptics play:PadHapticBar];
    PadStripItem which = item.tag;
    switch (which) {
        case PadStripVoice:
            [self resetInput];
            [self.delegate landscapeWantsDictation:self];
            return;
        case PadStripSettings: [self.delegate landscapeWantsSettings:self]; return;
        case PadStripLeave: [self.delegate landscapeWantsDisconnect:self]; return;
        default: break;
    }
    [_keyboard reset];
    [_pcKeys reset];
    [[PadOutput shared] releaseAll];
    _open = (_open == which) ? PadStripNone : which;
    [self updateItems];
}

- (void)zoomTapped:(UIButton*)b {
    [PadHaptics play:PadHapticBar];
    [self.delegate landscape:self wantsZoom:b.tag / 10.0];
}

- (void)networkTapped:(UIButton*)b {
    [PadHaptics play:PadHapticBar];
    if (b.tag == 9 || b.tag == 8) {
        _open = PadStripNone;
        [self updateItems];
        if (b.tag == 9) [self.delegate landscapeWantsReconnect:self];
        else [self.delegate landscapeWantsVideoToggled:self];
        return;
    }
    [PadSettings setNetworkProfile:(PadNetworkProfile)b.tag];
    [self updateItems];
}

- (void)monitorTapped:(UIButton*)b {
    [PadHaptics play:PadHapticBar];
    // O Sunshine troca de monitor com Ctrl+Alt+Shift+F1 (Vertical) / F2 (Principal) e liga o cursor com N.
    int key = b.tag == 2 ? PadVkF2 : b.tag == 1 ? PadVkF1 : PadVkN;
    [[PadOutput shared] pressKeys:@[@(PadVkCtrl), @(PadVkAlt), @(PadVkShift), @(key)]];
    if (b.tag != 0) {
        _open = PadStripNone;
        [self updateItems];
    }
}

- (void)resetInput {
    [_keyboard reset];
    [_pcKeys reset];
    [[PadOutput shared] releaseAll];
    _open = PadStripNone;
    [self updateItems];
}

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit; // o vazio deixa o toque chegar à imagem
}

- (void)keyboardViewDidClose:(PadKeyboardView*)view {
    [self resetInput];
}

- (void)pcKeysViewWantsLetters:(PadPcKeysView*)view {
    [_pcKeys reset];
    _open = PadStripKeyboard;
    [self updateItems];
}

- (void)pcKeysViewDidClose:(PadPcKeysView*)view {
    [self resetInput];
}

@end

#pragma mark - Ditado

/// Acabamento do ditado: comandos falados viram pontuação ("vírgula" → ","), acentos que o
/// reconhecimento esqueceu voltam (só troca de acento, nunca outra palavra) e as frases começam
/// com maiúscula e terminam com ponto.
static NSString* lpzFold(NSString* w) {
    return [w stringByFoldingWithOptions:NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch locale:nil];
}

/// Enrolações que nunca são palavra de verdade.
static NSSet<NSString*>* lpzFillers(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"ah", @"ahn", @"ahh", @"aah", @"hum", @"humm", @"hmm", @"hm", @"uhm", @"uh", @"hã",
                                    @"ãh", @"ã", @"ãã", @"eh", @"éh", @"éé", @"ééé", @"ehh", @"hein", @"uhum"]];
    });
    return set;
}

/// Palavras que podem se repetir de propósito ("não não", "muito muito").
static NSSet<NSString*>* lpzRepeatable(void) {
    static NSSet* set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"não", @"muito", @"bem", @"já", @"sim", @"pouco", @"tá", @"bora", @"vai", @"corre", @"calma", @"logo"]];
    });
    return set;
}

/// Durante a fala: só tira as enrolações óbvias, para o texto ao vivo já vir limpo.
static NSString* lpzLiveClean(NSString* text) {
    static NSRegularExpression* re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"(?i)(^|\\s)(ah+n?|a+h|hu+m+|hm+|uhm|uh+|hã+|ãh|ã+|eh+|éh|éé+|hein)[,.…!?]*(?=\\s|$)"
                                                       options:0 error:nil];
    });
    NSString* out = [re stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1"];
    out = [[NSRegularExpression regularExpressionWithPattern:@"\\s{2,}" options:0 error:nil]
        stringByReplacingMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@" "];
    return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

static BOOL lpzEndsWithPunctuation(NSString* s) {
    if (s.length == 0) return YES;
    return [@".,;:!?…" containsString:[s substringFromIndex:s.length - 1]];
}

/// Texto final a partir das palavras e dos tempos de cada uma: tira enrolações ("ah", "hum", e o
/// "é" solto entre pausas), tira gaguejo ("eu eu vou" → "eu vou") e usa as pausas para pontuar
/// onde o reconhecimento não pontuou (pausa média = vírgula, pausa longa = ponto).
static NSString* lpzCleanTranscription(SFTranscription* t) {
    NSString* full = t.formattedString;
    NSArray<SFTranscriptionSegment*>* segs = t.segments;
    if (segs.count == 0) return lpzLiveClean(full);
    BOOL timed = NO;
    for (SFTranscriptionSegment* g in segs) if (g.duration > 0) { timed = YES; break; }

    NSMutableArray<NSString*>* tokens = [NSMutableArray array];
    NSString* lastCore = nil;
    for (NSUInteger i = 0; i < segs.count; i++) {
        SFTranscriptionSegment* g = segs[i];
        // O pedaço do texto formatado desta palavra até a próxima (inclui a pontuação dela).
        NSUInteger start = g.substringRange.location;
        NSUInteger end = i + 1 < segs.count ? segs[i + 1].substringRange.location : full.length;
        if (start > full.length || end > full.length || end < start) continue;
        NSString* chunk = [[full substringWithRange:NSMakeRange(start, end - start)]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* core = [[g.substring stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]] lowercaseString];
        NSString* tail = chunk.length > g.substring.length && [chunk hasPrefix:g.substring] ? [chunk substringFromIndex:g.substring.length] : @"";

        NSTimeInterval gapBefore = 9, gapAfter = 9;
        if (timed && i > 0) gapBefore = g.timestamp - (segs[i - 1].timestamp + segs[i - 1].duration);
        if (timed && i + 1 < segs.count) gapAfter = segs[i + 1].timestamp - (g.timestamp + g.duration);

        BOOL filler = [lpzFillers() containsObject:core] ||
                      ([core isEqualToString:@"é"] && timed && gapBefore > 0.35 && gapAfter > 0.35);
        BOOL stutter = lastCore != nil && [core isEqualToString:lastCore] && ![lpzRepeatable() containsObject:core] &&
                       (!timed || gapBefore < 1.0);
        if (filler || stutter) {
            // A pontuação que vinha grudada nela passa para a palavra anterior.
            NSString* punct = [tail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (punct.length > 0 && tokens.count > 0 && !lpzEndsWithPunctuation(tokens.lastObject)) {
                tokens[tokens.count - 1] = [tokens.lastObject stringByAppendingString:punct];
            }
            continue;
        }
        NSString* token = chunk;
        if (timed && i + 1 < segs.count && !lpzEndsWithPunctuation(token)) {
            if (gapAfter >= 1.5) token = [token stringByAppendingString:@"."];
            else if (gapAfter >= 0.8) token = [token stringByAppendingString:@","];
        }
        [tokens addObject:token];
        lastCore = core;
    }
    return [tokens componentsJoinedByString:@" "];
}

static NSString* lpzPolishDictation(NSString* raw) {
    NSMutableString* t = [raw mutableCopy];
    // Mais longos primeiro, para "ponto e vírgula" não virar "ponto e ,".
    NSArray* commands = @[
        @[@"novo parágrafo", @"\n\n"], @[@"nova linha", @"\n"], @[@"próxima linha", @"\n"],
        @[@"ponto de interrogação", @"?"], @[@"ponto de exclamação", @"!"], @[@"ponto e vírgula", @";"],
        @[@"ponto final", @"."], @[@"dois pontos", @":"], @[@"reticências", @"..."], @[@"vírgula", @","],
        @[@"abre parênteses", @"("], @[@"fecha parênteses", @")"],
    ];
    for (NSArray* c in commands) {
        NSString* pattern = [NSString stringWithFormat:@"(?i)\\s*\\b%@\\b", [NSRegularExpression escapedPatternForString:c[0]]];
        NSString* with = [c[1] isEqualToString:@"("] ? @" (" : c[1];
        [[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil]
            replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length)
                      withTemplate:[NSRegularExpression escapedTemplateForString:with]];
    }
    // Pausa e comando falado juntos dão pontuação dobrada ("casa, ,"): fica a mais forte.
    [[NSRegularExpression regularExpressionWithPattern:@"[,;:]\\s*([,.;:!?])" options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"$1"];
    [[NSRegularExpression regularExpressionWithPattern:@"([.!?])\\s*," options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"$1"];
    // Espaço certo em volta da pontuação.
    [[NSRegularExpression regularExpressionWithPattern:@" +([,.;:!?)])" options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"$1"];
    [[NSRegularExpression regularExpressionWithPattern:@"([,;:!?])(?=[^\\s\\d])" options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"$1 "];
    [[NSRegularExpression regularExpressionWithPattern:@"\\( +" options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"("];
    [[NSRegularExpression regularExpressionWithPattern:@" *\n *" options:0 error:nil]
        replaceMatchesInString:t options:0 range:NSMakeRange(0, t.length) withTemplate:@"\n"];

    // Acentos: palavra a palavra, aceitando só a mesma palavra com outro acento.
    PadAutocorrectPT* pt = [PadAutocorrectPT shared];
    NSRegularExpression* words = [NSRegularExpression regularExpressionWithPattern:@"\\p{L}+" options:0 error:nil];
    NSArray<NSTextCheckingResult*>* found = [words matchesInString:t options:0 range:NSMakeRange(0, t.length)];
    for (NSTextCheckingResult* m in [found reverseObjectEnumerator]) {
        NSString* w = [t substringWithRange:m.range];
        NSString* fixed = w.length > 1 ? [pt correct:w.lowercaseString previous:nil] : nil;
        if (fixed != nil && ![fixed isEqualToString:w.lowercaseString] && [lpzFold(fixed) isEqualToString:lpzFold(w)]) {
            BOOL upper = [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[w characterAtIndex:0]];
            if (upper) fixed = [[[fixed substringToIndex:1] uppercaseString] stringByAppendingString:[fixed substringFromIndex:1]];
            [t replaceCharactersInRange:m.range withString:fixed];
        }
    }

    // Maiúscula no começo do texto e depois de . ! ? ou quebra de linha.
    BOOL capital = YES;
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t characterAtIndex:i];
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c]) {
            if (capital) {
                NSString* up = [[t substringWithRange:NSMakeRange(i, 1)] uppercaseString];
                [t replaceCharactersInRange:NSMakeRange(i, 1) withString:up];
            }
            capital = NO;
        } else if (c == '.' || c == '!' || c == '?' || c == '\n') {
            capital = YES;
        } else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c]) {
            capital = NO;
        }
    }
    NSString* out = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    // Frase completa sem pontuação no fim ganha ponto.
    if (out.length > 0 && [out componentsSeparatedByString:@" "].count >= 3) {
        unichar last = [out characterAtIndex:out.length - 1];
        if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:last]) out = [out stringByAppendingString:@"."];
    }
    return out;
}

@interface PadDictationViewController () <UITextViewDelegate>
@end

@implementation PadDictationViewController {
    UIView* _card;
    UILabel* _status;
    UIView* _dot;
    UITextView* _text;
    UILabel* _placeholder;
    SFSpeechRecognizer* _recognizer;
    SFSpeechAudioBufferRecognitionRequest* _request;
    SFSpeechRecognitionTask* _task;
    AVAudioEngine* _engine;
    BOOL _listening;
    BOOL _edited;
    // Enviar no meio da fala espera o resultado final (com os tempos das palavras) por até 2,5 s.
    BOOL _sendWhenFinal, _sendEnter, _delivered;
    SFTranscription* _last;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    [PadAutocorrectPT shared]; // carrega o dicionário enquanto a pessoa fala

    _card = [[UIView alloc] init];
    _card.backgroundColor = pantera(0x16110f, 0.98);
    _card.layer.cornerRadius = 22;
    _card.layer.borderWidth = 1;
    _card.layer.borderColor = pantera(0xc8a15a, 0.35).CGColor;
    [self.view addSubview:_card];

    _dot = [[UIView alloc] init];
    _dot.backgroundColor = pantera(0xd9434a, 1);
    _dot.layer.cornerRadius = 5;
    [_card addSubview:_dot];

    _status = [[UILabel alloc] init];
    _status.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _status.textColor = pantera(0xc8a15a, 1);
    _status.text = @"Preparando o microfone…";
    [_card addSubview:_status];

    _text = [[UITextView alloc] init];
    _text.backgroundColor = pantera(0x0b0908, 1);
    _text.textColor = pantera(0xefe7de, 1);
    _text.font = [UIFont systemFontOfSize:19 weight:UIFontWeightMedium];
    _text.layer.cornerRadius = 14;
    _text.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
    _text.keyboardAppearance = UIKeyboardAppearanceDark;
    _text.tintColor = pantera(0xc8a15a, 1);
    _text.delegate = self;
    [_card addSubview:_text];

    _placeholder = [[UILabel alloc] init];
    _placeholder.text = @"Fale em português. Diga \"vírgula\", \"ponto final\", \"ponto de interrogação\" ou \"nova linha\" para pontuar. Dá para corrigir antes de enviar.";
    _placeholder.numberOfLines = 0;
    _placeholder.font = [UIFont systemFontOfSize:15];
    _placeholder.textColor = pantera(0x9a8c82, 1);
    _placeholder.userInteractionEnabled = NO;
    [_text addSubview:_placeholder];

    NSArray* titles = @[@"Cancelar", @"Enviar", @"Enviar ↵"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = 200 + i;
        [b setTitle:titles[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        b.layer.cornerRadius = 12;
        b.backgroundColor = i == 0 ? pantera(0x332925, 1) : i == 1 ? pantera(0x7a1c21, 1) : pantera(0xa3242a, 1);
        [b setTitleColor:pantera(0xefe7de, i == 0 ? 0.8 : 1) forState:UIControlStateNormal];
        [b addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:b];
    }
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat w = MIN(520, b.size.width - 24 - safe.left - safe.right);
    CGFloat pad = 16, textH = b.size.height > b.size.width ? 160 : 100;
    CGFloat h = pad + 20 + 10 + textH + 12 + 50 + pad;
    _card.frame = CGRectMake(round((b.size.width - w) / 2), b.size.height - h - MAX(safe.bottom, 12), w, h);
    _dot.frame = CGRectMake(pad, pad + 5, 10, 10);
    _status.frame = CGRectMake(pad + 18, pad, w - 2 * pad - 18, 20);
    _text.frame = CGRectMake(pad, pad + 30, w - 2 * pad, textH);
    _placeholder.frame = CGRectMake(15, 12, _text.bounds.size.width - 30, 60);
    CGFloat gap = 8, bw = (w - 2 * pad - 2 * gap) / 3, y = CGRectGetMaxY(_text.frame) + 12;
    for (int i = 0; i < 3; i++) {
        [_card viewWithTag:200 + i].frame = CGRectMake(pad + i * (bw + gap), y, bw, 50);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [self showProblem:@"Sem permissão de reconhecimento de fala. Libere em Ajustes do iPhone > Lpz Remote."];
                return;
            }
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!granted) {
                        [self showProblem:@"Sem permissão do microfone. Libere em Ajustes do iPhone > Lpz Remote."];
                        return;
                    }
                    [self startListening];
                });
            }];
        });
    }];
}

- (void)showProblem:(NSString*)message {
    _status.text = message;
    _status.numberOfLines = 2;
    _status.adjustsFontSizeToFitWidth = YES;
    _status.minimumScaleFactor = 0.7;
    _dot.backgroundColor = pantera(0x9a8c82, 1);
    [_dot.layer removeAllAnimations];
}

- (void)startListening {
    if (_listening || _edited || self.presentingViewController == nil) return;
    _recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"pt-BR"]];
    if (_recognizer == nil || !_recognizer.isAvailable) {
        [self showProblem:@"O reconhecimento em português não está disponível agora (precisa de internet)."];
        return;
    }
    NSError* error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker |
                         AVAudioSessionCategoryOptionAllowBluetooth
                   error:&error];
    [session setActive:YES error:&error];

    _request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    _request.shouldReportPartialResults = YES;
    _request.taskHint = SFSpeechRecognitionTaskHintDictation;
    // O reconhecimento no servidor da Apple acerta mais acentos e pontuação que o do aparelho.
    _request.requiresOnDeviceRecognition = NO;
    _request.contextualStrings = @[@"vírgula", @"ponto final", @"ponto de interrogação", @"nova linha", @"KDE", @"Konsole", @"Steam"];
    if (@available(iOS 16.0, *)) _request.addsPunctuation = YES;

    _engine = [[AVAudioEngine alloc] init];
    AVAudioInputNode* input = _engine.inputNode;
    AVAudioFormat* format = [input outputFormatForBus:0];
    if (format.sampleRate <= 0) {
        [self showProblem:@"O microfone não respondeu. Tente de novo."];
        [self restoreAudio];
        return;
    }
    SFSpeechAudioBufferRecognitionRequest* request = _request;
    [input installTapOnBus:0 bufferSize:1024 format:format block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
        [request appendAudioPCMBuffer:buffer];
    }];
    [_engine prepare];
    if (![_engine startAndReturnError:&error]) {
        [input removeTapOnBus:0];
        [self showProblem:@"Não deu para ligar o microfone."];
        [self restoreAudio];
        return;
    }
    _listening = YES;
    _status.text = @"Ouvindo…";
    CABasicAnimation* pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @1;
    pulse.toValue = @0.25;
    pulse.duration = 0.7;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [_dot.layer addAnimation:pulse forKey:@"pulse"];

    __weak typeof(self) weakSelf = self;
    _task = [_recognizer recognitionTaskWithRequest:_request resultHandler:^(SFSpeechRecognitionResult* result, NSError* err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) me = weakSelf;
            if (me == nil) return;
            if (result != nil) me->_last = result.bestTranscription;
            if (result != nil && !me->_edited) {
                me->_text.text = result.isFinal ? lpzPolishDictation(lpzCleanTranscription(result.bestTranscription))
                                                : lpzLiveClean(result.bestTranscription.formattedString);
                me->_placeholder.hidden = me->_text.text.length > 0;
            }
            if (err != nil || result.isFinal) {
                if (!me->_edited && !result.isFinal && me->_last != nil) {
                    me->_text.text = lpzPolishDictation(lpzCleanTranscription(me->_last));
                }
                [me stopListening];
                if (me->_sendWhenFinal) {
                    [me deliver:me->_text.text];
                    return;
                }
                me->_status.text = me->_text.text.length > 0 ? @"Pronto. Corrija se quiser e envie." : @"Não ouvi nada. Toque em Cancelar ou fale de novo abrindo a Voz.";
            }
        });
    }];
}

- (void)stopListening {
    if (!_listening) return;
    _listening = NO;
    [_engine stop];
    [_engine.inputNode removeTapOnBus:0];
    [_request endAudio];
    [_task finish];
    _task = nil;
    _request = nil;
    _engine = nil;
    [_dot.layer removeAllAnimations];
    _dot.backgroundColor = pantera(0xc8a15a, 1);
    [self restoreAudio];
}

/// Volta o áudio ao jeito da transmissão (só tocar, sem abaixar outros sons).
- (void)restoreAudio {
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [session setActive:YES error:nil];
}

- (void)textViewDidBeginEditing:(UITextView*)textView {
    // Corrigindo à mão: para de ouvir para não sobrescrever.
    _edited = YES;
    [self stopListening];
    _status.text = @"Editando. Envie quando estiver certo.";
}

- (void)textViewDidChange:(UITextView*)textView {
    _placeholder.hidden = textView.text.length > 0;
}

- (void)backgroundTapped:(UITapGestureRecognizer*)tap {
    if (!CGRectContainsPoint(_card.frame, [tap locationInView:self.view])) [self finish:NO enter:NO];
}

- (void)buttonTapped:(UIButton*)b {
    [PadHaptics play:PadHapticBar];
    [self finish:b.tag != 200 enter:b.tag == 202];
}

- (void)finish:(BOOL)send enter:(BOOL)enter {
    [_text resignFirstResponder];
    if (send && _listening && !_edited) {
        // Ainda ouvindo: fecha o microfone e espera o resultado final, que traz as pausas.
        if (_sendWhenFinal) return;
        _sendWhenFinal = YES;
        _sendEnter = enter;
        _status.text = @"Finalizando o texto…";
        [_engine stop];
        [_engine.inputNode removeTapOnBus:0];
        [_request endAudio];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self->_delivered) return;
            NSString* text = self->_last != nil ? lpzPolishDictation(lpzCleanTranscription(self->_last)) : self->_text.text;
            [self stopListening];
            [self deliver:text];
        });
        return;
    }
    [self stopListening];
    _sendEnter = enter;
    if (send) [self deliver:_text.text];
    else [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)deliver:(NSString*)raw {
    if (_delivered) return;
    _delivered = YES;
    NSString* text = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL enter = _sendEnter;
    void (^onSend)(NSString*, BOOL) = self.onSend;
    [self dismissViewControllerAnimated:YES completion:^{
        if (onSend != nil && (text.length > 0 || enter)) onSend(text, enter);
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopListening];
}

@end
