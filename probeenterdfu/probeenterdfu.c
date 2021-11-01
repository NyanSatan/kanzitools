#include <stdio.h>
#include <astris/astris_api.h>

int main(int argc, const char *argv[]) {
    AXconn_t *conn = AXconn_create();
    if (!conn) {
        printf("failed to create Astris connection\n");
        return -1;
    }

    if (AXconn_connect(conn, NULL, 0, 0) != 0) {
        printf("failed to connect to a probe\n");
        return -1;
    }

    AXconn_fwupdate(conn);
    printf("the probe should reach bootloader now\n");

    return 0;
}
