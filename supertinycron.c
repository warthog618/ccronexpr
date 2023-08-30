#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>

#define VERSION "dev-build"

typedef struct {
    char* cmd;
    char* args;
    char* schedule;
    int verbose;
} TinyCronJob;

void output(const char *msg, ...) {
    printf("[tinycron] %s\n", msg);
}

void errHandler(int err, const char *msg) {
    if (err) {
        if (strlen(msg) == 0) {
            output(strerror(err));
        } else {
            char errMsg[512];
            snprintf(errMsg, sizeof(errMsg), "%s %s", msg, strerror(err));
            output(errMsg);
        }
    }
}

void exitOnErr(int err, const char *msg) {
    if (err) {
        errHandler(err, msg);
        exit(1);
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
    exit(1);
}

void run(TinyCronJob *job) {
    char command[512];
    snprintf(command, sizeof(command), "%s %s", job->cmd, job->args);

    if (job->verbose) {
        char msg[512];
        snprintf(msg, sizeof(msg), "running job: %s %s", job->cmd, job->args);
        output(msg);
    }

    int err = system(command);
    errHandler(err, "job failed");
}

#include "ccronexpr.h"

void nap(TinyCronJob *job) {
    time_t current_time = time(NULL);
    time_t next_run;

    cron_expr expr;
    const char* err = NULL;
    cron_parse_expr(job->schedule, &expr, &err);

    if (err) {
        char errMsg[512];
        snprintf(errMsg, sizeof(errMsg), "error parsing cron expression: %s", err);
        output(errMsg);
        return;
    }

    next_run = cron_next(&expr, current_time);

    if (job->verbose) {
        char msg[512];
        struct tm *time_info = localtime(&next_run);
        strftime(msg, sizeof(msg), "next job scheduled for %Y-%m-%d %H:%M:%S", time_info);
        output(msg);
    }

    int sleep_duration = next_run - current_time;
    sleep(sleep_duration);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        usage();
    }

    if (strcmp(argv[1], "version") == 0) {
        printf("tinycron version %s\n", VERSION);
        exit(0);
    }

    if (strcmp(argv[1], "help") == 0) {
        usage();
    }

    if (argc <= 2) {
        errHandler(1, "incorrect number of arguments");
        usage();
    }

    TinyCronJob job = optsFromEnv();
    job.schedule = argv[1];
    job.cmd = argv[2];
    job.args = argv[3];

    while (1) {
        nap(&job);
        run(&job);
    }

    return 0;
}
