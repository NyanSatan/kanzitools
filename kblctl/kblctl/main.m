//
//  main.m
//  kblctl
//
//  Created by noone on 10/24/21.
//

#import <Foundation/Foundation.h>
#import "KBLDeviceMenu.h"

bool device_acquire(kbl_device_t **handle, const kbl_device_config_t **config) {
    KBLDeviceMenu *device = [KBLDeviceMenu getDeviceWithMenu];
    if (!device) {
        printf("no devices found\n");
        return false;
    }
    
    printf("device: %s-%s\n", [device.name UTF8String], [device.sn UTF8String]);
    
    
    if (kbl_device_open([device service], handle) != 0) {
        printf("failed to open device\n");
        return false;
    }
    
    if (config) {
        *config = [device config];
    }
    
    return true;
}

int device_flash(const char *path) {
    if (access(path, F_OK) != 0) {
        printf("the input file doesn't exist or is not available for reading\n");
        return -1;
    }
    
    kbl_device_t *handle;
    const kbl_device_config_t *config;
    if (!device_acquire(&handle, &config)) {
        return -1;
    }
    
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("failed to open the input file\n");
        kbl_device_free(handle);
        return -1;
    }
    
    uint32_t size = (uint32_t)lseek(fd, 0, SEEK_END);
    if (size > config->fw_size) {
        printf("the input file is too big for the requested probe\n");
        kbl_device_free(handle);
        close(fd);
        return -1;
    }
    
    if (size == config->fw_size) {
        printf("this is a dumped firmware image\n");
    }
    
    uint8_t buffer[size];
    if (pread(fd, buffer, size, 0) != size) {
        printf("failed to read from file");
        kbl_device_free(handle);
        close(fd);
        return -1;
    }
    
    close(fd);
    
    if (kbl_control_request(handle, KBLRequestFlash) != 0) {
        printf("failed to send flash request\n");
        kbl_device_free(handle);
        return -1;
    }
    
    printf("flash request sent, writing...\n");
    
    if (kbl_usb_transfer(handle, USBTransactionWrite, buffer, &size) != 0) {
        printf("failed to write\n");
        kbl_device_free(handle);
        return -1;
    }
    
    kbl_device_free(handle);
    
    printf("successfully flashed!\n");
    
    return 0;
}

int device_dump(const char *path) {
    if (access(path, F_OK) == 0) {
        printf("the output file already exists, won't overwrite\n");
        return -1;
    }
    
    kbl_device_t *handle;
    const kbl_device_config_t *config;
    if (!device_acquire(&handle, &config)) {
        return -1;
    }
    
    if (kbl_control_request(handle, KBLRequestDump) != 0) {
        printf("failed to send dump request\n");
        kbl_device_free(handle);
        return -1;
    }
    
    printf("dump request sent, reading...\n");
    
    uint32_t size = (uint32_t)config->fw_size;
    
    uint8_t buffer[size];
    memset(buffer, 0x0, sizeof(buffer));
    
    if (kbl_usb_transfer(handle, USBTransactionRead, buffer, &size) != 0) {
        printf("failed to read\n");
        kbl_device_free(handle);
        return -1;
    }
    
    int fd = open(path, O_WRONLY | O_CREAT, 0644);
    if (fd < 0) {
        printf("failed to create the output file\n");
        kbl_device_free(handle);
        return -1;
    }
    
    if (write(fd, buffer, size) != size) {
        printf("failed to write to the output file\n");
        kbl_device_free(handle);
        close(fd);
        return -1;
    }
    
    kbl_device_free(handle);
    close(fd);
    
    printf("successfully dumped to %s!\n", path);
    
    return 0;
}

int device_reset() {
    kbl_device_t *handle;
    if (!device_acquire(&handle, NULL)) {
        return -1;
    }
    
    int ret;
    
    if (kbl_control_request(handle, KBLRequestReset) == 0) {
        printf("reset request sent successfully!\n");
        ret = 0;
    } else {
        printf("reset request failed\n");
        ret = -1;
    }
    
    kbl_device_free(handle);
    
    return ret;
}

void usage(const char *program_name) {
    printf("usage: %s VERB [options]\n", program_name);
    printf("where VERB is one of the following:\n");
    printf("\tflash <file>\tflash firmware from a file\n");
    printf("\tdump <file>\tdump firmware to a file\n");
    printf("\treset\t\treset to normal mode\n");
}

typedef enum {
    KBLCTL_VERB_FLASH,
    KBLCTL_VERB_DUMP,
    KBLCTL_VERB_RESET,
    KBLCTL_VERB_UNDEFINED
} kblctl_verb_t;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        kblctl_verb_t verb = KBLCTL_VERB_UNDEFINED;
        const char *arg = NULL;
        
        if (argc == 2 && strcmp(argv[1], "reset") == 0) {
            verb = KBLCTL_VERB_RESET;
        } else if (argc == 3) {
            if (strcmp(argv[1], "flash") == 0) {
                verb = KBLCTL_VERB_FLASH;
            } else if (strcmp(argv[1], "dump") == 0) {
                verb = KBLCTL_VERB_DUMP;
            } else {
                usage(argv[0]);
                return -1;
            }
            
            arg = argv[2];
            
        } else {
            usage(argv[0]);
            return -1;
        }
        
        switch (verb) {
            case KBLCTL_VERB_FLASH:
                return device_flash(arg);
                
            case KBLCTL_VERB_DUMP:
                return device_dump(arg);
                
            case KBLCTL_VERB_RESET:
                return device_reset();
                
            case KBLCTL_VERB_UNDEFINED:
                return -1;
        }
    
    }

}
