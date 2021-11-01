//
//  patcher.h
//  astrisprobed_patcher
//
//  Created by noone on 12/9/19.
//  Copyright © 2019 noone. All rights reserved.
//

#ifndef patcher_h
#define patcher_h

#define APPLE_VID   0x5AC

#define KANZI_PID   0x1621
#define NOVA_PID    0x1624

#define CHIMP_PID   0x162C
#define UDT_PID     0x168C

int start_patcher(BOOL as_daemon, BOOL nova, BOOL udt);

#endif /* patcher_h */
