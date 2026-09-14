#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int fixture_pipe(int ends[2]) {
  int result = pipe(ends);
  const char *mode = getenv("BASH_PIPE_FIXTURE");
  if (result == 0 && mode && strcmp(mode, "fcntl-failure") == 0) {
    /* only this child's new write fd is invalid; F_GETFL must fail. */
    close(ends[1]);
    const char *log_path = getenv("BASH_PIPE_FIXTURE_LOG");
    int log_fd = log_path ? open(log_path, O_WRONLY | O_CREAT | O_APPEND, 0600) : -1;
    const char event[] = "{\"action\":\"invalid-write-end\"}\n";
    if (log_fd < 0 || write(log_fd, event, sizeof event - 1) != sizeof event - 1)
      _exit(125);
    close(log_fd);
  }
  return result;
}

/* model one 512-byte pipe write without consuming shared pipe capacity. */
static ssize_t fixture_write(int fd, const void *data, size_t count) {
  struct stat info;
  const char *mode = getenv("BASH_PIPE_FIXTURE");
  const char *log_path = getenv("BASH_PIPE_FIXTURE_LOG");
  if (!mode || fd <= STDERR_FILENO || fstat(fd, &info) != 0 ||
      !S_ISFIFO(info.st_mode))
    return write(fd, data, count);

  int flags = fcntl(fd, F_GETFL);
  int nonblocking = (flags & O_NONBLOCK) != 0;
  int limited = count > 512;
  const char *action = limited ? (nonblocking ? mode : "blocked") : "fits";
  if (log_path) {
    char event[192];
    int length = snprintf(event, sizeof event,
        "{\"pid\":%d,\"fd\":%d,\"requested\":%zu,\"nonblocking\":%s,\"action\":\"%s\"}\n",
        getpid(), fd, count, nonblocking ? "true" : "false", action);
    int log_fd = open(log_path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (log_fd < 0 || write(log_fd, event, length) != length)
      _exit(125);
    close(log_fd);
  }

  if (!limited)
    return write(fd, data, count);
  if (!nonblocking) {
    /* the reader cannot start until bash finishes this blocking write. */
    if (write(fd, data, 512) != 512)
      _exit(125);
    for (;;)
      pause();
  }
  if (strcmp(mode, "eagain") == 0) {
    errno = EAGAIN;
    return -1;
  }
  ssize_t written = write(fd, data, 512);
  if (written >= 0)
    errno = 0;
  return written;
}

__attribute__((used)) static struct {
  const void *replacement;
  const void *original;
} interpose_write __attribute__((section("__DATA,__interpose"))) = {
  (const void *)fixture_write, (const void *)write
};

__attribute__((used)) static struct {
  const void *replacement;
  const void *original;
} interpose_pipe __attribute__((section("__DATA,__interpose"))) = {
  (const void *)fixture_pipe, (const void *)pipe
};
