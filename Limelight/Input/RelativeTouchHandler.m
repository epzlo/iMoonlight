//
//  RelativeTouchHandler.m
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "RelativeTouchHandler.h"
#if !TARGET_OS_TV
#import "PadOutput.h"
#endif

#include <Limelight.h>

static const int REFERENCE_WIDTH = 1280;
static const int REFERENCE_HEIGHT = 720;

#if !TARGET_OS_TV
// Lpz Remote: a finger that starts moving within this distance (screen points) of the cursor
// moves the cursor from where it is; farther away, the cursor jumps under the finger and follows it.
static const CGFloat NEAR_CURSOR_DISTANCE = 70;
// O cursor fica esta distância (pontos de tela) acima do dedo, para o dedo não cobrir a ponta da seta.
static const CGFloat CURSOR_LIFT = 48;
typedef NS_ENUM(NSInteger, HybridMode) { HybridUndecided, HybridNear, HybridFar };
#endif

@implementation RelativeTouchHandler {
    CGPoint touchLocation, originalLocation;
    BOOL touchMoved;
    BOOL isDragging;
    NSTimer* dragTimer;
    NSUInteger peakTouchCount;
#if !TARGET_OS_TV
    HybridMode hybridMode;
    CGPoint hybridCursorStart;
#endif
    
#if TARGET_OS_TV
    UIGestureRecognizer* remotePressRecognizer;
    UIGestureRecognizer* remoteLongPressRecognizer;
#endif
    
    UIView* view;
}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->view = view;
    
#if TARGET_OS_TV
    remotePressRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(remoteButtonPressed:)];
    remotePressRecognizer.allowedPressTypes = @[@(UIPressTypeSelect)];
    
    remoteLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(remoteButtonLongPressed:)];
    remoteLongPressRecognizer.allowedPressTypes = @[@(UIPressTypeSelect)];
    
    [self->view addGestureRecognizer:remotePressRecognizer];
    [self->view addGestureRecognizer:remoteLongPressRecognizer];
#endif
    
    return self;
}

- (BOOL)isConfirmedMove:(CGPoint)currentPoint from:(CGPoint)originalPoint {
    // Movements of greater than 5 pixels are considered confirmed
    return hypotf(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y) >= 5;
}

- (void)onDragStart:(NSTimer*)timer {
    if (!touchMoved && !isDragging){
        isDragging = true;
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    touchMoved = false;
#if !TARGET_OS_TV
    hybridMode = HybridUndecided;
#endif
    peakTouchCount = [[event allTouches] count];
    if ([[event allTouches] count] == 1) {
        UITouch *touch = [[event allTouches] anyObject];
        originalLocation = touchLocation = [touch locationInView:view];
        if (!isDragging) {
            dragTimer = [NSTimer scheduledTimerWithTimeInterval:0.650
                                                     target:self
                                                   selector:@selector(onDragStart:)
                                                   userInfo:nil
                                                    repeats:NO];
        }
    }
    else if ([[event allTouches] count] == 2) {
        CGPoint firstLocation = [[[[event allTouches] allObjects] objectAtIndex:0] locationInView:view];
        CGPoint secondLocation = [[[[event allTouches] allObjects] objectAtIndex:1] locationInView:view];
        
        originalLocation = touchLocation = CGPointMake((firstLocation.x + secondLocation.x) / 2, (firstLocation.y + secondLocation.y) / 2);
    }
}

#if !TARGET_OS_TV
/// O ponto da imagem um pouco acima do dedo (a distância é fixa na tela, com ou sem zoom).
- (CGPoint)liftedPoint:(CGPoint)point {
    CGPoint onScreen = [view convertPoint:point toView:nil];
    onScreen.y -= CURSOR_LIFT;
    return [view convertPoint:onScreen fromView:nil];
}

// One-finger movement while the app tracks the cursor. Returns NO to fall back to relative motion.
- (BOOL)hybridMoveTo:(CGPoint)currentLocation {
    PadOutput* out = [PadOutput shared];
    if (!out.tracksCursor || ![view isKindOfClass:[StreamView class]]) return NO;
    StreamView* sv = (StreamView*)view;
    CGSize ss = out.streamSize;
    
    if (hybridMode == HybridUndecided) {
        // A tap never moves the cursor: decide only once the finger has really moved.
        if (![self isConfirmedMove:currentLocation from:originalLocation]) return YES;
        if (isDragging) {
            hybridMode = HybridNear;   // holding the button: always drag from where the cursor is
        } else {
            // Compare on screen, so the local zoom of the image counts.
            CGPoint cursorInView = [sv viewPointForStreamPixel:out.cursorPosition streamSize:ss];
            CGPoint a = [view convertPoint:cursorInView toView:nil];
            CGPoint b = [view convertPoint:[self liftedPoint:originalLocation] toView:nil];
            hybridMode = hypot(a.x - b.x, a.y - b.y) <= NEAR_CURSOR_DISTANCE ? HybridNear : HybridFar;
        }
        hybridCursorStart = out.cursorPosition;
    }
    
    if (hybridMode == HybridFar) {
        [out moveCursorTo:[sv streamPixelForViewPoint:[self liftedPoint:currentLocation] streamSize:ss]];
    } else {
        // Same distance the finger travelled over the image, from where the cursor was.
        CGPoint p0 = [sv streamPixelForViewPoint:originalLocation streamSize:ss];
        CGPoint p1 = [sv streamPixelForViewPoint:currentLocation streamSize:ss];
        [out moveCursorTo:CGPointMake(hybridCursorStart.x + p1.x - p0.x, hybridCursorStart.y + p1.y - p0.y)];
    }
    return YES;
}
#endif

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([[event allTouches] count] == 1) {
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint currentLocation = [touch locationInView:view];
#if !TARGET_OS_TV
        if ([self hybridMoveTo:currentLocation]) {
            if ([self isConfirmedMove:currentLocation from:originalLocation]) {
                touchMoved = true;
            }
            touchLocation = currentLocation;
            return;
        }
#endif
        
        if (touchLocation.x != currentLocation.x ||
            touchLocation.y != currentLocation.y)
        {
            int deltaX = (currentLocation.x - touchLocation.x) * (REFERENCE_WIDTH / view.bounds.size.width);
            int deltaY = (currentLocation.y - touchLocation.y) * (REFERENCE_HEIGHT / view.bounds.size.height);
            
            if (deltaX != 0 || deltaY != 0) {
                LiSendMouseMoveEvent(deltaX, deltaY);
                touchLocation = currentLocation;
                
                // If we've moved far enough to confirm this wasn't just human/machine error,
                // mark it as such.
                if ([self isConfirmedMove:touchLocation from:originalLocation]) {
                    touchMoved = true;
                }
            }
        }
    } else if ([[event allTouches] count] == 2) {
        CGPoint firstLocation = [[[[event allTouches] allObjects] objectAtIndex:0] locationInView:view];
        CGPoint secondLocation = [[[[event allTouches] allObjects] objectAtIndex:1] locationInView:view];
        
        CGPoint avgLocation = CGPointMake((firstLocation.x + secondLocation.x) / 2, (firstLocation.y + secondLocation.y) / 2);
        if (touchLocation.y != avgLocation.y) {
            LiSendHighResScrollEvent((avgLocation.y - touchLocation.y) * 10);
        }

        // If we've moved far enough to confirm this wasn't just human/machine error,
        // mark it as such.
        if ([self isConfirmedMove:firstLocation from:originalLocation]) {
            touchMoved = true;
        }
        
        touchLocation = avgLocation;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [dragTimer invalidate];
    dragTimer = nil;
    if (isDragging) {
        isDragging = false;
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    } else if (!touchMoved) {
        if (peakTouchCount == 2) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                Log(LOG_D, @"Sending right mouse button press");
                
                LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
                
                // Wait 100 ms to simulate a real button press
                usleep(100 * 1000);
                
                LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            });
        } else if (peakTouchCount == 1) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                if (!self->isDragging){
                    Log(LOG_D, @"Sending left mouse button press");
                    
                    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
                    
                    // Wait 100 ms to simulate a real button press
                    usleep(100 * 1000);
                }
                self->isDragging = false;
                LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            });
        }
    }
    
    // We we're moving from 2+ touches to 1. Synchronize the current position
    // of the active finger so we don't jump unexpectedly on the next touchesMoved
    // callback when finger 1 switches on us.
    if ([[event allTouches] count] - [touches count] == 1) {
        NSMutableSet *activeSet = [[NSMutableSet alloc] initWithCapacity:[[event allTouches] count]];
        [activeSet unionSet:[event allTouches]];
        [activeSet minusSet:touches];
        touchLocation = [[activeSet anyObject] locationInView:view];
        
        // Mark this touch as moved so we don't send a left mouse click if the user
        // right clicks without moving their other finger.
        touchMoved = true;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [dragTimer invalidate];
    dragTimer = nil;
    if (isDragging) {
        isDragging = false;
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    }
    peakTouchCount = 0;
}

#if TARGET_OS_TV
- (void)remoteButtonPressed:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        Log(LOG_D, @"Sending left mouse button press");
        
        // Mark this as touchMoved to avoid a duplicate press on touch up
        self->touchMoved = true;
        
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
        
        // Wait 100 ms to simulate a real button press
        usleep(100 * 1000);
            
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    });
}
- (void)remoteButtonLongPressed:(id)sender {
    Log(LOG_D, @"Holding left mouse button");
    
    isDragging = true;
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
}
#endif

@end
