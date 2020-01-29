//
//  device.h
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#ifndef device_h
#define device_h

#import <Foundation/Foundation.h>

#include <mach/mach.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>

typedef struct kbl_device_struct {
    IOUSBDeviceInterface **device;
    IOUSBInterfaceInterface550 **interface;
    uint8_t out_pipe;
    uint8_t in_pipe;
} kbl_device;

int find_device(uint16_t vid, uint16_t pid, kbl_device **device, NSString **name);
void free_device(kbl_device *device);

#endif /* device_h */
