/* A minimal wrapper for socket communication.

Copyright (C) 2013, Joshua More and Michele Ceriotti

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <netdb.h>

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0
#endif

void close_socket(int psockfd)
/* Close a socket. */
{
   if (psockfd >= 0)
   {
      close(psockfd);
   }
}

void open_socket(int *psockfd, int inet, int port, const char *host)
/* Opens a socket.

Args:
   psockfd: The id of the socket that will be created.
   inet: An integer that determines whether the socket will be an inet or unix
      domain socket. Gives unix if 0, inet otherwise.
   port: The port number for the socket to be created.
   host: The name of the host server.
*/
{
   int sockfd, ai_err;

   if (inet > 0)
   { // Creates an internet socket
      struct addrinfo hints, *res;
      char service[32];

      memset(&hints, 0, sizeof(hints));
      hints.ai_socktype = SOCK_STREAM;
      hints.ai_family = AF_INET;
      hints.ai_flags = AI_PASSIVE;

      snprintf(service, sizeof(service), "%d", port);
      ai_err = getaddrinfo(host, service, &hints, &res);
      if (ai_err != 0)
      {
         fprintf(stderr, "Error fetching host data for '%s': %s\n", host, gai_strerror(ai_err));
         exit(-1);
      }

      // Creates socket
      sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
      if (sockfd < 0)
      {
         perror("Error opening socket");
         freeaddrinfo(res);
         exit(-1);
      }

      // Makes connection
      if (connect(sockfd, res->ai_addr, res->ai_addrlen) < 0)
      {
         perror("Error opening INET socket: wrong port or server unreachable");
         close(sockfd);
         freeaddrinfo(res);
         exit(-1);
      }
      freeaddrinfo(res);
   }
   else
   { // Creates a UNIX domain socket
      struct sockaddr_un serv_addr;

      memset(&serv_addr, 0, sizeof(serv_addr));
      serv_addr.sun_family = AF_UNIX;
      
      int path_len = snprintf(serv_addr.sun_path, sizeof(serv_addr.sun_path), "/tmp/ipi_%s", host);
      if (path_len < 0 || (size_t)path_len >= sizeof(serv_addr.sun_path))
      {
         fprintf(stderr, "Error: UNIX socket path too long for host '%s'\n", host);
         exit(-1);
      }

      sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
      if (sockfd < 0)
      {
         perror("Error opening UNIX socket creation");
         exit(-1);
      }

      if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
      {
         perror("Error opening UNIX socket: path unavailable, or server not listening");
         close(sockfd);
         exit(-1);
      }
   }

   *psockfd = sockfd;
}

void writebuffer(int sockfd, const char *data, int len)
/* Writes to a socket. */
{
   int n = 0, nw;

   while (n < len)
   {
      nw = send(sockfd, &data[n], len - n, MSG_NOSIGNAL);

      if (nw <= 0) // Catches write errors (-1) and unexpected EOF/closed socket (0)
      {
         perror("Error writing to socket: server has quit or connection broke");
         exit(-1);
      }

      n += nw;
   }
}

void readbuffer(int sockfd, char *data, int len)
/* Reads from a socket. */
{
   int n = 0, nr;

   // Loop until we have read exactly 'len' bytes
   while (n < len)
   {
      nr = read(sockfd, &data[n], len - n);
      
      if (nr <= 0) // Catches both errors (-1) and unexpected EOF (0)
      {
         perror("Error reading from socket: server has quit or connection broke");
         exit(-1);
      }
      
      n += nr;
   }
}
