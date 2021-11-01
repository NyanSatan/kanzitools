//
//  patcher.m
//  astrisprobed_patcher
//
//  Created by noone on 12/9/19.
//  Copyright © 2019 noone. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <mach-o/loader.h>
#import "patcher.h"
#import "procInfo.h"

const uint16_t kanzi_pid_vid[] = {APPLE_VID, KANZI_PID};
const uint16_t nova_pid_vid[]  = {APPLE_VID, NOVA_PID};

const uint16_t chimp_pid_vid[] = {APPLE_VID, CHIMP_PID};
const uint16_t udt_pid_vid[]   = {APPLE_VID, UDT_PID};

BOOL gAsDaemon;

#define PATCHER_LOG(format, ...) \
            if (gAsDaemon) \
                NSLog(@format, ##__VA_ARGS__); \
            else \
                printf(format "\n", ##__VA_ARGS__);

BOOL check_process(Process* process) {
    NSString *processName = [[process binary] name];
    if ([processName isEqualToString:@"astrisprobed"]) {
        pid_t astrisprobed_pid = [process pid];
        PATCHER_LOG("Found astrisprobed, pid: %d", astrisprobed_pid);
        return YES;
    }
    
    return NO;
}

kern_return_t GetOFVariable(char *name, CFTypeRef *valueRef) {
    kern_return_t       result;
    mach_port_t         masterPort;
    
    result = IOMasterPort(bootstrap_port, &masterPort);
    if (result != KERN_SUCCESS) {
        PATCHER_LOG("Error getting the IOMaster port: %s",
          mach_error_string(result));
        return result;
    }

    io_registry_entry_t optionsRef = IORegistryEntryFromPath(masterPort, "IODeviceTree:/options");
    if (optionsRef == 0) {
        PATCHER_LOG("nvram is not supported on this system");
        return KERN_FAILURE;
    }

    CFStringRef nameRef = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingUTF8);
    if (nameRef == 0) {
        PATCHER_LOG("Error creating CFString for key %s", name);
        IOObjectRelease(optionsRef);
        return KERN_FAILURE;
    }

    *valueRef = IORegistryEntryCreateCFProperty(optionsRef, nameRef, 0, 0);

    CFRelease(nameRef);
    IOObjectRelease(optionsRef);
    
    if (*valueRef == 0) return kIOReturnNotFound;

    return KERN_SUCCESS;
}

void sip_warning() {
    if (NSAppKitVersionNumber >= NSAppKitVersionNumber10_11) {
        CFTypeRef csr_config;
        if (GetOFVariable("csr-active-config", &csr_config) == KERN_SUCCESS) {
            if (CFGetTypeID(csr_config) == CFDataGetTypeID()) {
                NSData *csrConfigData = (__bridge NSData*)csr_config;
                
                uint32_t csr_config_uint;
                [csrConfigData getBytes:&csr_config_uint length:sizeof(csr_config_uint)];
                
#define CSR_ALLOW_TASK_FOR_PID (1<<2)
                
                if (!(csr_config_uint & CSR_ALLOW_TASK_FOR_PID)) {
                    PATCHER_LOG("");
                    PATCHER_LOG("task_for_pid() against Apple-signed binaries is disallowed");
                    PATCHER_LOG("by SIP rules. Boot from Recovery partition and execute this:");
                    PATCHER_LOG("");
                    PATCHER_LOG("\tcsrutil enable --without debug && reboot");
                    PATCHER_LOG("");
                }
                
            } else {
                CFRelease(csr_config);
            }
        }
    }
}

int replace(task_t task, vm_address_t start_offset, void *buffer, size_t buffer_length, void *find, void *replace, size_t length) {
    void *previous_occurence = NULL;
    
    for (int i = 0; i < 2; i++) {
        void *find_struct = memmem(previous_occurence ? previous_occurence : buffer,
                                   previous_occurence ? buffer_length - (previous_occurence - buffer) : buffer_length,
                                   find,
                                   length);
        if (!find_struct) {
            if (i != 0) {
                PATCHER_LOG("only found one target struct, that's normal for some Astris versions");
                return 0;
            } else {
                PATCHER_LOG("failed to find target struct");
            }
            
            return -1;
        } else {
            vm_address_t address = (vm_address_t)start_offset + (find_struct - buffer);
            if (i == 0) {
                previous_occurence = find_struct + length;
            }
            if (vm_write(task, address, (vm_address_t)replace, (mach_msg_type_number_t)length) != KERN_SUCCESS) {
                PATCHER_LOG("failed to replace struct");
                return -1;
            }
            
            PATCHER_LOG("written new PID at %p", (void*)address);
        }
    }
    
    return 0;
}

int patch(pid_t pid, BOOL nova, BOOL udt) {
    PATCHER_LOG("Starting patching...");
    
    task_t probed_task;
    
    kern_return_t ret = task_for_pid(mach_task_self(), pid, &probed_task);
    if (ret != KERN_SUCCESS) {
        PATCHER_LOG("task_for_pid() failed");
        sip_warning();
        return -1;
    }
    
    vm_region_basic_info_data_t info;
    mach_vm_size_t size;
    mach_port_t object_name;
    mach_msg_type_number_t count;
    count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_vm_address_t address = 1;
    
    if ((ret = mach_vm_region(probed_task, &address, &size, VM_REGION_BASIC_INFO, (vm_region_info_t) &info, &count, &object_name)) != KERN_SUCCESS) {
        PATCHER_LOG("failed to find astrisprobed's base addr");
        return -1;
    }

    vm_map_offset_t vmoffset = address;
    vm_map_size_t vmsize = size;
                
    PATCHER_LOG("vmoffset: 0x%llx", vmoffset);
    PATCHER_LOG("vmsize: 0x%llx", vmsize);
    
    pointer_t buffer_ptr;
    uint32_t real_vmsize;
    
    if ((ret = vm_read(probed_task, vmoffset, vmsize, &buffer_ptr, &real_vmsize)) != KERN_SUCCESS) {
        PATCHER_LOG("failed to read astrisprobed's task memory");
        return -1;
    }
    
    void *task_data = malloc(real_vmsize);
    if (!task_data) {
        PATCHER_LOG("out of memory!");
        return -1;
    }
    
    memcpy(task_data, (const void *)buffer_ptr, real_vmsize);
    
    if (*(uint32_t *)task_data != MH_MAGIC_64) {
        PATCHER_LOG("astrisprobed isn't a 64-bit image");
        free(task_data);
        return -1;
    }
    
    struct mach_header_64 *probed_macho_header = task_data;
    struct load_command *commands = task_data + sizeof(*probed_macho_header);
    struct segment_command_64 *data_segment = NULL;
    
    for (uint32_t i = 0, o = 0; i < (probed_macho_header->ncmds); i++) {
        struct load_command *command = (struct load_command *)((uint64_t)commands + o);
        if (command->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *segment = (struct segment_command_64 *)command;
            if (strcmp(segment->segname, SEG_DATA) == 0) {
                data_segment = segment;
                PATCHER_LOG("found %s segment at %p (unslid)", SEG_DATA, (void*)data_segment->vmaddr);
                break;
            }
        }
        o += command->cmdsize;
    }
    
    if (!data_segment) {
        PATCHER_LOG("couldn't find %s segment", SEG_DATA);
        free(task_data);
        return -1;
    }
    
    struct section_64 *sections = (struct section_64 *)((uint64_t)data_segment + sizeof(*data_segment));
    struct section_64 *const_section = NULL;
    
    for (uint32_t i = 0; i < (data_segment->nsects); i++) {
        struct section_64 *section = &(sections[i]);
        if (strcmp(section->sectname, "__const") == 0) {
            const_section = section;
            PATCHER_LOG("found %s section at 0x%x (file offset unslid)", "__const", const_section->offset);
            break;
        }
    }
    
    free(task_data);
    
    if (!const_section) {
        PATCHER_LOG("couldn't find %s section", "__const");
        return -1;
    }
    
    uint64_t const_offset = vmoffset + const_section->offset;
    uint64_t const_size = const_section->size;
    
    if ((ret = vm_read(probed_task, const_offset, const_size, &buffer_ptr, &real_vmsize)) != KERN_SUCCESS) {
        PATCHER_LOG("failed to read astrisprobed's task memory");
        return -1;
    }
    
    void *const_data = malloc(real_vmsize);
    if (!const_data) {
        PATCHER_LOG("out of memory!");
        return -1;
    }
    
    memcpy(const_data, (const void *)buffer_ptr, real_vmsize);
    
    int result = 0;
    
    if (nova) {
        PATCHER_LOG("Patching Nova...");
        if (replace(probed_task, const_offset, const_data, const_size, (void *)&kanzi_pid_vid, (void *)&nova_pid_vid, sizeof(nova_pid_vid)) != 0) {
            result++;
        }
    }
    
    if (udt) {
        PATCHER_LOG("Patching UDT...");
        if (replace(probed_task, const_offset, const_data, const_size, (void *)&chimp_pid_vid, (void *)&udt_pid_vid, sizeof(udt_pid_vid)) != 0) {
            result++;
        }
    }
    
    free(const_data);
    
    if (result == 0) {
        PATCHER_LOG("Successfully patched astrisprobed with PID: %d", pid);
    } else {
        PATCHER_LOG("Error patching astrisprobed with PID: %d", pid);
    }
    
    return result;
}

int start_patcher(BOOL as_daemon, BOOL nova, BOOL udt) {
    gAsDaemon = as_daemon;
    
    BOOL wasPatched = NO;
    
    if (getuid() != 0) {
        PATCHER_LOG("This must be run as root!");
        return -1;
    }
    
    ProcInfo* procInfo = [[ProcInfo alloc] init:YES];
    for (Process* process in [procInfo currentProcesses]) {
        if (check_process(process)) {
            pid_t pid = [process pid];
            if (patch(pid, nova, udt) != 0) {
                PATCHER_LOG("Failed to patch astrisprobed with PID: %d", pid);
                if (!gAsDaemon)
                    return -1;
                else {
                    wasPatched = NO;
                }
            } else {
                if (gAsDaemon) {
                    wasPatched = YES;
                } else {
                    return 0;
                }
            }
        }
    }
    
    
    if (gAsDaemon) {
        ProcessCallbackBlock block = ^(Process* process) {
            if (process.type != EVENT_EXIT) {
                if (check_process(process)) {
                    pid_t pid = [process pid];
                    if (patch(pid, nova, udt) != 0) {
                        PATCHER_LOG("Failed to patch astrisprobed with PID: %d", pid);
                    }
                }
            }
        };
        
        [procInfo start:block];
        if (wasPatched) {
            PATCHER_LOG("Waiting for another astrisprobed\n");
        } else {
            PATCHER_LOG("Waiting for astrisprobed\n");
        }
        
        [[NSRunLoop currentRunLoop] run];
    } else {
        PATCHER_LOG("Failed to find astrisprobed process");
        return -1;
    }
    
    return 0;
}
