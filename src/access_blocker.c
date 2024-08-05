// SPDX-License-Identifier: GPL-2.0

/**
 * Modifies behaviour in Chromium/Electron's code:
 * - void DrmRenderNodePathFinder::FindDrmRenderNodePath()
 * - void VADisplayStateSingleton::PreSandboxInitialization()
 */

#include <linux/limits.h>
#include <sys/stat.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>

#if !defined(TJTOOLS_PUBLIC)
#define TJTOOLS_PUBLIC
#endif

#define ARRAY_SIZE(_x_) (sizeof(_x_) / sizeof(_x_[0]))

typedef void *(*hook_func_t)(int);

static hook_func_t __real_func0, __real_func1;

static const char *__blocked_paths[] = {
    "/dev/dri/card0",
    "/dev/dri/renderD128",
};

static __ino_t __blocked_inodes[ARRAY_SIZE(__blocked_paths)];

static void __hook_init() __attribute__ ((constructor));

static void __hook_init() {
    int ret;
    unsigned i;
    struct stat path_stat;

    fprintf(stderr, "info: installing hooks...\n");

    __real_func0 = (hook_func_t)(intptr_t)dlsym(RTLD_NEXT, "drmGetVersion");
    __real_func1 = (hook_func_t)(intptr_t)dlsym(RTLD_NEXT, "gbm_create_device");

    for (i = 0; i < ARRAY_SIZE(__blocked_paths); ++i) {
        ret = stat(__blocked_paths[i], &path_stat);
        if (ret < 0) {
            fprintf(stderr, "error: failed to find FD for: %s\n", __blocked_paths[i]);
            break;
        }

        __blocked_inodes[i] = path_stat.st_ino;
    }
}

static bool __is_blocked(__ino_t node) {
    for (unsigned i = 0; i < ARRAY_SIZE(__blocked_inodes); ++i) {
        if (__blocked_inodes[i] == node) {
            return true;
        }
    }

    return false;
}

TJTOOLS_PUBLIC void *drmGetVersion(int fd) {
    int ret;
    struct stat fd_stat;

    ret = fstat(fd, &fd_stat);
    if (ret == 0) {
        if (__is_blocked(fd_stat.st_ino)) {
            fprintf(stderr, "info: blocking drmGetVersion() to FD: %d\n", fd);

            return NULL;
        }
    }

    if (__real_func0 == NULL) {
        return NULL;
    }

    return __real_func0(fd);
}

TJTOOLS_PUBLIC void *gbm_create_device(int fd) {
    int ret;
    struct stat fd_stat;

    ret = fstat(fd, &fd_stat);
    if (ret == 0) {
        if (__is_blocked(fd_stat.st_ino)) {
            fprintf(stderr, "info: blocking gbm_create_device() to FD: %d\n", fd);

            return NULL;
        }
    }

    if (__real_func1 == NULL) {
        return NULL;
    }

    return __real_func1(fd);
}
