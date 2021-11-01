//
//  kbl_device.c
//  kblctl
//
//  Created by noone on 10/24/21.
//

#include "kbl_device.h"

int kbl_device_open(io_service_t service, kbl_device_t **handle) {
    IOUSBDeviceInterface **device_interface = NULL;
    IOCFPlugInInterface** plug_in_interface;
    SInt32 score;
    
    kern_return_t err = IOCreatePlugInInterfaceForService(service,
                                                          kIOUSBDeviceUserClientTypeID,
                                                          kIOCFPlugInInterfaceID,
                                                          &plug_in_interface,
                                                          &score);
    if (err != KERN_SUCCESS || plug_in_interface == NULL) {
        printf("IOCreatePlugInInterfaceForService returned 0x%08x", err);
        return -1;
    }
    else {
        err = (*plug_in_interface)->QueryInterface(plug_in_interface,
                                                 CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                                                 (LPVOID*)&device_interface);

        
        
        (*plug_in_interface)->Release(plug_in_interface);
        
        if (err || device_interface == NULL) {
            printf("QueryInterface returned %x\n", err);
            return -1;
        }
    }


    io_iterator_t iterator;

    IOUSBFindInterfaceRequest interface_request;
    interface_request.bAlternateSetting     = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceClass       = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceProtocol    = kIOUSBFindInterfaceDontCare;
    interface_request.bInterfaceSubClass    = kIOUSBFindInterfaceDontCare;

    (*device_interface)->CreateInterfaceIterator(device_interface, &interface_request, &iterator);

    io_service_t interface_ref = IOIteratorNext(iterator);
    while (IOIteratorNext(iterator));
    
    if (interface_ref == 0) {
        printf("USB device has no interfaces\n");
        return -1;
    }

    IOUSBInterfaceInterface550 **interface_interface = NULL;

    err = IOCreatePlugInInterfaceForService(interface_ref,
                                            kIOUSBInterfaceUserClientTypeID,
                                            kIOCFPlugInInterfaceID,
                                            &plug_in_interface,
                                            &score);
    IOObjectRelease(interface_ref);
    
    if (err != KERN_SUCCESS || plug_in_interface == NULL) {
        printf("IOCreatePlugInInterfaceForService returned 0x%08x", err);
        return -1;
    }
    else {
        
        err = (*plug_in_interface)->QueryInterface(plug_in_interface,
                                                   CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
                                                   (LPVOID*)&interface_interface);
        
        
        

        (*plug_in_interface)->Release(plug_in_interface);
        
        if (err || interface_interface == NULL) {
            printf("QueryInterface returned %x\n", err);
            return -1;
        }
    }


    (*interface_interface)->USBInterfaceOpen(interface_interface);

    
    uint8_t pipe_counter = 1;

    uint8_t in_pipe = 0;
    uint8_t out_pipe = 0;

    do {
        uint8_t direction = 0;
        uint8_t number = 0;
        uint8_t tranferType = 0;
        uint16_t maxPacketSize = 0;
        uint8_t interval = 0;
        
        (*interface_interface)->GetPipeProperties(interface_interface, pipe_counter, &direction, &number, &tranferType, &maxPacketSize, &interval);
        
        if (direction == 1 && tranferType == 2) {
            in_pipe = pipe_counter;
            (*interface_interface)->ClearPipeStallBothEnds(interface_interface, pipe_counter);
        }
        
        if (direction == 0 && tranferType == 2) {
            out_pipe = pipe_counter;
            (*interface_interface)->ClearPipeStallBothEnds(interface_interface, pipe_counter);
        }
        
        pipe_counter++;
        
    } while (pipe_counter != 3);
    
    
    kbl_device_t *device_desc = malloc(sizeof(kbl_device_t));
    if (!device_desc) {
        printf("out of memory!");
        (*(device_interface))->Release(device_interface);
        (*(interface_interface))->Release(interface_interface);
        return -1;
    }
    
    device_desc->device = device_interface;
    device_desc->interface = interface_interface;
    device_desc->out_pipe = out_pipe;
    device_desc->in_pipe = in_pipe;
    
    *handle = device_desc;
    
    return 0;
}

void kbl_device_free(kbl_device_t *handle) {
    (*(handle->device))->Release(handle->device);
    (*(handle->interface))->Release(handle->interface);
    free(handle);
}

#define USB_TIMEOUT 500

int kbl_control_request(kbl_device_t *handle, KBLRequestSelector selector) {
    (*(handle->device))->USBDeviceSuspend(handle->device, false);
    
    IOUSBDevRequestTO request;
    request.bmRequestType = 0x41;
    request.bRequest = selector;
    request.wValue = 0;
    request.wIndex = 0;
    request.wLength = 0;
    request.pData = NULL;
    request.wLenDone = 0;
    request.noDataTimeout = USB_TIMEOUT;
    request.completionTimeout = USB_TIMEOUT;
    
    return (*(handle->device))->DeviceRequestTO(handle->device, &request);
}

#define USB_TRANSFER_TIMEOUT    10000

int kbl_usb_transfer(kbl_device_t *handle, USBTransactionSelector selector, void *data, uint32_t *size) {
    IOReturn ret;
    
    while (true) {
        uint8_t pipe;
        
        if (selector == USBTransactionRead) {
            pipe = handle->in_pipe;
            ret = (*(handle->interface))->ReadPipeTO(handle->interface, pipe, data, size, USB_TRANSFER_TIMEOUT, USB_TRANSFER_TIMEOUT);
            
        } else if (selector == USBTransactionWrite) {
            pipe = handle->out_pipe;
            ret = (*(handle->interface))->WritePipeTO(handle->interface, pipe, data, *size, USB_TRANSFER_TIMEOUT, USB_TRANSFER_TIMEOUT);
            
        } else {
            printf("unrecognized selector for USB transfer\n");
            return -1;
        }
        
        if (ret == kIOUSBPipeStalled) {
            printf("pipe stalled, clearing and trying again\n");
            (*(handle->interface))->ClearPipeStall(handle->interface, pipe);
        } else {
            break;
        }
    }
    
    switch (ret) {
        case kIOReturnSuccess:
            return 0;

        case kIOUSBTransactionTimeout:
            printf("timeout while USB transfer\n");
            break;
            
        case kIOReturnNoDevice:
            printf("device disconnected while USB transfer\n");
            break;
            
        default:
            printf("unknown error while USB transfer\n");
            break;
    }
    
    return -1;
}
