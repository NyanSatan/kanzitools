//
//  device.m
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#include "include/device.h"


int find_device(uint16_t vid, uint16_t pid, kbl_device **device, NSString **name) {
    mach_port_t masterPort = 0;
    kern_return_t err = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (err) {
        return -1;
    }
    
    NSMutableDictionary* matchingDict = (__bridge NSMutableDictionary*)IOServiceMatching(kIOUSBDeviceClassName);
    if (matchingDict == nil) {
        mach_port_deallocate(mach_task_self(), masterPort);
        return -1;
    }
    
    [matchingDict setValue:[NSNumber numberWithShort:vid] forKey:[NSString stringWithCString:kUSBVendorID encoding:NSASCIIStringEncoding]];
    [matchingDict setValue:[NSNumber numberWithShort:pid] forKey:[NSString stringWithCString:kUSBProductID encoding:NSASCIIStringEncoding]];
    
    io_iterator_t iterator = 0;
    err = IOServiceGetMatchingServices(masterPort, (__bridge CFMutableDictionaryRef)matchingDict, &iterator);
    if (err) {
        return -1;
    }
    

    io_service_t usbDeviceRef = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    
    IOUSBDeviceInterface **deviceInterface = NULL;
    
    if (usbDeviceRef == 0) {
        return -1;
    } else {
        NSString *productName = (__bridge NSString*) (CFStringRef) IORegistryEntrySearchCFProperty(usbDeviceRef,
                                                                                                   kIOServicePlane,
                                                                                                   CFSTR("USB Product Name"),
                                                                                                   kCFAllocatorDefault,
                                                                                                   kIORegistryIterateRecursively);
        
        NSString *serialNumber = (__bridge NSString*) (CFStringRef) IORegistryEntrySearchCFProperty(usbDeviceRef,
                                                                                                    kIOServicePlane,
                                                                                                    CFSTR(kUSBSerialNumberString),
                                                                                                    kCFAllocatorDefault,
                                                                                                    kIORegistryIterateRecursively);
        
        *name = [NSString stringWithFormat:@"%@ %@", productName, serialNumber];
        
        SInt32 score;
        IOCFPlugInInterface** plugInInterface;
        
        err = IOCreatePlugInInterfaceForService(usbDeviceRef,
                                                kIOUSBDeviceUserClientTypeID,
                                                kIOCFPlugInInterfaceID,
                                                &plugInInterface, &score);
        if (err != kIOReturnSuccess || plugInInterface == 0) {
            IOObjectRelease(usbDeviceRef);
            printf("IOCreatePlugInInterfaceForService returned 0x%08x", err);
            return -2;
        }
        else {
            err = (*plugInInterface)->QueryInterface(plugInInterface,
                                                     CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                                     (LPVOID*)&deviceInterface);

            
            
            (*plugInInterface)->Release(plugInInterface);
            
            if (err || deviceInterface == NULL) {
                printf("QueryInterface returned %x\n", err);
                return -3;
            }
        }
    }
    
    IOObjectRelease(usbDeviceRef);
    mach_port_deallocate(mach_task_self(), masterPort);
    
    
    IOUSBFindInterfaceRequest interface_request;
    interface_request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    
    (*deviceInterface)->CreateInterfaceIterator(deviceInterface, &interface_request, &iterator);
    
    io_service_t interfaceRef = IOIteratorNext(iterator);
    
    if (interfaceRef == 0) {
        printf("USB device has no interfaces\n");
        return -1;
    }
    
    SInt32 score;
    IOCFPlugInInterface** plugInInterface;
    
    IOUSBInterfaceInterface550 **interfaceInterface = 0;
    
    err = IOCreatePlugInInterfaceForService(interfaceRef,
                                            kIOUSBInterfaceUserClientTypeID,
                                            kIOCFPlugInInterfaceID,
                                            &plugInInterface, &score);
    if (err != kIOReturnSuccess || plugInInterface == 0) {
        printf("IOCreatePlugInInterfaceForService returned 0x%08x", err);
        return -1;
    }
    else {
        
        err = (*plugInInterface)->QueryInterface(plugInInterface,
                                                 CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
                                                 (LPVOID*)&interfaceInterface);
        
        
        

        (*plugInInterface)->Release(plugInInterface);
        
        if (err || interfaceInterface == NULL) {
            printf("QueryInterface returned %x\n", err);
            return -1;
        }
    }
    
    
    (*interfaceInterface)->USBInterfaceOpen(interfaceInterface);
    
    int pipe_counter = 1;
    
    int in_pipe = 0;
    int out_pipe = 0;
    
    do {
        
        uint8_t direction = 0;
        uint8_t number = 0;
        uint8_t tranferType = 0;
        uint16_t maxPacketSize = 0;
        uint8_t interval = 0;
        
        (*interfaceInterface)->GetPipeProperties(interfaceInterface, pipe_counter, &direction, &number, &tranferType, &maxPacketSize, &interval);
        
        if (direction == 1 && tranferType == 2) {
            printf("dealing with BULK IN pipe\n");
            in_pipe = pipe_counter;
            (*interfaceInterface)->ClearPipeStallBothEnds(interfaceInterface, pipe_counter);
        }
        
        if (direction == 0 && tranferType == 2) {
            printf("dealing with BULK OUT pipe\n");
            out_pipe = pipe_counter;
            (*interfaceInterface)->ClearPipeStallBothEnds(interfaceInterface, pipe_counter);
        }
        
        pipe_counter++;
        
    } while (pipe_counter != 3);
    
    
    IOObjectRelease(interfaceRef);
    IOObjectRelease(iterator);
    
    
    kbl_device *device_desc = malloc(sizeof(kbl_device));
    if (!device_desc) {
        printf("out of memory!");
        return -1;
    }
    
    device_desc->device = deviceInterface;
    device_desc->interface = interfaceInterface;
    device_desc->out_pipe = out_pipe;
    device_desc->in_pipe = in_pipe;
    
    *device = device_desc;
    
    return 0;
    
}

void free_device(kbl_device *device) {
    (*(device->device))->Release(device->device);
    (*(device->interface))->Release(device->interface);
    free(device);
}
