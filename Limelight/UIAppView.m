//
//  UIAppView.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "UIAppView.h"
#import "AppAssetManager.h"
#import "Moonlight-Swift.h"

static const float REFRESH_CYCLE = 1.0f;

@implementation UIAppView {
    TemporaryApp* _app;
    UILabel* _appLabel;
    UIImageView* _appOverlay;
    UIImageView* _appImage;
    NSCache* _artCache;
    id<AppCallback> _callback;
    UIView* _swiftCardView;
    UIMotionEffectGroup* _parallaxGroup;
    CATransform3D _restingTransform;
    BOOL _capturedResting;
    BOOL _showingPlayIcon;
}

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
    
    //_appImage = [[UIImageView alloc] initWithFrame:self.frame];
    //[_appImage setImage:noImage];
    //[self addSubview:_appImage];
    
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
    //_appImage.adjustsImageWhenAncestorFocused = YES;
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
    self.backgroundColor = [UIColor clearColor];
    
    return self;
}

- (void)didMoveToSuperview {
    if (self.superview != nil) {
        // Ensure only one update loop is ever pending (the view can be
        // re-added on cell reuse, which would otherwise stack loops).
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLoop) object:self];
        [self updateLoop];
    }
    else {
        // Detached: stop the pending loop promptly instead of waiting for the
        // next tick to notice superview == nil.
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateLoop) object:self];
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
    UIImage* appImage = [_artCache objectForKey:_app];
    if (appImage == nil) {
        appImage = [UIImage imageWithContentsOfFile:[AppAssetManager boxArtPathForApp:_app]];
        if (appImage != nil) {
            [_artCache setObject:appImage forKey:_app];
        }
    }
    
    // 1. LE FILTRE ANTI-FAUSSES IMAGES
    if (appImage != nil) {
        if ((appImage.size.width == 130.f && appImage.size.height == 180.f) ||
            (appImage.size.width == 628.f && appImage.size.height == 888.f)) {
            appImage = nil; // On force à nil pour déclencher le texte en Swift
        }
    }
    
    BOOL isPlaying = [_app.id isEqualToString:_app.host.currentGame];
    
    if (_swiftCardView != nil) {
        [_swiftCardView removeFromSuperview];
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    _swiftCardView = [LiquidGlassCardBridge createCardWithTitle:_app.name image:appImage isPlaying:isPlaying];
    _swiftCardView.frame = self.bounds;

    [self addSubview:_swiftCardView];
    _showingPlayIcon = isPlaying;
}

- (void) buttonSelected:(id)sender {
    _swiftCardView.alpha = 0.5f; // On utilise la vue Swift maintenant !
}
- (void) buttonDeselected:(id)sender {
    _swiftCardView.alpha = 1.0f;
}

- (void) positionSubviews {
    CGFloat padding = 5.f;
    CGSize frameSize = self.bounds.size;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
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
    
    // Update the app image only when the play state actually changes
    BOOL isPlaying = [_app.id isEqualToString:_app.host.currentGame];
    if (isPlaying != _showingPlayIcon) {
        [self updateAppImage];
    }
    
    // Show no shadow for hidden apps. Because we adjust the opacity of the
    // cells for hidden apps, it makes them look bad when the shadow draws
    // through the app tile.
    // self.superview.layer.shadowOpacity = _app.hidden ? 0.0f : 0.5f;
    
    // Update opacity if neccessary
    [self setAlpha:_app.hidden ? 0.4 : 1.0];
    
    // Queue the next refresh cycle
    [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
}

- (void)setCardFocused:(BOOL)focused withCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    self.clipsToBounds = NO;

    // Snapshot the resting transform exactly once, before we ever mutate it.
    if (!_capturedResting) {
        _restingTransform = self.layer.transform;
        _capturedResting = YES;
    }

    if (focused) {
        if (_parallaxGroup == nil) {
            UIInterpolatingMotionEffect *tiltX = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform.rotation.y" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
            tiltX.minimumRelativeValue = @(-0.15);
            tiltX.maximumRelativeValue = @(0.15);
            UIInterpolatingMotionEffect *tiltY = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform.rotation.x" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
            tiltY.minimumRelativeValue = @(0.15);
            tiltY.maximumRelativeValue = @(-0.15);
            _parallaxGroup = [[UIMotionEffectGroup alloc] init];
            _parallaxGroup.motionEffects = @[tiltX, tiltY];
        }

        [coordinator addCoordinatedAnimations:^{
            CATransform3D transform = self->_restingTransform;
            transform.m34 = -1.0 / 500.0;
            transform = CATransform3DScale(transform, 1.15, 1.15, 1.0);
            self.layer.transform = transform;

            self.layer.shadowColor = [UIColor whiteColor].CGColor;
            self.layer.shadowOffset = CGSizeMake(0, 0);
            self.layer.shadowOpacity = 0.8;
            self.layer.shadowRadius = 20.0;

            self.layer.cornerRadius = 12.0;
            self.layer.borderColor = [UIColor whiteColor].CGColor;
            self.layer.borderWidth = 4.0;

            [self addMotionEffect:self->_parallaxGroup];
        } completion:nil];
    } else {
        [coordinator addCoordinatedAnimations:^{
            self.layer.transform = self->_restingTransform;
            self.layer.shadowOpacity = 0.0;
            self.layer.borderWidth = 0.0;

            if (self->_parallaxGroup != nil) {
                [self removeMotionEffect:self->_parallaxGroup];
            }
        } completion:nil];
    }
}


@end
