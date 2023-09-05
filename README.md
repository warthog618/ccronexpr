
supertinycron
=============

A very small replacement for cron. Particularly useful within containers and for distributing cron tasks alongside a project as a standalone file.

Installing
----------

```bash
make
sudo mv supertinycron /usr/local/bin/
```

Usage
-----

```
supertinycron [expression] [command...]
```

Supertinycron can be conveniently used in your scripts interpreter line:
```bash
#!/usr/local/bin/supertinycron */5 * * * * * * /bin/sh
echo "Current time: $(date)"
```

Or invoked directly via commandline:
```bash
$ supertinycron '*/5 * * * * * *' /bin/echo hello
```

Implementation
--------------
This reference follows:
* [1] https://github.com/gorhill/cronexpr/blob/master/README.md
* [2] https://www.javadoc.io/doc/org.quartz-scheduler/quartz/latest/org/quartz/CronExpression.html
* [3] https://github.com/staticlibs/ccronexpr/blob/master/README.md
* [4] https://github.com/mdvorak/ccronexpr/blob/main/README.md
* [5] https://en.wikipedia.org/wiki/Cron#CRON_expression

		Field name     Mandatory?   Allowed values          Allowed special characters
		----------     ----------   --------------          ---------------
		Second         No           0-59                    * / , -
		Minute         Yes          0-59                    * / , -
		Hour           Yes          0-23                    * / , -
		Day of month   Yes          1-31                    * / , - L W
		Month          Yes          1-12 or JAN-DEC         * / , -
		Day of week    Yes          0-6,7 or SAT-SUN,SAT    * / , - L #
		Year           No           1970–2199               * / , -

Note that SAT is represented twice in Day of week as 0 and 7. This to comply with http://linux.die.net/man/5/crontab#.
Note that Year spans to 2199, that follows [2] and is different from [1] which is only 2099.

#### Asterisk `*`
The asterisk indicates that the cron expression matches for all values of the field. For example, using an asterisk in the Month field indicates every month.

#### Hyphen `-`
Hyphens define ranges. For example, using hypen in the Year field: `2000-2010` indicates every year between `2000` and `2010` AD, inclusive.

#### Slash `/`
Slashes describe increments of ranges. For example, using slash in the Minute field: `3-59/15` indicates the third minute of the hour and every 15 minutes thereafter. The form `*/...` is equivalent to the form "first-last/...", that is, an increment over the largest possible range of the field.

#### Comma `,`
Commas are used to separate items of a list. For example, using comma in Day of week field: `MON,WED,FRI` means Mondays, Wednesdays and Fridays.

#### `L`
`L` stands for "last". When used in the Day of week field, it allows you to specify constructs such as "the last Friday" (`5L`) of a given month. In the Day of month field, it specifies the last day of the month.

If it is used in Day of week field by itlsef, it is equivalent to `7` or `SAT`, meaning expressions `* * * * * L *` and `* * * * * 7 *` are equivalent.

If it is used in Day of week field after another value, it means "the last weekday of the month", where weekday is Monday, Tuesday, ..., Sunday. For eample, "6L" means "the last friday of the month".

If it is used in Day of month field follow by a negative number. For example, "L-3", it means "third to last day of the calendar month".

When using the 'L' option, it is important not to specify lists, or ranges of values, as you'll get confusing/unexpected results.

#### `W`
The `W` character is allowed for the Day of month field. This character is used to specify the business day (Monday-Friday) nearest the given day. As an example, if you were to specify `15W` as the value for the Day of month field, the meaning is: "the nearest business day to the 15th of the month."

So, if the 15th is a Saturday, the trigger fires on Friday the 14th. If the 15th is a Sunday, the trigger fires on Monday the 16th. If the 15th is a Tuesday, then it fires on Tuesday the 15th. However if you specify `1W` as the value for day-of-month, and the 1st is a Saturday, the trigger fires on Monday the 3rd, as it does not "jump" over the boundary of a month's days.

The `W` character can be specified only when the Day of month is a single day, not a range or list of days.

The `W` character can also be combined with `L`, i.e. `LW` to mean "the last business day of the month."

By itself it equivalent to range `1-5`, meaning expressions `* * * W * * *` and `* * * * * 1-5 *` are equivalent. Note this is different from [1,2].

#### Hash `#`
`#` is allowed for the Day of week field, and must be followed by a number between one and five or their negative values. It allows you to specify constructs such as "the second Friday" of a given month.

This character is used to specify "the nth weekday day of the month". For example, the value of "6#3" in the Day of month field means the third Friday of the month (day 6 = Friday and "#3" = the 3rd one in the month). Other examples: "2#1" = the first Monday of the month and "4#5" = the fifth Wednesday of the month. Note that if you specify "#5" and there is not 5 of the given Day of week in the month, then no firing will occur that month. If the '#' character is used, there can only be one expression in the dy of week field ("3#1,6#3" is not valid, since there are two expressions).

The nth value can also be negative. For example "#-1 means last, "#-2" means 2nd to last, etc., meaning expressions `* * * * * 6#-1 *` and `* * * * * 6L *` are equivalent.

Predefined cron expressions
---------------------------
(Copied from <https://en.wikipedia.org/wiki/Cron#Predefined_scheduling_definitions>, with text modified according to this implementation)

    Entry       Description                                                             Equivalent to
    @annually   Run once a year at midnight in the morning of January 1                 0 0 0 1 1 * *
    @yearly     Run once a year at midnight in the morning of January 1                 0 0 0 1 1 * *
    @monthly    Run once a month at midnight in the morning of the first of the month   0 0 0 1 * * *
    @weekly     Run once a week at midnight in the morning of Sunday                    0 0 0 * * 0 *
    @daily      Run once a day at midnight                                              0 0 0 * * * *
    @hourly     Run once an hour at the beginning of the hour                           0 0 * * * * *
    @minutely   Run once a minute at the beginning of minute                            0 * * * * * *
    @secondly   Run once every second                                                   * * * * * * *
    @reboot     Not supported

Note that `@minutely` and `@secondly` are not standard.

Other details
-------------
* If only five fields are present, the Year and Second fields are omitted. The omitted Year and Second are `*` and `0` respectively.
* If only six fields are present, the Year field is omitted. The omitted Year is set to `*`. Note that this is different from [1] which has Second field omitted in this case and [2] which doesn't allow five fields.
* Only proper expressions are guaranteed to work.
* Cron doesn't decide calendar, it follows it. It doesn't and it should not disallow combinations like 31st April or 30rd February. Not only that these dates hisctorically happened, but they may very well happen based on timezone configuration. Within reasonable constrains, it should work under changed conditions.

Config
------

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

Quartz extension of day of week and day of month compatibility (2023)
---------------------------
See [quartz](https://www.javadoc.io/doc/org.quartz-scheduler/quartz/latest/org/quartz/CronExpression.html).

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

