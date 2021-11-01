//
//  fraudlib.c
//  kanzifraudctl
//
//  Created by noone on 9/28/20.
//  Copyright © 2020 noone. All rights reserved.
//

#include "fraudlib.h"

#define BUFFER_I2C_ADDR 0xAF

#define AUTH_CMD "authcmd"

#define AUTH_CMD_GET_CERT_LEN   2
#define AUTH_CMD_SET_CERT_OFF   3
#define AUTH_CMD_PASS_HASH      4
#define AUTH_CMD_GET_SIG_LEN    5
#define AUTH_CMD_GET_SIG        6

#define CERT_PORTION_LENGTH     128

struct __attribute__((packed)) probe_range {
    uint16_t len;
    uint16_t off;
};


struct probe_range probe_range_decode(uint32_t raw) {
    uint16_t len = CFSwapInt16BigToHost(*(uint16_t*)&raw);
    uint16_t off = CFSwapInt16BigToHost(*(((uint16_t *)&raw) + 1));
    
    return (struct probe_range){len, off};
}

uint32_t probe_range_encode(struct probe_range *decoded) {
    uint16_t off = CFSwapInt16BigToHost(decoded->off);
    uint16_t len = CFSwapInt16BigToHost(decoded->len);
    
    struct probe_range result = {len, off};
    
    return *(uint32_t *)&result;
}

int writeBuf(AXconn_t *conn, uint8_t *data, int len) {
    return AXgeni2c_send(conn, BUFFER_I2C_ADDR, data, len, 0);
}

int readBuf(AXconn_t *conn, uint8_t *data, int len) {
    return AXgeni2c_recv(conn, BUFFER_I2C_ADDR, data, len, 0);
}

int executeCmd(AXconn_t *conn, int cmd) {
    AXrelay_set(conn, AUTH_CMD, cmd);
    
    for (int i = 0; i < 150; i++) {
        int ret = AXrelay_get(conn, AUTH_CMD);
        
        if (ret != cmd)
            return ret; //should be zero
    }
    
    printf("executeCmd failed!\n");
    
    return -1;
}

int KFLGetSignature(AXconn_t *conn, uint8_t *hash, uint8_t *signature) {
    if (writeBuf(conn, hash, SHA1_LENGTH) != SHA1_LENGTH) {
        printf("failed to send hash to Mozart\n");
        return -1;
    }
    
    if (executeCmd(conn, AUTH_CMD_PASS_HASH) != 0) {
        printf("failed to pass hash\n");
        return -1;
    }
    
    if (executeCmd(conn, AUTH_CMD_GET_SIG_LEN) != 0) {
        printf("failed to get signature length\n");
        return -1;
    }
    
    uint16_t sig_len = 0;
    if (readBuf(conn, (uint8_t *)&sig_len, sizeof(sig_len)) != sizeof(sig_len)) {
        printf("failed to read signature length\n");
        return -1;
    }

    sig_len = CFSwapInt16BigToHost(sig_len);
    
    printf("signature length: %d\n", sig_len);
    
    if (sig_len != SIGNATURE_LENGTH) {
        printf("invalid signature length returned from Mozart\n");
        return -1;
    }
    
    if (executeCmd(conn, AUTH_CMD_GET_SIG) != 0) {
        printf("failed to send AUTH_CMD_GET_SIG command\n");
        return -1;
    }
    
    if (readBuf(conn, signature, SIGNATURE_LENGTH) != SIGNATURE_LENGTH) {
        printf("failed to receive signature from Mozart\n");
        return -1;
    }
    
    return 0;
}

int KFLGetCertificate(AXconn_t *conn, uint8_t **certificate, uint32_t *length) {
    if (executeCmd(conn, AUTH_CMD_GET_CERT_LEN) != 0) {
        printf("failed to request certificate length\n");
        return -1;
    }
    
    uint32_t cert_len_raw = 0;
    if (readBuf(conn, (uint8_t *)&cert_len_raw, sizeof(cert_len_raw)) != sizeof(cert_len_raw)) {
        printf("failed to read certificate length\n");
        return -1;
    }
    
    //printf("certificate length (raw): %08x\n", cert_len_raw);
    
    struct probe_range cert_len_decoded = probe_range_decode(cert_len_raw);
    
    uint16_t cert_len = cert_len_decoded.len;
    
    printf("certificate length: %d\n", cert_len);
    
    uint8_t *buf = malloc(cert_len);
    memset(buf, 0x0, cert_len);
    
    for (uint16_t i = 0; i < cert_len; i += CERT_PORTION_LENGTH) {
        uint16_t left = cert_len - i;
        uint16_t to_read = left < CERT_PORTION_LENGTH ? left : CERT_PORTION_LENGTH;
        
        struct probe_range range = {
            i, to_read
        };
        
        uint32_t range_raw = probe_range_encode(&range);
    
        printf("reading at offset: %d\n", i);
        
        if (!(writeBuf(conn, (uint8_t *)&range_raw, sizeof(range_raw)) == sizeof(range_raw) && executeCmd(conn, AUTH_CMD_SET_CERT_OFF) == 0)) {
            printf("failed to set offset\n");
            free(buf);
            return -1;
        }
        
        if (readBuf(conn, buf + i, to_read) != to_read) {
            printf("failed to receive certificate portion\n");
            free(buf);
            return -1;
        }
    }
    
    *certificate = buf;
    *length = cert_len;
    
    return 0;
}
