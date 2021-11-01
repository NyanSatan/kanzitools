//
//  kbl_device.h
//  kblctl
//
//  Created by noone on 10/24/21.
//

#ifndef kbl_device_h
#define kbl_device_h

#include <stdio.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#define APPLE_VID   0x05AC

enum kbl_device_type {
    KBLTypeKanzi,
    KBLTypeChimp,
    KBLTypeKoko
};

struct kbl_device_config {
    enum kbl_device_type type;
    uint16_t pid;
    size_t fw_size;
};

typedef struct kbl_device_config kbl_device_config_t;

static const kbl_device_config_t kbl_configs[] = {
    {
        .type = KBLTypeKanzi,
        .pid = 0x1622,
        .fw_size = 0x100000
    },
    {
        .type = KBLTypeChimp,
        .pid = 0x162D,
        .fw_size = 0x100000
    },
    {
        .type = KBLTypeKoko,
        .pid = 0x164D,
        .fw_size = 0x20000
    },
};

#define NUM_OF_KBL_CONFIGS  (sizeof(kbl_configs) / sizeof(struct kbl_device_config))


typedef struct {
    IOUSBDeviceInterface **device;
    IOUSBInterfaceInterface550 **interface;
    uint8_t out_pipe;
    uint8_t in_pipe;
} kbl_device_t;

int  kbl_device_open(io_service_t service, kbl_device_t **handle);
void kbl_device_free(kbl_device_t *handle);


typedef enum {
    KBLRequestFlash = 1,
    KBLRequestDump = 2,
    KBLRequestReset = 3
} KBLRequestSelector;

int kbl_control_request(kbl_device_t *handle, KBLRequestSelector selector);


typedef enum {
    USBTransactionRead = 0,
    USBTransactionWrite = 1
} USBTransactionSelector;

int kbl_usb_transfer(kbl_device_t *handle, USBTransactionSelector selector, void *data, uint32_t *size);

#endif /* kbl_device_h */
