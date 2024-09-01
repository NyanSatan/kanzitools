#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

#define BL_LEN      (0x4000)
#define FW_LEN_PTR  (BL_LEN + 0x1C)
#define FW_MAX_LEN  ((1 * 1024 * 1024) - BL_LEN)

uint32_t stm32_crc(uint32_t *buf, size_t count) {
    uint32_t crc = 0xFFFFFFFFUL;
    
    for (size_t i = 0; i < count; i++) {
        uint32_t val = *(buf + i);
        crc ^= val;
        for (int z = 0; z < 32; z++) {
            crc = (crc & 0x80000000UL) == 0 ? crc << 1 : (crc << 1) ^ 0x04C11DB7UL;
        }
    }
    
    return crc;
}

int main(int argc, const char *argv[]) {
    if (argc < 3) {
        printf("%s <input> <output>\n", argv[0]);
        return -1;
    }
    
    const char *input = argv[1];
    const char *output = argv[2];
    
    int fd = open(input, O_RDONLY);
    if (fd < 0) {
        printf("failed to open input file\n");
        return -2;
    }
    
    uint32_t fw_len = 0;
    
    if (pread(fd, &fw_len, sizeof(uint32_t), FW_LEN_PTR) != sizeof(uint32_t)) {
        close(fd);
        printf("failed to read firmware length\n");
        return -3;
    }
    
    printf("firmware length = 0x%x\n", fw_len);
    
    if (fw_len % 4) {
        printf("firmware length is not aligned to 4\n");
        return -5;
    }
    
    if (fw_len > FW_MAX_LEN) {
        printf("firmware length is too big\n");
        return -5;
    }
    
    uint32_t total_len = BL_LEN + fw_len;
    
    uint8_t buf[total_len];
    size_t len_ret = pread(fd, buf, total_len, 0);
    
    close(fd);
    
    if (len_ret != total_len) {
        printf("failed to read firmware\n");
        return -4;
    }
    
    uint32_t *fw_ptr = (uint32_t *)(buf + BL_LEN);
    size_t fw_count = fw_len / 4;
    
    uint32_t crc_final = stm32_crc(fw_ptr, fw_len / 4);
    printf("final CRC = 0x%08x\n", crc_final);
    
    if (crc_final != 0) {
        printf("final CRC is NOT 0x0, fixing\n");
        
        volatile uint32_t *crc_ptr = fw_ptr + fw_count - 1;
        
        uint32_t crc_current = *crc_ptr;
        printf("current CRC = 0x%08x\n", crc_current);
        
        uint32_t crc_computed = stm32_crc(fw_ptr, fw_count - 1);
        printf("computed CRC = 0x%08x\n", crc_computed);

        *crc_ptr = crc_computed;
        
        uint32_t crc_recomputed = stm32_crc(fw_ptr, fw_count);
        printf("recomputed final CRC = 0x%08x\n", crc_recomputed);
        
        if (crc_recomputed != 0) {
            printf("still do NOT match after recomputing?!\n");
            return -6;
        }
    } else {
        printf("CRC is good!\n");
    }
    
    int fd_out = open(output, O_WRONLY | O_CREAT, 0644);
    if (fd_out < 0) {
        printf("failed to create output file\n");
        return -7;
    }
    
    size_t write_ret = write(fd_out, buf, total_len);
    
    close(fd_out);
    
    if (write_ret != total_len) {
        printf("failed to write output file\n");
        return -8;
    }
    
    printf("written output file\n");
    
    printf("DONE!\n");
    
    return 0;
}
