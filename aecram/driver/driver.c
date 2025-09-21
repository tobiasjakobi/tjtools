/**
 * Driver to access the RAM of an auxiliary embedded controller (AEC).
 *
 * This AEC is different from the ACPI embedded controller.
 */

#include "aecram.h"

#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/errno.h>
#include <linux/fcntl.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/ioctl.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/moduleparam.h>
#include <linux/module.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <linux/version.h>

/**
 * References:
 * - https://8051enthusiast.github.io/2021/07/05/001-EC_legacy.html
 * - https://github.com/8051enthusiast/at51
 * - https://github.com/anarcheuz/8051-disassembler
 * - https://bluenowhere334.blogspot.com/2018/06/io-port-note.html
 * - https://linux.die.net/man/8/superiotool
 * - https://github.com/coreboot/coreboot/blob/main/util/superiotool/superiotool.c
 * - https://stackoverflow.com/questions/14194798/is-there-a-specification-of-x86-i-o-port-assignment
 */

#define CMD_TYPE_OFFSET_LOW	0x10
#define CMD_TYPE_OFFSET_HIGH	0x11
#define CMD_TYPE_SELECT_VALUE	0x12

/**
 * Command executed on the auxiliary embedded controller.
 */
struct aec_cmd {
	u8 cmd_type;
	u8 cmd_arg;
};

struct aecram_config {
	u8 addr_port; /* Address port on the host side. */
	u8 data_port; /* Data port on the host side. */

	u8 cmd_reg; /* Command register on the AEC side (2 bytes long). */
};

struct aecram_data {
	struct cdev dev;
	struct mutex mtx;

	const struct aecram_config *config;

	int major;
};

/**
 * Default AECRAM config.
 *
 * Only config for now. Should work for the AEC of the Ayaneo KUN.
 */
static const struct aecram_config config_default = {
	/* Standard SuperIO address/data port. */
	.addr_port = 0x4e,
	.data_port = 0x4f,

	.cmd_reg = 0x2e,
};

static const char driver_name[] = "aecram";

static struct aecram_data data;

static inline void cmd_out(const struct aecram_config *cfg, const struct aec_cmd *cmd)
{
	outb(cfg->cmd_reg + 0, cfg->addr_port);
	outb(cmd->cmd_type, cfg->data_port);

	outb(cfg->cmd_reg + 1, cfg->addr_port);
	outb(cmd->cmd_arg, cfg->data_port);
}

static inline u8 cmd_in(const struct aecram_config *cfg, const struct aec_cmd *cmd)
{
	outb(cfg->cmd_reg + 0, cfg->addr_port);
	outb(cmd->cmd_type, cfg->data_port);

	outb(cfg->cmd_reg + 1, cfg->addr_port);
	return inb(cfg->data_port);
}

static void offset_high(const struct aecram_config *cfg, u16 offset)
{
	const struct aec_cmd cmd = {
		.cmd_type = CMD_TYPE_OFFSET_HIGH,
		.cmd_arg = (offset >> 8) & 0xFF,
	};

	cmd_out(cfg, &cmd);
}

static void offset_low(const struct aecram_config *cfg, u16 offset)
{
	const struct aec_cmd cmd = {
		.cmd_type = CMD_TYPE_OFFSET_LOW,
		.cmd_arg = offset & 0xFF,
	};

	cmd_out(cfg, &cmd);
}

static void write_value(const struct aecram_config *cfg, u8 val)
{
	const struct aec_cmd cmd = {
		.cmd_type = CMD_TYPE_SELECT_VALUE,
		.cmd_arg = val,
	};

	cmd_out(cfg, &cmd);
}

static u8 read_value(const struct aecram_config *cfg)
{
	const struct aec_cmd cmd = {
		.cmd_type = CMD_TYPE_SELECT_VALUE,
	};

	return cmd_in(cfg, &cmd);
}

static int aecram_write(struct aecram_data *d, u16 offset, u8 val)
{
	const struct aecram_config *cfg = d->config;
	int ret;

	ret = mutex_lock_interruptible(&d->mtx);

	if (ret)
		return ret;

	offset_high(cfg, offset);
	offset_low(cfg, offset);

	write_value(cfg, val);

	mutex_unlock(&d->mtx);

	return 0;
}

static int aecram_read(struct aecram_data *d, u16 offset, u8 *val)
{
	const struct aecram_config *cfg = d->config;
	int ret;

	ret = mutex_lock_interruptible(&d->mtx);

	if (ret < 0)
		return ret;

	offset_high(cfg, offset);
	offset_low(cfg, offset);

	*val = read_value(cfg);

	mutex_unlock(&d->mtx);

	return 0;
}

static int aecram_write_buffer(struct aecram_data *d, u16 offset, const u8 *buf, u16 length)
{
	int ret;

	for (unsigned i = 0; i < length; ++i) {
		ret = aecram_write(d, offset + i, buf[i]);
		if (ret < 0)
			return ret;
	}
	return 0;
}

static int aecram_read_buffer(struct aecram_data *d, u16 offset, u8 *buf, u16 length)
{
	int ret;

	for (unsigned i = 0; i < length; ++i) {
		ret = aecram_read(d, offset + i, &buf[i]);
		if (ret < 0)
			return ret;
	}

	return 0;
}

static bool is_valid_param(u16 offset, u8 length)
{
	if ((unsigned)offset + (unsigned)length - 1 > 0xffff)
		return false;

	if (length > AECRAM_BUFFER_SIZE)
		return false;

	return true;
}

static int aecram_open(struct inode *inode, struct file *filp)
{
	struct aecram_data *d = container_of(inode->i_cdev, struct aecram_data, dev);

	filp->private_data = d;

	return 0;
}

static long aecram_unlocked_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	struct aecram_data *d = filp->private_data;
	int ret = 0;

	switch (cmd) {
		case IOCTL_AECRAM_SET_TYPE:
		{
			if (arg == AECRAM_TYPE_AYANEO) {
				d->config = &config_default;
			} else {
				ret = -EINVAL;
			}
		} break;

		case IOCTL_AECRAM_READ:
		{
			struct aecram_request *req = (struct aecram_request *)arg;

			u16 offset;
			u8 length;

			if (d->config == NULL)
				return -ENODEV;

			if (!access_ok(req, sizeof(struct aecram_request)))
				return -EFAULT;

			__get_user(offset, &req->offset);
			__get_user(length, &req->length);

			if (!is_valid_param(offset, length))
				return -EINVAL;

			if (length != 0) {
				u8 *buffer __free(kfree) = kzalloc(length, GFP_KERNEL);

				ret = aecram_read_buffer(d, offset, buffer, length);
				if (ret == 0) {
					if (__copy_to_user(req->buffer, buffer, length) != length)
						ret = -EFAULT;
				}
			}
		} break;

		case IOCTL_AECRAM_WRITE:
		{
			const struct aecram_request *req = (const struct aecram_request *)arg;

			u16 offset;
			u8 length;

			if (d->config == NULL)
				return -ENODEV;

			if (!access_ok(req, sizeof(struct aecram_request)))
				return -EFAULT;

			__get_user(offset, &req->offset);
			__get_user(length, &req->length);

			if (!is_valid_param(offset, length))
				return -EINVAL;

			if (length != 0) {
				u8 *buffer __free(kfree) = kzalloc(length, GFP_KERNEL);

				if (__copy_from_user(buffer, req->buffer, length) != length) {
					ret = -EFAULT;
				} else {
					ret = aecram_write_buffer(d, offset, buffer, length);
				}
			}
		} break;

		default:
		{
			/* Invalid ioctl. */
			ret = -EINVAL;
		} break;
	}

	return ret;
}

static const struct file_operations aecram_fops = {
	.owner = THIS_MODULE,
	.open = aecram_open,
	.unlocked_ioctl = aecram_unlocked_ioctl,
};

static int __init aecram_init(void)
{
	dev_t devno;
	int ret;

	memset(&data, 0, sizeof(data));
	mutex_init(&data.mtx);

	ret = alloc_chrdev_region(&devno, 0, 1, driver_name);
	if (ret < 0) {
		pr_err("aecram: failed to alloc chrdev: %d\n", ret);

		return -ENOMEM;
	}

	data.major = MAJOR(devno);

	cdev_init(&data.dev, &aecram_fops);

	ret = cdev_add(&data.dev, devno, 1);
	if (ret < 0) {
		pr_err("aecram: failed to add cdev: %d\n", ret);

		unregister_chrdev_region(MKDEV(data.major, 0), 1);

		return -ENOMEM;
	}

	pr_info("aecram: driver loaded\n");

	return 0;
}

static void __exit aecram_exit(void)
{
	cdev_del(&data.dev);
	unregister_chrdev_region(MKDEV(data.major, 0), 1);
}

module_init(aecram_init);
module_exit(aecram_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Tobias Jakobi <tjakobi@math.uni-bielefeld.de>");
MODULE_DESCRIPTION("Auxiliary embedded controller RAM driver");
MODULE_VERSION("1.0");
