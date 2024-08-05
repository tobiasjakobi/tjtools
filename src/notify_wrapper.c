/*
 * gcc -lsystemd -O2 -o notify_wrapper notify_wrapper.c
 */

#include <systemd/sd-login.h>
#include <unistd.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *notify_send = "/usr/bin/notify-send";

static int exec_notify(uid_t id, const char *summary, const char *body, const char *icon) {
    char xdg_rundir[64];
    char icon_opt[512];

    snprintf(xdg_rundir, sizeof(xdg_rundir), "XDG_RUNTIME_DIR=/var/run/user/%u", id);

    const char *notify_envp[] = {
        xdg_rundir,
        NULL,
    };

    if (icon != NULL) {
        snprintf(icon_opt, sizeof(icon_opt), "--icon=/usr/share/icons/%s", icon);

        const char *notify_argv[] = {
            notify_send,
            icon_opt,
            summary,
            body,
            NULL,
        };

        return execve(notify_send, (char * const*)notify_argv, (char * const*)notify_envp);
    } else {
        const char *notify_argv[] = {
            notify_send,
            summary,
            body,
            NULL,
        };

        return execve(notify_send, (char * const*)notify_argv, (char * const*)notify_envp);
    }
}

int main(int argc, char *argv[]) {
    const uid_t euid = geteuid();

    int ret;
    char **sessions = NULL;
    unsigned num_sessions;

    ret = sd_get_sessions(&sessions);
    if (ret < 0) {
        fprintf(stderr, "error: no sessions available: %d\n", ret);

        return -1;
    } else if (ret == 0) {
      return 0;
    }

    num_sessions = ret;

    bool euid_found = false;
    unsigned session_id;

    for (unsigned i = 0; i < num_sessions; ++i) {
        session_id = atoi(sessions[i]);

        uid_t session_uid;
        ret = sd_session_get_uid(sessions[i], &session_uid);
        if (ret < 0) {
            fprintf(stderr, "warn: failed to query UID of session: %s: %d\n", sessions[i], ret);

            continue;
        }

        if (session_uid != euid) {
            continue;
        }

        char *session_type;
        ret = sd_session_get_type(sessions[i], &session_type);
        if (ret < 0) {
            fprintf(stderr, "warn: failed to query type of session: %s: %d\n", sessions[i], ret);

            continue;
        }

        if (strcmp(session_type, "wayland") == 0) {
            euid_found = true;

            break;
        }
    }

    for (unsigned i = 0; i < num_sessions; ++i) {
        free(sessions[i]);
    }

    free(sessions);
    sessions = NULL;

    if (!euid_found) {
        return 0;
    }

    if (argc < 3) {
        fprintf(stderr, "error: invalid number of arguments: %d\n", argc);

        return -2;
    }

    const char *icon = argc > 3 ? argv[3] : NULL;

    return exec_notify(euid, argv[1], argv[2], icon);
}
