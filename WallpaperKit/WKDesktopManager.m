//
//  WKDesktopManager.m
//  WallpaperKit
//
//  Created by Naville Zhang on 2017/1/9.
//  Copyright © 2017年 NavilleZhang. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#include <unistd.h>
#include <CoreServices/CoreServices.h>
#include <ApplicationServices/ApplicationServices.h>
#import "WKDesktopManager.h"
#import "WKOcclusionStateWindow.h"

/* Reverse engineered Space API; stolen from xmonad */
typedef void *CGSConnectionID;
extern CGSConnectionID _CGSDefaultConnection(void);
#define CGSDefaultConnection _CGSDefaultConnection()

typedef uint64_t CGSSpace;
typedef enum _CGSSpaceType {
    kCGSSpaceUser,
    kCGSSpaceFullscreen,
    kCGSSpaceSystem,
    kCGSSpaceUnknown
} CGSSpaceType;
typedef enum _CGSSpaceSelector {
    kCGSSpaceCurrent = 5,
    kCGSSpaceOther = 6,
    kCGSSpaceAll = 7
} CGSSpaceSelector;

extern CFArrayRef CGSCopySpaces(const CGSConnectionID cid, CGSSpaceSelector type);
extern CGSSpaceType CGSSpaceGetType(const CGSConnectionID cid, CGSSpace space);



@implementation WKDesktopManager{
    NSUInteger lastActiveSpaceID;
    WKOcclusionStateWindow* DummyWindow;//Dummy Transparent Window at kCGDesktopIconWindowLevel+1 for OcclusionState Observe
}
+ (instancetype)sharedInstance{
    static WKDesktopManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WKDesktopManager alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}
-(instancetype)init{
    self=[super init];
    self.windows=[NSMutableDictionary dictionary];
    self->lastActiveSpaceID=INT_MAX;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOSChange:) name:OSNotificationCenterName object:nil];
    self->DummyWindow=[WKOcclusionStateWindow new];
    return self;
}
-(void)stop{
    for(NSNumber* key in self.windows.allKeys){
        for(WKDesktop* currentDesktop in [self.windows objectForKey:key]){
            [currentDesktop close];
            [[self.windows objectForKey:key] removeObject:currentDesktop];
        }
    }
    [self.windows removeAllObjects];

    self->lastActiveSpaceID=INT_MAX;
}
-(NSMutableArray<WKDesktop*>*)desktopsForSpaceID:(NSUInteger)spaceID{
    if([self.windows.allKeys containsObject:[NSNumber numberWithInteger:spaceID]]){
        return [self.windows objectForKey:[NSNumber numberWithInteger:spaceID]];
    }
    else{
        return nil;
    }
}
-(void)DisplayDesktop:(WKDesktop*)wk{
    [wk orderFront:nil];
    [wk play];
    [self->DummyWindow orderFront:nil];
    //Keep Current Video Playing if next Window is not playing video,etc
    for(id key in self.windows.allKeys){
            for( WKDesktop* currentDesktop in [self.windows objectForKey:key])
            {
                if(![currentDesktop isEqualTo:wk] && wk.currentView.requiresExclusiveBackground==YES&&currentDesktop.currentView.requiresExclusiveBackground==YES){
                    //Pause Old "Main" view;
                    [currentDesktop close];
                    [[self.windows objectForKey:key] removeObject:wk];
                }
                
                if([currentDesktop isEqualTo:wk]){//Ignore next space's WKDesktop
                    continue;
                }
                if(currentDesktop.currentView.requiresConsistentAccess==YES && wk.currentView.requiresConsistentAccess==NO){
                    //Old view needs consistent access while the new one doesn't. Leave it running
                }
                else{
                    [currentDesktop pause];
                }
            }
    }
    
}
-(NSUInteger)currentSpaceID{
    CFArrayRef spaces = CGSCopySpaces(CGSDefaultConnection, kCGSSpaceCurrent);
    // CFArrayRef spaces = CGSCopySpaces(CGSDefaultConnection, kCGSSpaceAll);
    long count = CFArrayGetCount(spaces);
    
    long ii;
    for (ii = count - 1; ii >= 0; ii--) {
        CGSSpace spaceId = [(__bridge id)CFArrayGetValueAtIndex(spaces, ii) intValue];
        if (CGSSpaceGetType(CGSDefaultConnection, spaceId) == kCGSSpaceSystem)
            continue;
        CFRelease(spaces);
        return spaceId;
    }
    CFRelease(spaces);
    return WRONG_WINDOW_ID;

}
-(void)discardSpaceID:(NSUInteger)spaceID{
    if([self.windows.allKeys containsObject:[NSNumber numberWithInteger:spaceID]]){
        for(WKDesktop* win in  [self.windows objectForKey:[NSNumber numberWithInteger:spaceID]]){
            [win close];
            [self->_windows removeObjectForKey:[NSNumber numberWithInteger:spaceID]];
        }
    }
    
}
-(void)handleOSChange:(NSNotification*)notification{
    BOOL isVisible=[[notification.userInfo objectForKey:@"Visibility"] boolValue];
    NSNumber* newSpaceID=[notification.userInfo objectForKey:@"CurrentSpaceID"];
    for(id key in self.windows.allKeys){
        if(isVisible==NO){
            for(WKDesktop* wk in [self.windows objectForKey:key]){
                [wk pause];
            }
            continue;
        }
        if([key isEqualTo:newSpaceID]){
            for(WKDesktop* wk in [self.windows objectForKey:key]){
                [wk play];
            }
        }
        else{
            for(WKDesktop* wk in [self.windows objectForKey:key]){
                [wk pause];
            }
        }
    }
}
-(WKDesktop*)createDesktopWithSpaceID:(NSUInteger)SpaceID andRender:(NSDictionary*)render{
      WKDesktop*  wk=[[WKDesktop alloc] initWithContentRect:CGDisplayBounds(CGMainDisplayID()) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        if(render==nil|| ![render.allKeys containsObject:@"Render"]){
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Render Invalid" userInfo:render];
        }
        [wk renderWithEngine:[render objectForKey:@"Render"] withArguments:render];
        self.activeWallpaperView=wk.currentView;
        if(self.windows[[NSNumber numberWithInteger:SpaceID]]==nil){
            self.windows[[NSNumber numberWithInteger:SpaceID]]=[NSMutableArray array];
        }
    
        [self.windows[[NSNumber numberWithInteger:SpaceID]] addObject:wk];
    return wk;
}
@end
