#ifndef __AECRAM_H_
#define __AECRAM_H_

#include <linux/ioctl.h>
#include <linux/types.h>

#define AECRAM_BUFFER_SIZE	64
#define AECRAM_IOCTL_BASE	0x40

#define AECRAM_TYPE_AYANEO	1

struct aecram_request {
	__u16 offset;
	__u8 length;
	__u8 reserved;
	__u8 buffer[AECRAM_BUFFER_SIZE];
};

#define IOCTL_AECRAM_SET_TYPE	_IOW(AECRAM_IOCTL_BASE, 1, int)
#define IOCTL_AECRAM_READ	_IOWR(AECRAM_IOCTL_BASE, 2, struct aecram_request)
#define IOCTL_AECRAM_WRITE	_IOW(AECRAM_IOCTL_BASE, 3, struct aecram_request)

#endif // __AECRAM_H_
