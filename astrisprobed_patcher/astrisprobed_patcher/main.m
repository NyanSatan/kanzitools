//
//  main.m
//  astrisprobed_patcher
//
//  Created by noone on 10/22/21.
//

#import <Foundation/Foundation.h>
#import "patcher.h"

void usage(const char *program_name) {
    printf("%s OPTIONS\n", program_name);
    printf("where OPTIONS are the following:\n");
    printf("\t--daemon\trun as daemon\n");
    printf("\t--nova\t\tpatch Kanzi's PID to Nova's\n");
    printf("\t--udt\t\tpatch Chimp's PID to UDT's\n");
    printf("\n");
    printf("either --nova or --udt must be passed\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BOOL as_daemon = NO;
        BOOL nova = NO;
        BOOL udt = NO;
        
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--daemon") == 0) {
                as_daemon = YES;
            } else if (strcmp(argv[i], "--nova") == 0) {
                nova = YES;
            } else if (strcmp(argv[i], "--udt") == 0) {
                udt = YES;
            } else {
                usage(argv[0]);
                return -1;
            }
        }
        
        if (!nova && !udt) {
            usage(argv[0]);
            return -1;
        }
        
        return start_patcher(as_daemon, nova, udt);
    }
}
