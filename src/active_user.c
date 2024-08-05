// SPDX-License-Identifier: GPL-2.0

#include <systemd/sd-login.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if !defined(TJTOOLS_PUBLIC)
#define TJTOOLS_PUBLIC
#endif

TJTOOLS_PUBLIC int get_active_user(uint32_t *user_id) {
    int ret;
    char **sessions = NULL;
    unsigned num_sessions;

    ret = sd_get_sessions(&sessions);
    if (ret < 0) {
        fprintf(stderr, "error: failed to determine sessions: %d\n", ret);

        return -1;
    } else if (ret == 0) {
        return 0;
    }

    num_sessions = ret;

    for (unsigned i = 0; i < num_sessions; ++i) {
        const char *session = sessions[i];

        if (sd_session_is_remote(session) != 0) {
            continue;
        }

        if (sd_session_is_active(session) == 0) {
            continue;
        }

        uid_t session_uid;
        ret = sd_session_get_uid(session, &session_uid);
        if (ret < 0) {
            fprintf(stderr, "warn: failed to query UID of session: %s: %d\n", session, ret);

            continue;
        }

        char *session_type;
        ret = sd_session_get_type(session, &session_type);
        if (ret < 0) {
            fprintf(stderr, "warn: failed to query type of session: %s: %d\n", sessions[i], ret);

            continue;
        }

        const bool is_wayland = strcmp(session_type, "wayland") == 0;

        free(session_type);

        if (is_wayland) {
            *user_id = session_uid;
            ret = 1;

            break;
        }
    }

    for (unsigned i = 0; i < num_sessions; ++i) {
        free(sessions[i]);
    }

    free(sessions);
    sessions = NULL;

    return ret;
}
