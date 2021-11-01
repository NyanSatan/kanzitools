//
//  KBLDeviceMenu.m
//  kblctl
//
//  Created by noone on 10/24/21.
//

#import "KBLDeviceMenu.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

@implementation KBLDeviceMenu

+ (KBLDeviceMenu *)deviceWithService:(io_service_t)service {
    KBLDeviceMenu *device = [[KBLDeviceMenu alloc] init];
    
    [device setService:service];
    
    NSString *productName = (__bridge NSString*)(CFStringRef)IORegistryEntrySearchCFProperty(service,
                                                                                             kIOServicePlane,
                                                                                             CFSTR("USB Product Name"),
                                                                                             kCFAllocatorDefault,
                                                                                             kIORegistryIterateRecursively);
    if (!productName) {
        printf("failed to retrieve product name\n");
        return nil;
    }
    
    [device setName:productName];
    
    
    NSString *serialNumber = (__bridge NSString*)(CFStringRef)IORegistryEntrySearchCFProperty(service,
                                                                                              kIOServicePlane,
                                                                                              CFSTR(kUSBSerialNumberString),
                                                                                              kCFAllocatorDefault,
                                                                                              kIORegistryIterateRecursively);
    
    if (!serialNumber) {
        printf("failed to retrieve SN\n");
        return nil;
    }
    
    [device setSn:serialNumber];
    
    
    NSNumber *productID = (__bridge NSNumber*)(CFNumberRef)IORegistryEntrySearchCFProperty(service,
                                                                                           kIOServicePlane,
                                                                                           CFSTR(kUSBProductID),
                                                                                           kCFAllocatorDefault,
                                                                                           kIORegistryIterateRecursively);
    
    if (!productID) {
        printf("failed to retrieve SN\n");
        return nil;
    }
    
    uint16_t pid_raw = [productID unsignedShortValue];

    for (int i = 0; i < NUM_OF_KBL_CONFIGS; i++) {
        const kbl_device_config_t *current_config = &(kbl_configs[i]);
        
        if (current_config->pid == pid_raw) {
            [device setConfig:current_config];
        }
    }
    
    
    return device;
}

+ (NSArray<KBLDeviceMenu *> *)findDevices {
    NSMutableDictionary *matchingDict = (__bridge NSMutableDictionary *)IOServiceMatching(kIOUSBDeviceClassName);
    if (matchingDict == nil) {
        return nil;
    }
    
    NSMutableArray *pids = [NSMutableArray array];
    
    for (int i = 0; i < NUM_OF_KBL_CONFIGS; i++) {
        [pids addObject:[NSNumber numberWithUnsignedShort:kbl_configs[i].pid]];
    }
    
    [matchingDict setValue:[NSNumber numberWithUnsignedShort:APPLE_VID] forKey:[NSString stringWithCString:kUSBVendorID encoding:NSASCIIStringEncoding]];
    [matchingDict setValue:pids forKey:@"idProductArray"];

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, (__bridge CFMutableDictionaryRef)matchingDict, &iterator);
    if (err != KERN_SUCCESS) {
        return nil;
    }
    
    
    NSMutableArray *result = [NSMutableArray array];
    
    io_service_t service = IO_OBJECT_NULL;
    while ((service = IOIteratorNext(iterator))) {
        KBLDeviceMenu *device = [self deviceWithService:service];
        if (!device) {
            printf("failed retrieving device info\n");
            continue;
        }
        
        [result addObject:device];
    }
    
    IOObjectRelease(iterator);

    return result;
}

+ (KBLDeviceMenu *)getDeviceWithMenu {
    NSArray<KBLDeviceMenu *> *devices = [self findDevices];
    
    if ([devices count] == 0) {
        return nil;
    }
    
    if ([devices count] == 1) {
        return [devices firstObject];
    }
    
    static const char start = 'a';
    unsigned int index = 0;
    
    for (KBLDeviceMenu *iterated in devices) {
        printf("%c) %s-%s\n", index + start, [iterated.name UTF8String], [iterated.sn UTF8String]);
        index++;
    }
    
    unsigned int result_index = -1;
    
    do {
        printf("Select one of the devices listed above: ");
        
        char result_char = getchar();
        if (result_char == '\n')
            continue;
        
        getchar();
        result_index = result_char - start;
    } while (result_index >= [devices count]);
    
    return [devices objectAtIndex:result_index];
}

@end
