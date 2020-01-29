//
//  reset.m
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "include/device.h"
#include "include/astris_api.h"

int reset() {
    printf("looking for KanziBoot 0x%04x:0x%04x\n", APPLE_VID, KANZI_BOOT_LOADER_PID);
    
    kbl_device *device = NULL;
    NSString *name = nil;
    
    if (find_device(APPLE_VID, KANZI_BOOT_LOADER_PID, &device, &name) != 0) {
        printf("failed to find KanziBoot\n");
        return -1;
    }
    
    printf("found device: %s\n", [name UTF8String]);
    
    if (controlRequestKBL(device, KBL_REBOOT) == 0) {
        printf("reset request sent\n");
    } else {
        printf("reset request failed\n");
        free_device(device);
        return -1;
    }
    
    free_device(device);
    
    return 0;
}
