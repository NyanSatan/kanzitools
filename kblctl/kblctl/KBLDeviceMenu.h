//
//  KBLDeviceMenu.h
//  kblctl
//
//  Created by noone on 10/24/21.
//

#import <Foundation/Foundation.h>
#import "kbl_device.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBLDeviceMenu : NSObject

@property NSString *name;
@property NSString *sn;
@property io_service_t service;
@property const kbl_device_config_t *config;

+ (NSArray<KBLDeviceMenu *> *)findDevices;
+ (KBLDeviceMenu *)getDeviceWithMenu;

@end

NS_ASSUME_NONNULL_END
