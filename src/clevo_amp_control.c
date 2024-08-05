/*
 * Based on the Python tool init-headphone-ubuntu
 *
 * https://github.com/Unrud/init-headphone-ubuntu.git
 */

#include <linux/i2c-dev.h>
#include <linux/i2c.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <unistd.h>

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include <assert.h>
#include <errno.h>

enum e_constants {
    device_address = 0x73,
};

enum e_modes {
    invalid,
    init,
    effect,
    mute,
    unmute,
    recovery,
};

enum e_effects {
    no_change,
    bass_boost,
    unknown1,
    unknown2,
    boost_all,
    unknown3,
    unknown4,
    num_effects,
};


struct i2c_slave {
    int fd;
    uint8_t address;
};

struct amplifier_paket {
    uint8_t cmd;
    uint8_t val;
};


static const struct amplifier_paket output_disable_pkt = {
    .cmd = 0x00, .val = 0x86,
};

static const struct amplifier_paket output_enable_pkt = {
    .cmd = 0x00, .val = 0x82,
};

static const uint8_t effects_cmds[5] = {
    0x04, 0x05, 0x07, 0x08, 0x09,
};

static const uint8_t effects_vals[num_effects][5] = {
    {
        0x11, 0x02, 0x22, 0x82, 0x22,
    }, {
        0xee, 0x03, 0x40, 0x84, 0xff,
    }, {
        0xaa, 0x23, 0x40, 0x84, 0x00,
    }, {
        0xaa, 0x22, 0x33, 0x84, 0x00,
    }, {
        0x88, 0x03, 0x23, 0x82, 0x22,
    }, {
        0xaa, 0x23, 0x41, 0x84, 0x00,
    }, {
        0xaa, 0x02, 0x43, 0x82, 0x00,
    },
};

static const struct amplifier_paket recovery_pkts[2] = {
    {
        .cmd = 0x0b, .val = 0x82,
    }, {
        .cmd = 0x0b, .val = 0x92,
    },
};


static enum e_modes
unfmt_modes(const char *m)
{
    if (strcmp(m, "init") == 0)
        return init;
    else if (strcmp(m, "effect") == 0)
        return effect;
    else if (strcmp(m, "init") == 0)
        return init;
    else if (strcmp(m, "mute") == 0)
        return mute;
    else if (strcmp(m, "unmute") == 0)
        return unmute;
    else if (strcmp(m, "recovery") == 0)
        return recovery;
    else
        return invalid;
}


static int
i2c_write(struct i2c_slave *slv, uint8_t cmd, uint8_t val)
{
    int ret;

    union i2c_smbus_data data = {
        .byte = val,
    };

    struct i2c_smbus_ioctl_data req = {
        .read_write = I2C_SMBUS_WRITE,
        .command = cmd,
        .size = I2C_SMBUS_BYTE_DATA,
        .data = &data,
    };

    ret = ioctl(slv->fd, I2C_SMBUS, &req);

    return ret;
}

static int
i2c_read(struct i2c_slave *slv, uint8_t cmd, uint8_t *val)
{
    int ret;

    union i2c_smbus_data data;

    struct i2c_smbus_ioctl_data req = {
        .read_write = I2C_SMBUS_READ,
        .command = cmd,
        .size = I2C_SMBUS_BYTE_DATA,
        .data = &data,
    };

    ret = ioctl(slv->fd, I2C_SMBUS, &req);

    *val = data.byte & 0xff;

    return ret;
}

static int
i2c_init(struct i2c_slave *slv)
{
    int ret, address;

    address = slv->address;

    ret = ioctl(slv->fd, I2C_SLAVE, address);

    return ret;
}

static void
i2c_fini(struct i2c_slave *slv)
{
    close(slv->fd);
}

static int
prolog_write(struct i2c_slave *slv)
{
    static const struct amplifier_paket prolog_pkt = {
        .cmd = 0x0a, .val = 0x41,
    };

    static const uint8_t cmds[2] = {0x04, 0x09};

    int ret;
    unsigned i;

    ret = i2c_write(slv, prolog_pkt.cmd, prolog_pkt.val);
    if (ret < 0) {
        fprintf(stderr, "error: %s: failed to write first paket (%d)\n", __func__, ret);
        return -1;
    }

    for (i = 0; i < sizeof(cmds) / sizeof(uint8_t); ++i) {
        uint8_t val;

        ret = i2c_read(slv, cmds[i], &val);
        if (ret < 0)
            break;

        ret = i2c_write(slv, cmds[i], val);
        if (ret < 0)
            break;
    }

    if (i != sizeof(cmds) / sizeof(uint8_t)) {
        fprintf(stderr, "error: %s: failed to write main paket %u (%d)\n", __func__, i, ret);
        return -2;
    }

    return 0;
}

static int
pakets_write(struct i2c_slave *slv, unsigned num, const struct amplifier_paket *pkts)
{
    int ret;
    unsigned i;

    ret = prolog_write(slv);
    if (ret < 0) {
        fprintf(stderr, "error: %s: failed to write prolog (%d)\n", __func__, ret);
        return -1;
    }

    for (i = 0; i < num; ++i) {
        ret = i2c_write(slv, pkts[i].cmd, pkts[i].val);

        if (ret < 0)
            break;
    }

    if (i != num) {
        fprintf(stderr, "error: %s: failed to write paket %u (%d)\n", __func__, i, ret);
        return -2;
    }

    return 0;
}

static struct amplifier_paket*
gen_effect(struct amplifier_paket *pkt, enum e_effects effect)
{
    unsigned i;

    for (i = 0; i < sizeof(effects_cmds) / sizeof(uint8_t); ++i) {
        *pkt++ = (struct amplifier_paket) {
            .cmd = effects_cmds[i],
            .val = effects_vals[effect][i],
        };
    }

    return pkt;
}

static int
amp_effect(struct i2c_slave *slv, enum e_effects effect)
{
    // disable (1) + effect (5) + enable (1)
    struct amplifier_paket pakets[1 + 5 + 1];
    struct amplifier_paket *pkt = pakets;

    *pkt++ = output_disable_pkt;
    pkt = gen_effect(pkt, effect);
    *pkt++ = output_enable_pkt;

    return pakets_write(slv, sizeof(pakets) / sizeof(struct amplifier_paket), pakets);
}

static int
amp_mute(struct i2c_slave *slv, bool state)
{
    return pakets_write(slv, 1, state ? &output_disable_pkt : &output_enable_pkt);
}

static int
amp_init(struct i2c_slave *slv)
{
    return amp_effect(slv, bass_boost);
}

static int
amp_recovery(struct i2c_slave *slv)
{
    return pakets_write(slv, 2, recovery_pkts);
}


static struct i2c_slave*
open_amplifier()
{
    static const char identifier[] = "SMBus I801 adapter at";
    static const char i2c_base[] = "/sys/class/i2c-dev";
    char buffer[512];

    DIR *dp;
    struct dirent *ep;
    int fd, i2c_idx;

    struct i2c_slave *slv = NULL;

    dp = opendir(i2c_base);
    if (dp == NULL) {
        fprintf(stderr, "error: %s: missing i2c device sysfs\n", __func__);
        goto fail;
    }

    while ((ep = readdir(dp))) {
        ssize_t len;
        bool found = false;

        if (sscanf(ep->d_name, "i2c-%d", &i2c_idx) != 1)
            continue;

        snprintf(buffer, sizeof(buffer), "%s/%s/name", i2c_base, ep->d_name);

        fd = open(buffer, O_RDONLY);
        if (fd < 0)
            continue;

        len = read(fd, buffer, sizeof(buffer));

        if (len > strlen(identifier))
            len = strlen(identifier);

        if (strncmp(identifier, buffer, len) == 0)
            found = true;

        close(fd);

        if (found)
            break;

        i2c_idx = -1;
    }

    (void)closedir(dp);

    if (i2c_idx < 0) {
        fprintf(stderr, "error: %s: no matching I2C device found\n", __func__);
        goto fail;
    }

    snprintf(buffer, sizeof(buffer), "/dev/i2c-%d", i2c_idx);
    fprintf(stdout, "info: %s: trying I2C device \"%s\"...\n", __func__, buffer);

    fd = open(buffer, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "error: %s: failed to open device (%s)\n", __func__, strerror(errno));
        goto fail;
    }

    slv = calloc(1, sizeof(struct i2c_slave));

    slv->fd = fd;
    slv->address = device_address;

    if (i2c_init(slv) < 0) {
        fprintf(stderr, "error: %s: failed to init device (%s)\n", __func__, strerror(errno));
        goto fail_init;
    }

    return slv;

fail_init:
    free(slv);

fail:
    return NULL;
}


static void
usage(const char *name)
{
    fprintf(stderr, "usage: %s <mode>\n\n", name);

    fprintf(stderr, "Control the headphone amplifier found in some Clevo laptops\n\n");

    fprintf(stderr, "Available modes:\n");
    fprintf(stderr, "\tinit\t\t\tinitialize amplifier (with default effect)\n");
    fprintf(stderr, "\teffect <index>\t\tapply effect\n");
    fprintf(stderr, "\tmute\t\t\tamplifier off\n");
    fprintf(stderr, "\tunmute\t\t\tamplifier on\n");
    fprintf(stderr, "\trecovery\n\n");

    fprintf(stderr, "Available effect indices:\n");
    fprintf(stderr, "\t0\t\tno change\n");
    fprintf(stderr, "\t1\t\tbass boost (default)\n");
    fprintf(stderr, "\t2\n");
    fprintf(stderr, "\t3\n");
    fprintf(stderr, "\t4\t\tboost all\n");
    fprintf(stderr, "\t5\n");
    fprintf(stderr, "\t6\n");
}

static int
parse_effect(int argc, char *argv[], enum e_effects *e)
{
    unsigned tmp;

    if (argc <= 1)
        return -1;

    if (sscanf(argv[1], "%u", &tmp) != 1)
        return -1;

    if (tmp >= num_effects)
        return -1;

    *e = tmp;

    return 0;
}

int main(int argc, char *argv[])
{
    int ret;
    struct i2c_slave *clevo_amp;
    enum e_modes mode;
    enum e_effects ef;

    if (argc <= 1) {
        usage(argv[0]);

        ret = 0;
        goto out;
    }

    clevo_amp = open_amplifier();
    if (clevo_amp == NULL) {
        fprintf(stderr, "error: %s: failed to open amplifier\n", __func__);

        ret = -1;
        goto out;
    }

    mode = unfmt_modes(argv[1]);

    if (mode == invalid) {
        fprintf(stderr, "error: %s: invalid mode selected\n", __func__);

        ret = -2;
        goto fail;
    }

    switch(mode) {
    case init:
        ret = amp_init(clevo_amp);
        break;

    case effect:
        ret = parse_effect(argc - 1, argv + 1, &ef);
        if (ret < 0) {
            fprintf(stderr, "error: %s: invalid effect selected\n", __func__);
            break;
        }

        ret = amp_effect(clevo_amp, ef);
        break;

    case mute:
        ret = amp_mute(clevo_amp, true);
        break;

    case unmute:
        ret = amp_mute(clevo_amp, false);
        break;

    default:
    case recovery:
        ret = amp_recovery(clevo_amp);
        break;
    }

    if (ret < 0) {
        fprintf(stderr, "error: %s: failed to execute operation (%d)\n", __func__, ret);
        ret = -2;
    }

fail:
    i2c_fini(clevo_amp);
    free(clevo_amp);

out:
    return ret;
}
