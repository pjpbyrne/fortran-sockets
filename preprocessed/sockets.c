#define _POSIX_C_SOURCE 200809L   /* getaddrinfo, MSG_NOSIGNAL (POSIX.1-2008) */
#define _DARWIN_C_SOURCE          /* macOS: keep SO_NOSIGPIPE visible */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0   /* e.g. macOS: SIGPIPE suppressed via SO_NOSIGPIPE instead */
#endif

/**
 * Connects to a remote TCP host.
 *
 * @param host  Hostname or IP address (e.g., "example.com", "127.0.0.1", "::1").
 * @param port  Numeric port number (1-65535).
 * @return      A valid connected socket descriptor on success, or -1 on failure.
 */
int tcp_connect(const char *host, int port) {
    if (!host || port < 1 || port > 65535) {
        return -1;
    }

    char port_str[6];
    snprintf(port_str, sizeof(port_str), "%d", port);

    struct addrinfo hints;
    struct addrinfo *result = NULL;
    struct addrinfo *rp = NULL;
    int sockfd = -1;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;        /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM;    /* TCP stream sockets */
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_NUMERICSERV;    /* Optimization: treat service strictly as a numeric port */

    int s = getaddrinfo(host, port_str, &hints, &result);
    if (s != 0) {
        return -1;
    }

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        sockfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (sockfd == -1) {
            continue;
        }

#ifdef SO_NOSIGPIPE
        int one = 1;
        if (setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one)) == -1) {
            close(sockfd);
            sockfd = -1;
            continue;
        }
#endif

        if (connect(sockfd, rp->ai_addr, rp->ai_addrlen) == 0) {
            break; /* Success */
        }

        close(sockfd);
        sockfd = -1;
    }

    freeaddrinfo(result);
    return sockfd;
}

/**
 * Safely closes a socket descriptor.
 *
 * @param sockfd Socket file descriptor.
 * @return       0 on success, or -1 on error (with errno set).
 */
int tcp_close(int sockfd) {
    if (sockfd < 0) {
        errno = EBADF;
        return -1;
    }

    /* Do not retry on EINTR: on Linux the descriptor is already released,
       and retrying could close a descriptor reused by another thread. */
    return close(sockfd);
}

/**
 * Sends a full buffer over a stream socket, looping until all bytes
 * are transmitted or an error occurs.
 *
 * @param sockfd Socket file descriptor.
 * @param buf    Pointer to the data buffer to send.
 * @param len    Number of bytes to send.
 * @return       0 on success (all len bytes sent), or -1 on error.
 */
int tcp_send(int sockfd, const void *buf, size_t len) {
    if (sockfd < 0 || (!buf && len > 0)) {
        errno = EINVAL;
        return -1;
    }

    const char *ptr = (const char *)buf;
    size_t total_sent = 0;

    while (total_sent < len) {
        /* MSG_NOSIGNAL suppresses SIGPIPE if peer closed the connection;
           send() returns -1 with errno = EPIPE instead. */
        ssize_t bytes_sent = send(sockfd, ptr + total_sent, len - total_sent, MSG_NOSIGNAL);

        if (bytes_sent < 0) {
            if (errno == EINTR) {
                continue; /* Interrupted by signal, retry */
            }
            return -1;    /* Connection reset, broken pipe, or other error */
        }

        if (bytes_sent == 0) {
            /* Peer closed or cannot accept further data before completing transmission */
            errno = ECONNRESET;
            return -1;
        }

        total_sent += (size_t)bytes_sent;
    }

    return 0; /* Success: all bytes sent */
}

/**
 * Reads EXACTLY len bytes from a socket.
 * If the peer closes the connection before delivering len bytes,
 * this function considers it a failure, sets errno, and returns -1.
 *
 * @param sockfd Socket file descriptor.
 * @param buf    Destination buffer.
 * @param len    Total number of bytes required.
 * @return       0 on success (all len bytes received), or -1 on error/premature EOF.
 */
int tcp_recv(int sockfd, void *buf, size_t len) {
    if (sockfd < 0 || (!buf && len > 0)) {
        errno = EINVAL;
        return -1;
    }

    char *ptr = (char *)buf;
    size_t total_read = 0;

    while (total_read < len) {
        ssize_t n = recv(sockfd, ptr + total_read, len - total_read, 0);

        if (n < 0) {
            if (errno == EINTR) {
                continue; /* Interrupted by signal, retry */
            }
            return -1;    /* Underlying socket error */
        }

        if (n == 0) {
            /* Premature EOF: peer closed before sending expected payload */
            errno = ECONNRESET;
            return -1;
        }

        total_read += (size_t)n;
    }

    return 0; /* Success: exactly len bytes read */
}