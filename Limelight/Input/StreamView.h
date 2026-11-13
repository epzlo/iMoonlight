//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "ControllerSupport.h"
#import "OnScreenControls.h"
#import "Moonlight-Swift.h"
#import "StreamConfiguration.h"

@protocol UserInteractionDelegate <NSObject>

- (void) userInteractionBegan;
- (void) userInteractionEnded;

@end

#if TARGET_OS_TV
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate>
#else
@interface StreamView : UIView <X1KitMouseDelegate, UITextFieldDelegate, UIPointerInteractionDelegate>
#endif

- (void) setupStreamView:(ControllerSupport*)controllerSupport
     interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate
                  config:(StreamConfiguration*)streamConfig;
- (void) showOnScreenControls;
- (OnScreenControlsLevel) getCurrentOscState;

// Hides the on-screen gamepad while the portrait trackpad layout is in use,
// and brings back the previous level afterwards.
- (void) setOnScreenControlsSuppressed:(BOOL)suppressed;

#if !TARGET_OS_TV
- (void) updateCursorLocation:(CGPoint)location isMouse:(BOOL)isMouse;
/// Lpz Remote: a point in this view, in stream pixels (streamSize = stream resolution).
- (CGPoint) streamPixelForViewPoint:(CGPoint)point streamSize:(CGSize)streamSize;
/// A point in stream pixels, back in this view's coordinates.
- (CGPoint) viewPointForStreamPixel:(CGPoint)pixel streamSize:(CGSize)streamSize;
#endif

@end
