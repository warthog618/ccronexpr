#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#include "ccronexpr.h"

#ifndef VERSION
    #define VERSION "dev-build"
#endif

typedef struct {
    char* cmd;
    char* schedule;
    int verbose;
} TinyCronJob;

void output(const char *msg) {
    printf("[tinycron] %s\n", msg);
}

void sigchld_handler(int signo) {
    (void) signo;
    while (waitpid(-1, NULL, WNOHANG) > 0);
}

void sig_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        output("terminated");
        _exit(0);
    }
}

TinyCronJob optsFromEnv() {
    TinyCronJob opts = {0};
    if (getenv("TINYCRON_VERBOSE") != NULL) {
        opts.verbose = 1;
    }
    return opts;
}

void usage() {
    printf("Usage: tinycron [expression] [command]\n");
    exit(EXIT_FAILURE);
}

void message(const char *err, const char *msg) {
    if (strlen(msg) == 0) {
        output(err);
    } else {
        char errMsg[512];
        snprintf(errMsg, sizeof(errMsg), "%s %s", msg, err);
        output(errMsg);
    }
}

void messageInt(int err, const char *msg) {
    if (err) message(strerror(err), msg);
}

void run(TinyCronJob *job) {
    if (job->verbose) {
        message(job->cmd, "running job:");
    }

    messageInt(system(job->cmd), "job failed:");
}

int nap(TinyCronJob *job) {
    time_t current_time = time(NULL);
    time_t next_run;

    cron_expr expr;
    const char* err = NULL;
    cron_parse_expr(job->schedule, &expr, &err);

    if (err) {
        message(err, "error parsing cron expression:");
        return 1;
    }

    next_run = cron_next(&expr, current_time);

    if (job->verbose) {
        char msg[512];
        struct tm *time_info = localtime(&next_run);
        strftime(msg, sizeof(msg), "%Y-%m-%d %H:%M:%S", time_info);
        message(msg, "next job scheduled for");
    }

    int sleep_duration = next_run - current_time;
    sleep(sleep_duration);
    return 0;
}

int main(int argc, char *argv[]) {
    signal(SIGCHLD, sigchld_handler);
    signal(SIGTERM, sig_handler);
    signal(SIGINT,  sig_handler);

    if (argc < 2) {
        usage();
    }

    if (strcmp(argv[1], "version") == 0) {
        printf("tinycron version %s\n", VERSION);
        return EXIT_SUCCESS;
    }

    if (strcmp(argv[1], "help") == 0) {
        usage();
    }

    if (argc <= 2) {
        messageInt(1, "incorrect number of arguments");
        usage();
    }

    TinyCronJob job = optsFromEnv();
    job.schedule = argv[1];

    int cmd_len = 0;
    for (int i = 2; i < argc; i++) {
        cmd_len += strlen(argv[i]) * 2 + 3;
    }

    cmd_len += 1;

    char *cmd = malloc(cmd_len);
    if (!cmd) {
        perror("malloc");
        return EXIT_FAILURE;
    }
    
    for (int i = 2; i < argc; i++) {
        strcat(cmd, "\"");
        for(int j = 0; argv[i][j] != '\0'; j++) {
            if(argv[i][j] == '\"' || argv[i][j] == '\\') {
                strcat(cmd, "\\");
            }
            strncat(cmd, &argv[i][j], 1);
        }
        strcat(cmd, "\" ");
    }

    job.cmd = cmd;

    while (1) {
        if (nap(&job)) {
            perror("fatal error");
            break;
        }
        run(&job);
    }

    free(cmd);

    return EXIT_SUCCESS;
}
