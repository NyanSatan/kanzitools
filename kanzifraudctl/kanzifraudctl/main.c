//
//  main.c
//  kanzifraudctl
//
//  Created by noone on 9/28/20.
//  Copyright © 2020 noone. All rights reserved.
//

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/time.h>

#include "astris_api.h"
#include "fraudlib.h"
#include "utils.h"

bool probe_allowed(AXconn_t *conn) {
    const char *name = AXconn_showname(conn);
    bool found = false;
    
    for (int i = 0; i < ALLOWED_PROBES_COUNT; i++) {
        if (strstr(name, ALLOWED_PROBES[i])) {
            found = true;
            break;
        }
    }
    
    return found;
}

int probe_connect(AXconn_t **conn) {
    AXconn_t *_conn = AXconn_create();
    if (!conn) {
        printf("out of memory!\n");
        return -1;
    }
    
    if (AXconn_connect(_conn, "localhost", 0, 0) != 0) {
        printf("failed to connect to a probe\n");
        AXconn_destroy(_conn);
        return -1;
    }
    
    if (!probe_allowed(_conn)) {
        printf("this is not a compatible probe\n");
        AXconn_disconnect(_conn);
        AXconn_destroy(_conn);
        return -1;
    }
    
    *conn = _conn;
    
    return 0;
}

void probe_disconnect(AXconn_t *conn) {
    if (AXconn_connected(conn)) {
        AXconn_disconnect(conn);
    }
    
    AXconn_destroy(conn);
}

void usage(const char *argv0) {
    printf("usage: %s <option> <arg>\n", argv0);
    printf("where option is one of the following:\n");
    printf("\t-g <SHA-1>\tgenerate signature from hash\n");
    printf("\t-c <path>\tdump certificate\n");
}

int main(int argc, const char * argv[]) {
    if (argc != 3) {
        usage(argv[0]);
        return -1;
    }
    
    const char *option = argv[1];
    const char *arg = argv[2];
    
    if (strcmp(option, "-g") == 0) {
        if (strlen(arg) != SHA1_LENGTH * 2) {
            printf("not valid SHA-1 hash\n");
            return -1;
        }
        
        uint8_t sha1_decoded[SHA1_LENGTH];
        
        if (str2hex(SHA1_LENGTH, (unsigned char *)&sha1_decoded, arg) != SHA1_LENGTH) {
            printf("not valid SHA-1 hash\n");
            return -1;
        }
        
        uint8_t signature[SIGNATURE_LENGTH];
        
        int ret = 0;
        
        AXconn_t *conn;
        if (probe_connect(&conn) != 0) {
            return -1;
        }
        
        struct timeval st, et;

        gettimeofday(&st, NULL);
        
        if (KFLGetSignature(conn, (uint8_t*)&sha1_decoded, (uint8_t*)&signature) != 0) {
            printf("KFLGetSignature() failed\n");
            goto out_gen_fail;
        }
        
        gettimeofday(&et, NULL);
        
        long elapsed = ((et.tv_sec - st.tv_sec) * 1000000) + (et.tv_usec - st.tv_usec);
        printf("took %ld microseconds\n", elapsed);
        
        unsigned char *encoded = NULL;
        
        if (!(encoded = base64_encode(signature, SIGNATURE_LENGTH, NULL))) {
            printf("failed to encode result\n");
            goto out_gen_fail;
        }
        
        printf("B64 SIGNATURE:\n%s\n", encoded);
        
        free(encoded);
        
        goto out_gen;
        
    out_gen_fail:
        ret = -1;
        
    out_gen:
        probe_disconnect(conn);
        
        return ret;
        
    } else if (strcmp(option, "-c") == 0) {

        if (access(arg, F_OK) == 0) {
            printf("desired output file already exists\n");
            return -1;
        }
        
        AXconn_t *conn;
        if (probe_connect(&conn) != 0) {
            return -1;
        }
        
        
        int ret = 0;
        int fd = -1;
        
        uint8_t *cert_buf = NULL;
        uint32_t cert_len = 0;
        
        if (KFLGetCertificate(conn, &cert_buf, &cert_len) != 0) {
            printf("KFLGetCertificate() failed\n");
            goto out_cert_fail;
        }
        
        fd = open(arg, O_WRONLY | O_CREAT, 0644);
        if (fd < 0) {
            printf("failed to create output file\n");
            goto out_cert_fail;
        }
        
        if (write(fd, cert_buf, cert_len) != cert_len) {
            printf("failed to write certificate\n");
            goto out_cert_fail;
        }
        
        printf("written to %s\n", arg);
        
        goto out_cert;
        
    out_cert_fail:
        ret = -1;
        
    out_cert:
        if (cert_buf) free(cert_buf);
        if (fd > 0) close(fd);
        probe_disconnect(conn);
        
        return ret;
    } else {
        usage(argv[0]);
        return -1;
    }
}
