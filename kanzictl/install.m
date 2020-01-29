//
//  install.m
//  kanzictl
//
//  Created by noone on 12/17/19.
//  Copyright © 2019 noone. All rights reserved.
//

#import <Foundation/Foundation.h>

int install(const char *path) {
    if (getuid() != 0) {
        printf("This must be run as root!\n");
        return -1;
    }
    
    printf("Installing...\n");
    
    NSError *error = nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:@"/usr/local/bin/kanzictl" error:&error];
    
    [[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithUTF8String:path] toPath:@"/usr/local/bin/kanzictl" error:&error];
    
    if (error) {
        printf("Failed to copy the binary\n");
        return -1;
    }
    
    NSDictionary *launchDaemon = @{
        @"Label" : @"com.nyansatan.kanzictl",
        @"RunAtLoad" : @YES,
        @"KeepAlive" : @YES,
        @"ProgramArguments" : @[
            @"/usr/local/bin/kanzictl",
            @"patch",
            @"--daemon"
        ]
    };
    
    if (![launchDaemon writeToFile:@"/Library/LaunchDaemons/com.nyansatan.kanzictl.plist" atomically:NO]) {
        printf("Failed to create LaunchDaemon\n");
        return -1;
    }
    
    printf("\n");
    printf("To load daemon:\n");
    printf("\tsudo launchctl load %s\n", [@"/Library/LaunchDaemons/com.nyansatan.kanzictl.plist" UTF8String]);
    printf("To stop daemon:\n");
    printf("\tsudo launchctl unload %s\n", [@"/Library/LaunchDaemons/com.nyansatan.kanzictl.plist" UTF8String]);
    printf("\n");
    
    printf("Done installing\n");
    
    return 0;
}
