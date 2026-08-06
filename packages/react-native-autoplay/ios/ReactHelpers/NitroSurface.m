//
//  NitroSurface.m
//  Pods
//
//  Created by Manuel Auer on 28.11.25.
//

#import "NitroSurface.h"
#import <React/RCTInvalidating.h>
#import <React/RCTRootView.h>
#import <React/RCTSurface.h>
#import <React/RCTSurfaceHostingView.h>

@implementation NitroSurface

+ (void)stop:(nullable UIView *)view {
    if (view == nil) {
#if DEBUG
        NSLog(@"[AutoPlay] View is nil, ignoring");
#endif
        return;
    }

    if ([view isKindOfClass:[RCTSurfaceHostingView class]]) {
        RCTSurfaceHostingView *rootView =
            (RCTSurfaceHostingView *)view;
        
        if (rootView == nil) {
#if DEBUG
            NSLog(@"[AutoPlay] rootView == nil, cannot stop");
#endif
            return;
        }
        
        [rootView.surface stop];
    }

#if DEBUG
    NSLog(@"[AutoPlay] View is not recognized type, ignoring");
#endif
}

@end
