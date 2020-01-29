//
//  dump.m
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "include/dump.h"
#include "include/astris_api.h"
#include "include/device.h"

int dump(const char *output) {
    int result = 0;
    kbl_device *device = NULL;
    NSString *name = nil;
    void *buffer = NULL;
    
    
    if (access(output, F_OK) == 0) {
        printf("such image is already at the destination, won't overwrite\n");
        return -1;
    }
    
    printf("looking for KanziBoot 0x%04x:0x%04x\n", APPLE_VID, KANZI_BOOT_LOADER_PID);

    
    if (find_device(APPLE_VID, KANZI_BOOT_LOADER_PID, &device, &name) != 0) {
        printf("failed to find KanziBoot\n");
        result = -1;
        goto out;
    }
    
    printf("found device: %s\n", [name UTF8String]);
    
    
    if (controlRequestKBL(device, KBL_DUMP) == 0) {
        printf("dump request sent\n");
    } else {
        printf("dump request failed\n");
        result = -1;
        goto out;
    }

    
    uint32_t size = DUMP_LENGTH;
    
    buffer = malloc(size);
    if (!buffer) {
        printf("out of memory!\n");
        result = -1;
        goto out;
    }
    
    int status = 0;
    
    if ((status = usbTransaction(USBTransactionRead, 0, device, buffer, &size)) != 0x0) {
        printf("USB transaction failed: %d\n", status);
        result = -1;
        goto out;
    }
    
    int fd = open(output, O_WRONLY | O_CREAT, 0644);
    if (fd < 0) {
        printf("failed to open output file\n");
        result = -1;
        goto out;
    }
    
    if (pwrite(fd, buffer, DUMP_LENGTH, 0) < 0) {
        printf("failed to write to output file\n");
        result = -1;
        goto out;
    }
    
    printf("DONE\n");
    
    out:
        if (buffer) free(buffer);
        if (device) free_device(device);
    
        return result;
}
