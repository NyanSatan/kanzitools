//
//  main.m
//  kanzictl
//
//  Created by noone on 11/7/19.
//  Copyright © 2019 noone. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "dump.h"
#include "reset.h"
#include "patcher.h"
#include "install.h"

void print_warning() {
    printf("THIS IS CONFIDENTIAL & PROPRIETARY SOFTWARE BY LISA BRAUN (@NYAN_SATAN)\n");
    printf("WHOEVER ACQUIRED IT WITHOUT A PERMISSION MUST IMMEDIATELY COMMIT SUICIDE\n");
    printf("\n");
}

void print_usage(const char* arg0) {
    printf("usage: %s VERB\n", arg0);
    printf("where VERB is one of the following:\n");
    printf("\tdump <file>\t\tdumps firmware from Kanzi probe in recovery mode\n");
    printf("\treset\t\t\tresets Kanzi probe in recovery mode\n");
    printf("\tpatch\t\t\tpatches astrisprobed in memory to support SNR. Run with \"--daemon\" flag for it to operate as a daemon\n");
    printf("\tinstall\t\t\tinstalls daemon binary and LaunchDaemon plist\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //print_warning();
        
        if (argc < 2) {
            print_usage(argv[0]);
            return -1;
        }
        
        const char *verb = argv[1];
        
        if (strcmp(verb, "dump") == 0) {
            if (argc == 3) {
                const char *output = argv[2];
                return dump(output);
            } else {
                printf("not enough arguments\n");
                print_usage(argv[0]);
                return -1;
            }
        } else if (strcmp(verb, "reset") == 0) {
            return reset();
        } else if (strcmp(verb, "patch") == 0) {
            if (argc == 3) {
                const char *option = argv[2];
                if (strcmp(option, "--daemon") == 0) {
                    return start_patcher(YES);
                } else {
                    printf("unrecognized option: %s\n", option);
                    return -1;
                }
            } else {
                return start_patcher(NO);
            }
        } else if (strcmp(verb, "install") == 0) {
            return install([[[[NSProcessInfo processInfo] arguments] objectAtIndex:0] UTF8String]);
        } else {
            printf("unrecognized verb: %s\n", verb);
            print_usage(argv[0]);
            return -1;
        }
        
    }
    return 0;
}
