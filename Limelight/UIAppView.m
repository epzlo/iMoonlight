//
//  UIAppView.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "UIAppView.h"
#import "AppAssetManager.h"

static const float REFRESH_CYCLE = 1.0f;

@implementation UIAppView {
    TemporaryApp* _app;
    UILabel* _appLabel;
    UIImageView* _appOverlay;
    UIImageView* _appImage;
    NSCache* _artCache;
    id<AppCallback> _callback;
#if !TARGET_OS_TV
    BOOL _lpzWide, _lpzPower;
    UIView* _lpzBar;
    UILabel* _lpzName;
    UILabel* _lpzState;
    UIImageView* _lpzPlay;
#endif
}

#if !TARGET_OS_TV
#define LPZ_RGB(h) [UIColor colorWithRed:((h>>16)&0xFF)/255.0 green:((h>>8)&0xFF)/255.0 blue:(h&0xFF)/255.0 alpha:1]

+ (BOOL) lpzIsPowerApp:(TemporaryApp*)app {
    return [app.name isEqualToString:@"Desligar PC"] || [app.name isEqualToString:@"Reiniciar PC"];
}

static NSString* lpzFriendlyName(NSString* name) {
    if ([name isEqualToString:@"Desktop"]) return @"Área de trabalho";
    if ([name isEqualToString:@"Steam Big Picture"]) return @"Steam";
    return name;
}

- (void) lpzLayoutWithSize:(CGSize)size power:(BOOL)power {
    _lpzWide = YES;
    _lpzPower = power;
    self.layer.shouldRasterize = NO;
    self.frame = CGRectMake(0, 0, size.width, size.height);
    self.layer.cornerRadius = power ? 14 : 18;
    self.clipsToBounds = YES;
    self.backgroundColor = LPZ_RGB(0x1C1615);
    self.layer.borderWidth = 1;
    self.layer.borderColor = [LPZ_RGB(0xC8A15A) colorWithAlphaComponent:power ? 0.22 : 0.28].CGColor;
    
    if (power) {
        _appImage.hidden = YES;
        BOOL off = [_app.name isEqualToString:@"Desligar PC"];
        UIImageView* icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:off ? @"power" : @"arrow.clockwise"]];
        icon.tintColor = off ? LPZ_RGB(0xD9434A) : LPZ_RGB(0xC8A15A);
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.frame = CGRectMake(16, (size.height - 22) / 2, 22, 22);
        [self addSubview:icon];
        UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, size.width - 56, size.height)];
        l.text = _app.name;
        l.textColor = LPZ_RGB(0xEFE7DE);
        l.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [self addSubview:l];
        return;
    }
    
    CGFloat barH = 58;
    CGFloat imgH = size.height - barH;
    _appImage.frame = CGRectMake(0, 0, size.width, imgH);
    _appImage.contentMode = UIViewContentModeScaleAspectFill;
    _appImage.clipsToBounds = YES;
    _appImage.backgroundColor = LPZ_RGB(0x16110F);
    
    _lpzBar = [[UIView alloc] initWithFrame:CGRectMake(0, imgH, size.width, barH)];
    _lpzBar.backgroundColor = LPZ_RGB(0x1C1615);
    _lpzBar.userInteractionEnabled = NO;
    UIView* line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, 1)];
    line.backgroundColor = [LPZ_RGB(0xC8A15A) colorWithAlphaComponent:0.25];
    [_lpzBar addSubview:line];
    _lpzName = [[UILabel alloc] initWithFrame:CGRectMake(16, 9, size.width - 80, 24)];
    _lpzName.text = lpzFriendlyName(_app.name);
    _lpzName.textColor = LPZ_RGB(0xEFE7DE);
    _lpzName.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [_lpzBar addSubview:_lpzName];
    _lpzState = [[UILabel alloc] initWithFrame:CGRectMake(16, 32, size.width - 80, 16)];
    _lpzState.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [_lpzBar addSubview:_lpzState];
    _lpzPlay = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
    _lpzPlay.tintColor = LPZ_RGB(0xA3242A);
    _lpzPlay.contentMode = UIViewContentModeScaleAspectFit;
    _lpzPlay.frame = CGRectMake(size.width - 52, (barH - 36) / 2, 36, 36);
    [_lpzBar addSubview:_lpzPlay];
    [self addSubview:_lpzBar];
    [self updateAppImage];
}

- (void) lpzRefreshState {
    if (!_lpzWide || _lpzPower) return;
    BOOL running = [_app.id isEqualToString:_app.host.currentGame];
    _lpzState.text = running ? @"● Em uso, toque para voltar" : @"Toque para conectar";
    _lpzState.textColor = running ? LPZ_RGB(0xD9434A) : [LPZ_RGB(0xEFE7DE) colorWithAlphaComponent:0.55];
    _lpzPlay.image = [UIImage systemImageNamed:running ? @"arrow.uturn.forward.circle.fill" : @"play.circle.fill"];
}
#endif

static UIImage* noImage;

- (id) initWithApp:(TemporaryApp*)app cache:(NSCache*)cache andCallback:(id<AppCallback>)callback {
    self = [super init];
    _app = app;
    _callback = callback;
    _artCache = cache;
    
    // Cache the NoAppImage ourselves to avoid
    // having to load it each time
    if (noImage == nil) {
        noImage = [UIImage imageNamed:@"NoAppImage"];
    }
        
#if TARGET_OS_TV
    self.frame = CGRectMake(0, 0, 200, 265);
#else
    self.frame = CGRectMake(0, 0, 150, 200);
#endif
    
    [self setAlpha:app.hidden ? 0.4 : 1.0];
    
    _appImage = [[UIImageView alloc] initWithFrame:self.frame];
    [_appImage setImage:noImage];
    [self addSubview:_appImage];
    
    // Use UIContextMenuInteraction on iOS 13.0+ and a standard UILongPressGestureRecognizer
    // for tvOS devices and iOS prior to 13.0.
#if !TARGET_OS_TV
    if (@available(iOS 13.0, *)) {
        UIContextMenuInteraction* rightClickInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [self addInteraction:rightClickInteraction];
    }
    else
#endif
    {
        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(appLongClicked:)];
        [self addGestureRecognizer:longPressRecognizer];
    }
    
    [self addTarget:self action:@selector(appClicked:) forControlEvents:UIControlEventPrimaryActionTriggered];
    
    [self addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(buttonDeselected:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    
#if TARGET_OS_TV
    _appImage.adjustsImageWhenAncestorFocused = YES;
#else
    // Rasterizing the cell layer increases rendering performance by quite a bit
    // but we want it unrasterized for tvOS where it must be scaled.
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    if (@available(iOS 13.4.1, *)) {
        // Allow the button style to change when moused over
        self.pointerInteractionEnabled = YES;
    }
#endif
    
    [self updateAppImage];
    
    return self;
}

- (void)didMoveToSuperview {
    // Start our update loop when we are added to our cell
    if (self.superview != nil) {
        [self updateLoop];
    }
}

- (void) appClicked:(UIView *)view {
    [_callback appClicked:_app view:view];
}

- (void) appLongClicked:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [_callback appLongClicked:_app view:self];
    }
}

#if !TARGET_OS_TV
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location {
    // We don't want to trigger the primary action at this point, so cancel
    // tracking touch on this view now. This will also have the (intended)
    // effect of removing the touch highlight on this view.
    [self cancelTrackingWithEvent:nil];
    
    [_callback appLongClicked:_app view:self];
    return nil;
}
#endif

- (void) updateAppImage {
    if (_appOverlay != nil) {
        [_appOverlay removeFromSuperview];
        _appOverlay = nil;
    }
    if (_appLabel != nil) {
        [_appLabel removeFromSuperview];
        _appLabel = nil;
    }
    
    BOOL noAppImage = false;
    
    // First check the memory cache
    UIImage* appImage = [_artCache objectForKey:_app];
    if (appImage == nil) {
        // Next try to load from the on disk cache
        appImage = [UIImage imageWithContentsOfFile:[AppAssetManager boxArtPathForApp:_app]];
        if (appImage != nil) {
            [_artCache setObject:appImage forKey:_app];
        }
    }
    
    if (appImage != nil) {
        // This size of image might be blank image received from GameStream.
        // TODO: Improve no-app image detection
        if (!(appImage.size.width == 130.f && appImage.size.height == 180.f) && // GFE 2.0
            !(appImage.size.width == 628.f && appImage.size.height == 888.f)) { // GFE 3.0
            [_appImage setImage:appImage];
        } else {
            noAppImage = true;
        }
    } else {
        noAppImage = true;
    }
    
#if !TARGET_OS_TV
    if (_lpzWide) {
        if (noAppImage) {
            [_appImage setImage:nil];
            _appLabel = [[UILabel alloc] initWithFrame:_appImage.frame];
            _appLabel.text = lpzFriendlyName(_app.name);
            _appLabel.textAlignment = NSTextAlignmentCenter;
            _appLabel.textColor = [LPZ_RGB(0xEFE7DE) colorWithAlphaComponent:0.35];
            _appLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightHeavy];
            [self insertSubview:_appLabel aboveSubview:_appImage];
        }
        [self lpzRefreshState];
        return;
    }
#endif
    if ([_app.id isEqualToString:_app.host.currentGame]) {
        // Only create the app overlay if needed
        _appOverlay = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Play"]];
        _appOverlay.layer.shadowColor = [UIColor blackColor].CGColor;
        _appOverlay.layer.shadowOffset = CGSizeMake(0, 0);
        _appOverlay.layer.shadowOpacity = 1;
        _appOverlay.layer.shadowRadius = 4.0;
        _appOverlay.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    if (noAppImage) {
        _appLabel = [[UILabel alloc] init];
        [_appLabel setTextColor:[UIColor whiteColor]];
        [_appLabel setText:_app.name];
        [_appLabel setFont:[UIFont systemFontOfSize:24]];
        [_appLabel setBaselineAdjustment:UIBaselineAdjustmentAlignCenters];
        [_appLabel setTextAlignment:NSTextAlignmentCenter];
        [_appLabel setLineBreakMode:NSLineBreakByWordWrapping];
        [_appLabel setNumberOfLines:0];
    }
    
    [self positionSubviews];
    
#if TARGET_OS_TV
    [_appImage.overlayContentView addSubview:_appLabel];
    [_appImage.overlayContentView addSubview:_appOverlay];
#else
    [self addSubview:_appLabel];
    [self addSubview:_appOverlay];
#endif
}

- (void) buttonSelected:(id)sender {
#if !TARGET_OS_TV
    if (_lpzWide) {
        [UIView animateWithDuration:0.12 animations:^{ self.transform = CGAffineTransformMakeScale(0.97, 0.97); self.alpha = 0.85; }];
        return;
    }
#endif
    _appImage.layer.opacity = 0.5f;
}
- (void) buttonDeselected:(id)sender {
#if !TARGET_OS_TV
    if (_lpzWide) {
        [UIView animateWithDuration:0.18 animations:^{ self.transform = CGAffineTransformIdentity; self.alpha = 1; }];
        return;
    }
#endif
    _appImage.layer.opacity = 1.0f;
}

- (void) positionSubviews {
    CGFloat padding = 5.f;
    CGSize frameSize = _appImage.frame.size;
    CGPoint center = _appImage.center;
    
    if (_appLabel != nil) {
        if (_appOverlay != nil) {
            _appOverlay.frame = CGRectMake(0, 0, frameSize.width / 3, frameSize.width / 3);
            _appOverlay.center = CGPointMake(frameSize.width / 2, padding + _appOverlay.frame.size.height / 2);
            
            [_appLabel setFrame:CGRectMake(padding, _appOverlay.frame.size.height + padding, frameSize.width - 2 * padding, frameSize.height - _appOverlay.frame.size.height - 2 * padding)];
        }
        else {
            [_appLabel setFrame:CGRectMake(padding, padding, frameSize.width - 2 * padding, frameSize.height - 2 * padding)];
        }
    }
    else if (_appOverlay != nil) {
        _appOverlay.frame = CGRectMake(0, 0, frameSize.width / 2, frameSize.width / 2);
        _appOverlay.center = center;
    }
}

- (void) updateLoop {
    // Stop immediately if the view has been detached
    if (self.superview == nil) {
        return;
    }
    
#if !TARGET_OS_TV
    if (_lpzWide) {
        [self lpzRefreshState];
        [self setAlpha:_app.hidden ? 0.4 : 1.0];
        [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
        return;
    }
#endif
    // Update the app image if neccessary
    if ((_appOverlay != nil && ![_app.id isEqualToString:_app.host.currentGame]) ||
        (_appOverlay == nil && [_app.id isEqualToString:_app.host.currentGame])) {
        [self updateAppImage];
    }
    
    // Show no shadow for hidden apps. Because we adjust the opacity of the
    // cells for hidden apps, it makes them look bad when the shadow draws
    // through the app tile.
    self.superview.layer.shadowOpacity = _app.hidden ? 0.0f : 0.5f;
    
    // Update opacity if neccessary
    [self setAlpha:_app.hidden ? 0.4 : 1.0];
    
    // Queue the next refresh cycle
    [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
}

@end
