#define _POSIX_C_SOURCE 200809L
#define _DARWIN_C_SOURCE          /* macOS: keep TCP_KEEPALIVE visible */

#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

/* Must match KEEPALIVE_* in src/sockets.c */
#define EXPECT_KEEPIDLE  15
#define EXPECT_KEEPINTVL 15
#define EXPECT_KEEPCNT   4

static int get_int_opt(int fd, int level, int opt) {
    int value = -1;
    socklen_t len = sizeof(value);
    if (getsockopt(fd, level, opt, &value, &len) == -1) {
        return -1;
    }
    return value;
}

/**
 * Test helper: checks the options f90sockets_connect should have applied.
 *
 * @return 0 if all are as expected, otherwise a bitmask of failures:
 *         1 TCP_NODELAY, 2 SO_KEEPALIVE, 4 keepalive idle, 8 keepalive
 *         interval, 16 keepalive count, 32 FD_CLOEXEC. Timing options are
 *         only checked where the platform defines them.
 */
int f90sockets_test_check_sockopts(int fd, int expect_nodelay) {
    int failed = 0;

    if ((get_int_opt(fd, IPPROTO_TCP, TCP_NODELAY) != 0) != (expect_nodelay != 0)) {
        failed |= 1;
    }
    if (get_int_opt(fd, SOL_SOCKET, SO_KEEPALIVE) <= 0) {
        failed |= 2;
    }
#if defined(TCP_KEEPIDLE)
    if (get_int_opt(fd, IPPROTO_TCP, TCP_KEEPIDLE) != EXPECT_KEEPIDLE) {
        failed |= 4;
    }
#elif defined(TCP_KEEPALIVE)
    if (get_int_opt(fd, IPPROTO_TCP, TCP_KEEPALIVE) != EXPECT_KEEPIDLE) {
        failed |= 4;
    }
#endif
#ifdef TCP_KEEPINTVL
    if (get_int_opt(fd, IPPROTO_TCP, TCP_KEEPINTVL) != EXPECT_KEEPINTVL) {
        failed |= 8;
    }
#endif
#ifdef TCP_KEEPCNT
    if (get_int_opt(fd, IPPROTO_TCP, TCP_KEEPCNT) != EXPECT_KEEPCNT) {
        failed |= 16;
    }
#endif
    int fdflags = fcntl(fd, F_GETFD);
    if (fdflags == -1 || !(fdflags & FD_CLOEXEC)) {
        failed |= 32;
    }

    return failed;
}
