//
//  UIAppView.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TemporaryApp.h"

@protocol AppCallback <NSObject>

- (void) appClicked:(TemporaryApp*)app view:(UIView*)view;
- (void) appLongClicked:(TemporaryApp*)app view:(UIView*)view;

@end

#if !TARGET_OS_TV
@interface UIAppView : UIButton <UIContextMenuInteractionDelegate>
#else
@interface UIAppView : UIButton
#endif

- (id) initWithApp:(TemporaryApp*)app cache:(NSCache*)cache andCallback:(id<AppCallback>)callback;
- (void) updateAppImage;
#if !TARGET_OS_TV
/// Lpz Remote: wide card (16:9 picture of the PC's screen + name bar) or, for power
/// actions, a compact button. Replaces the portrait box-art layout.
- (void) lpzLayoutWithSize:(CGSize)size power:(BOOL)power;
+ (BOOL) lpzIsPowerApp:(TemporaryApp*)app;
#endif

@end
