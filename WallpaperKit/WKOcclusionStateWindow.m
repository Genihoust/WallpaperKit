//
//  WKOcclusionStateWindow.m
//  WallpaperKit
//
//  Created by Naville Zhang on 18/02/2017.
//  Copyright © 2017 NavilleZhang. All rights reserved.
//

#import "WKOcclusionStateWindow.h"
#import "WKDesktopManager.h"
@implementation WKOcclusionStateWindow
+ (instancetype)sharedInstance{
    static WKOcclusionStateWindow *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WKOcclusionStateWindow alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}
-(instancetype)init{
    CGRect rawSize=[NSScreen mainScreen].visibleFrame;
    self=[super initWithContentRect:NSMakeRect((rawSize.origin.x+rawSize.size.width)/8, (rawSize.origin.y+rawSize.size.height)/8, 3*rawSize.size.width/4, 3*rawSize.size.height/4) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
    [self setIgnoresMouseEvents:YES];
    self.delegate=self;
    [self setLevel:kCGDesktopIconWindowLevel+1];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:YES];
    self.collectionBehavior=(NSWindowCollectionBehaviorCanJoinAllSpaces |
                             NSWindowCollectionBehaviorStationary |
                             NSWindowCollectionBehaviorIgnoresCycle);
    return self;
}
-(BOOL)canBecomeKeyWindow{
    return NO;
}
-(BOOL)canBecomeMainWindow{
    return NO;
}
-(BOOL)canBeVisibleOnAllSpaces{
    return YES;
}
- (void)windowDidChangeOcclusionState:(NSNotification *)notification{
    BOOL isVisible;
    if(self.occlusionState & NSWindowOcclusionStateVisible){
        isVisible=YES;
    }
    else{
        isVisible=NO;
    }
    NSDictionary* UserInfo=@{@"CurrentSpaceID":[NSNumber numberWithInteger:[[WKDesktopManager sharedInstance] currentSpaceID]],@"Visibility":[NSNumber numberWithBool:isVisible]};
    [[NSNotificationCenter defaultCenter] postNotificationName:OSNotificationCenterName object:nil  userInfo:UserInfo];
}
@end