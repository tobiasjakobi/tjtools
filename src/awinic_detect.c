/**
 * gcc -o awinic_detect awinic_detect.c
 */

#include <i2c/smbus.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <fcntl.h>

#include <stdint.h>
#include <stdio.h>

static const unsigned adapter_nr = 1;
static const uint8_t devices_addresses[2] = {0x58, 0x5b};
static const uint8_t idcode_register = 0x0;
static const unsigned device_index = 0;

int main(int argc, char *argv[]) {
    int fd;
    int ret;
    char filename[20];

    snprintf(filename, 19, "/dev/i2c-%d", adapter_nr);

    fd = open(filename, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "error: failed to open I2C node: %d\n", fd);

        return -1;
    }

    ret = ioctl(fd, I2C_SLAVE, devices_addresses[device_index]);
    if (ret < 0) {
        fprintf(stderr, "error: failed to set I2C slave: %d\n", ret);

        return -2;
    }

    ret = i2c_smbus_read_byte_data(fd, idcode_register);
    if (ret < 0) {
        fprintf(stderr, "error: failed to read IDCODE: %d\n", ret);

        return -3;
    }

    fprintf(stderr, "info: read IDCODE: 0x%x\n", ret);

    return 0;
}

