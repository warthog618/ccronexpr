# supertinycron
A very small replacement for cron. Particularly useful within containers and for distributing cron tasks alongside a project as a standalone file.

## Installing

```bash
make
sudo mv supertinycron /usr/local/bin/
```

# Usage

```
supertinycron [expression] [command...]
```

Tinycron can be conveniently used in your scripts interpreter line:
```bash
#!/usr/local/bin/supertinycron */5 * * * * * /bin/sh
echo "Current time: $(date)"
```

Or invoked directly via commandline:
```bash
$ supertinycron '*/5 * * * * *' /bin/echo hello
```


## Expressions

Tinycron uses and supports expressions from the [cronexpr](https://github.com/exander77/supertinycron) library. Some examples:

* `@daily` - run once daily, at midnight
* `* 15 * * * * *` - run at minute `:15` of every hour
* `*/30 * * * * * *` - run every 30 seconds

## Config

TinyCron can be configured by setting the below environmental variables to a non-empty value:

Variable | Description
--- | ---
TINYCRON_VERBOSE | Enable verbose output


Cron expression parsing in ANSI C
=================================

[![Build](https://github.com/mdvorak/ccronexpr/actions/workflows/build.yml/badge.svg)](https://github.com/mdvorak/ccronexpr/actions/workflows/build.yml)

Given a cron expression and a date, you can get the next date which satisfies the cron expression.

Supports cron expressions with `seconds` field. Based on implementation of [CronSequenceGenerator](https://github.com/spring-projects/spring-framework/blob/babbf6e8710ab937cd05ece20270f51490299270/spring-context/src/main/java/org/springframework/scheduling/support/CronSequenceGenerator.java) from Spring Framework.

Compiles and should work on Linux (GCC/Clang), Mac OS (Clang), Windows (MSVC), Android NDK, iOS and possibly on other platforms with `time.h` support.

Supports compilation in C (89) and in C++ modes.

Usage example
-------------

    #include "ccronexpr.h"

    cron_expr expr;
    const char* err = NULL;
    memset(&expr, 0, sizeof(expr));
    cron_parse_expr("0 */2 1-4 * * *", &expr, &err);
    if (err) ... /* invalid expression */
    time_t cur = time(NULL);
    time_t next = cron_next(&expr, cur);


Compilation and tests run examples
----------------------------------

    gcc ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c89 -DCRON_TEST_MALLOC -o a.out && ./a.out
    g++ ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c++11 -DCRON_TEST_MALLOC -o a.out && ./a.out
    g++ ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c++11 -DCRON_TEST_MALLOC -DCRON_COMPILE_AS_CXX -o a.out && ./a.out

    clang ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c89 -DCRON_TEST_MALLOC -o a.out && ./a.out
    clang++ ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c++11 -DCRON_TEST_MALLOC -o a.out && ./a.out
    clang++ ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c++11 -DCRON_TEST_MALLOC -DCRON_COMPILE_AS_CXX -o a.out && ./a.out

    cl ccronexpr.c ccronexpr_test.c /W4 /D_CRT_SECURE_NO_WARNINGS && ccronexpr.exe

Examples of supported expressions
---------------------------------

Expression, input date, next date:

    "*/15 * 1-4 * * *",  "2012-07-01_09:53:50", "2012-07-02_01:00:00"
    "0 */2 1-4 * * *",   "2012-07-01_09:00:00", "2012-07-02_01:00:00"
    "0 0 7 ? * MON-FRI", "2009-09-26_00:42:55", "2009-09-28_07:00:00"
    "0 30 23 30 1/3 ?",  "2011-04-30_23:30:00", "2011-07-30_23:30:00"

See more examples in [tests](https://github.com/staticlibs/ccronexpr/blob/a1343bc5a546b13430bd4ac72f3b047ac08f8192/ccronexpr_test.c#L251).

Timezones
---------

This implementation does not support explicit timezones handling. By default, all dates are
processed as UTC (GMT) dates without timezone information. 

To use local dates (current system timezone) instead of GMT compile with `-DCRON_USE_LOCAL_TIME`, example:

    gcc -DCRON_USE_LOCAL_TIME ccronexpr.c ccronexpr_test.c -I. -Wall -Wextra -std=c89 -DCRON_TEST_MALLOC -o a.out && TZ="America/Toronto" ./a.out

License information
-------------------

This project is released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Changelog
---------

**HEAD**

* added CMake build
* added GitHub Workflow for continuous testing
* fixed type casts to support `-Wconvert`
* added tests for cron_prev and leap years
* fixed tests to work with `CRON_USE_LOCAL_TIME`
* added [ESP-IDF](./ESP-IDF.md) usage guide

**2019-03-27**

 * `CRON_USE_LOCAL_TIME` usage fixes

**2018-05-23**

 * merged [#8](https://github.com/staticlibs/ccronexpr/pull/8)
 * merged [#9](https://github.com/staticlibs/ccronexpr/pull/9)
 * minor cleanups

**2018-01-27**

 * merged [#6](https://github.com/staticlibs/ccronexpr/pull/6)
 * updated license file (to the one parse-able by github)

**2017-09-24**

 * merged [#4](https://github.com/staticlibs/ccronexpr/pull/4)

**2016-06-17**

 * use thread-safe versions of `gmtime` and `localtime`

**2015-02-28**

 * initial public version
