#define _ISOC99_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <signal.h>
#include <errno.h>
#include <limits.h>
#include <ctype.h>

#include "ccronexpr.h"

#ifndef VERSION
    #define VERSION "dev-build"
#endif

typedef struct { char *shell, *cmd, *schedule; int verbose; } TinyCronJob;

void output(const char *msg) {
    printf("[supertinycron] %s\n", msg);
}

void sigchld_handler(int signo) {
    (void) signo;
    /*while (waitpid(-1, NULL, WNOHANG) > 0);*/
}

void sig_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        ssize_t ignored;
        static const char msg[] = "[supertinycron] terminated\n";
        ignored = write(STDERR_FILENO, msg, sizeof(msg) - 1);
        (void)ignored;
        _exit(0);
    }
}

int cron_system(const char *shell, const char *command) {
    int status;
    pid_t wpid;
    pid_t pid;

    pid = fork();
    if (pid == 0) {
        execl(shell, shell, "-c", command, NULL);
        perror("execl");
        _exit(127);
    }
    if (pid < 0) {
        perror("fork");
        return -1;
    }

    do {
        wpid = waitpid(pid, &status, 0);
    } while (wpid < 0 && errno == EINTR);

    if (wpid < 0) {
        perror("waitpid");
        return -1;
    }
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return -1;
}

TinyCronJob optsFromEnv() {
    TinyCronJob opts = {0, 0, 0, 0};
    if (getenv("TINYCRON_VERBOSE") != NULL) opts.verbose = 1;
    opts.shell = getenv("SHELL");
    if (!opts.shell) opts.shell = (char *)"/bin/sh";
    return opts;
}

void usage() {
    printf("Usage: supertinycron [expression] [command]\n");
    exit(EXIT_FAILURE);
}

void message(const char *err, const char *msg) {
    if (strlen(msg) == 0) output(err);
    else {
        char errMsg[512];
        snprintf(errMsg, sizeof(errMsg), "%s %s", msg, err);
        output(errMsg);
    }
}

void messageInt(int err, const char *msg) {
    if (err) message(strerror(err), msg);
}

void exitOnErr(int err, const char *msg) {
    if (err) {
        messageInt(err, msg);
        exit(EXIT_FAILURE);
    }
}

void run(TinyCronJob *job) {
    int rc;
    char status[64];
    if (job->verbose) message(job->cmd, "running job:");

    rc = cron_system(job->shell, job->cmd);
    if (rc == 0) return;
    if (rc < 0) {
        message("internal execution error", "job failed:");
        return;
    }
    snprintf(status, sizeof(status), "exit code %d", rc);
    message(status, "job failed:");
}

int nap(TinyCronJob *job) {
    time_t current_time = time(NULL), next_run;
    time_t sleep_left;
    unsigned int sleep_chunk;

    cron_expr expr;
    const char* err = NULL;
    cron_parse_expr(job->schedule, &expr, &err);

    if (err) {
        message(err, "error parsing cron expression:");
        return 1;
    }

    next_run = cron_next(&expr, current_time);
    if (next_run == CRON_INVALID_INSTANT) {
        message("no next matching instant", "error creating job:");
        return 1;
    }

    if (job->verbose) {
        char msg[512];
        struct tm *time_info = localtime(&next_run);
        if (!time_info || !strftime(msg, sizeof(msg), "%Y-%m-%d %H:%M:%S", time_info)) strcpy(msg, "(invalid)");
        message(msg, "next job scheduled for");
    }

    sleep_left = next_run - current_time;
    while (sleep_left > 0) {
        sleep_chunk = (sleep_left > (time_t)UINT_MAX) ? UINT_MAX : (unsigned int)sleep_left;
        sleep_left = (time_t)sleep(sleep_chunk);
    }
    return 0;
}

char* find_nth(const char* str, char ch, int n) {
    int count = 0;
    while (*str) {
        if (*str == ch && ++count == n) return (char*)str;
        str++;
    }
    return NULL;
}

void parse_line(char *line, TinyCronJob *job, int count) {
    job->schedule = line;
    job->cmd = find_nth(line, ' ', line[0] == '@' ? 1 : count);

    if (!job->cmd) {
        message("incomplete cron expression", "error:");
        exit(EXIT_FAILURE);
    }
    *job->cmd = '\0';
    ++job->cmd;
}
int main(int argc, char *argv[]) {
    int i, line_len = 0;
    char *line;
    int exit_code;
    TinyCronJob job;

    /*signal(SIGCHLD, sigchld_handler);*/
    signal(SIGTERM, sig_handler);
    signal(SIGINT,  sig_handler);

    exit_code = EXIT_SUCCESS;

    if (argc < 2 || strcmp(argv[1], "help") == 0) usage();

    if (strcmp(argv[1], "version") == 0) {
        printf("supertinycron version %s\n", VERSION);
        return EXIT_SUCCESS;
    }
    if (argc < 3) usage();

    job = optsFromEnv();

    for (i = 1; i < argc; i++) {
        line_len += strlen(argv[i]);
    }
    line_len += argc - 2; /* spaces between argv[1..argc-1] */
    line_len += 1;        /* trailing '\0' */

    line = (char *)malloc(line_len);
    if (!line) {
        perror("malloc");
        return EXIT_FAILURE;
    }
    strcpy(line, argv[1]);
    for (i = 2; i < argc; i++) {
        strcat(line, " ");
        strcat(line, argv[i]);
    }

    if (job.verbose) message(line, "line");

    parse_line(line, &job, 7);

    while (1) {
        if (nap(&job)) {
            exit_code = EXIT_FAILURE;
            break;
        }
        run(&job);
    }

    free(line);

    return exit_code;
}
