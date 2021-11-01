//
//  astris_api.h
//  kanzifraudctl
//
//  Created by noone on 9/28/20.
//  Copyright © 2020 noone. All rights reserved.
//

#ifndef astris_api_h
#define astris_api_h

#include <stdbool.h>

/*
 * Userland interaction
 */

typedef struct AXconn_s AXconn_t;

AXconn_t   *AXconn_create(void);
int         AXconn_destroy(AXconn_t *info);
const char *AXconn_showname(AXconn_t *info);

int         AXconn_connect(AXconn_t *info, const char *host, int port, unsigned int flags);
int         AXconn_disconnect(AXconn_t *info);
bool        AXconn_connected(AXconn_t *info);

int AXrelay_get(AXconn_t *info, const char *name);
int AXrelay_set(AXconn_t *info, const char *name, int val);

int AXgeni2c_send(AXconn_t *info, uint8_t addr, uint8_t *data, int len, unsigned int flags);
int AXgeni2c_recv(AXconn_t *info, uint8_t addr, uint8_t *data, int len, unsigned int flags);

#endif /* astris_api_h */
