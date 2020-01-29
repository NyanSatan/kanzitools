//
//  astris_api.h
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#ifndef astris_api_h
#define astris_api_h

#include "device.h"

#define APPLE_VID               0x05AC
#define KANZI_BOOT_LOADER_PID   0x1622
//#define APPLE_VID               0x0483
//#define KANZI_BOOT_LOADER_PID   0x3748
#define CHIMP_BOOT_LOADER_PID   0x162D
#define DUMP_LENGTH             0x100000

typedef enum {
    KBL_FLASH = 1,
    KBL_DUMP = 2,
    KBL_REBOOT = 3
} KBLRequestSelector;

int controlRequestKBL(kbl_device *device, KBLRequestSelector selector);


typedef enum {
    USBTransactionRead = 0,
    USBTransactionWrite = 1
} USBTransactionSelector;

int usbTransaction(USBTransactionSelector selector, uint64_t unknown, kbl_device *device, void *buffer, uint32_t *size);

#endif /* astris_api_h */
