//
//  fraudlib.h
//  kanzifraudctl
//
//  Created by noone on 9/28/20.
//  Copyright © 2020 noone. All rights reserved.
//

#ifndef fraudlib_h
#define fraudlib_h

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include "astris_api.h"

#define SHA1_LENGTH 20
#define SIGNATURE_LENGTH 128

/*
 * Disable Chimp and Koba for now, they require additional work
 */

static const char *ALLOWED_PROBES[] = {"KanziSWD", "Nova", /*"ChimpSWD", "KobaSWD"*/};
#define ALLOWED_PROBES_COUNT sizeof(ALLOWED_PROBES) / sizeof(const char *)

int KFLGetSignature(AXconn_t *conn, uint8_t *hash, uint8_t *signature);
int KFLGetCertificate(AXconn_t *conn, uint8_t **certificate, uint32_t *length);

#endif /* fraudlib_h */
