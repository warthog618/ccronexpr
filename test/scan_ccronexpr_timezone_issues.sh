#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${TMPDIR:-/tmp}/ccronexpr_tz_scan.$$"

CC_BIN="${CC:-cc}"
TIMEOUT_SECS="${TIMEOUT_SECS:-20}"
CFLAGS_COMMON="${CFLAGS_COMMON:--Wextra -std=c89 -O2 -fPIC -DCRON_STRICT_MATCH}"

TIMEZONES="${TIMEZONES:-$(find /usr/share/zoneinfo -type f \
    | sed 's#^/usr/share/zoneinfo/##' \
    | rg -v '^(posix/|right/)|^(localtime|posixrules|leap-seconds.list|tzdata.zi|zone.tab|zone1970.tab|iso3166.tab|zonenow.tab|leapseconds)$' \
    | sort)}"
SETTINGS="${SETTINGS:-local local_noyears}"

if ! command -v "$CC_BIN" >/dev/null 2>&1; then
    echo "Compiler not found: $CC_BIN" >&2
    exit 2
fi

HAVE_TIMEOUT=1
TIMEOUT_QUIET_FLAG=""
if ! command -v timeout >/dev/null 2>&1; then
    HAVE_TIMEOUT=0
elif timeout --help 2>&1 | grep -q -- "--quiet"; then
    TIMEOUT_QUIET_FLAG="--quiet"
fi

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR"

compile_variant() {
    local setting="$1"
    local defs="$2"
    local out_bin="$WORK_DIR/ccronexpr_test_${setting}"

    # shellcheck disable=SC2086
    "$CC_BIN" $CFLAGS_COMMON $defs \
        "$ROOT_DIR/ccronexpr_test.c" "$ROOT_DIR/ccronexpr.c" \
        -I"$ROOT_DIR" -o "$out_bin"
}

for setting in $SETTINGS; do
    case "$setting" in
        local) compile_variant "$setting" "-DCRON_USE_LOCAL_TIME" ;;
        local_noyears) compile_variant "$setting" "-DCRON_USE_LOCAL_TIME -DCRON_DISABLE_YEARS" ;;
        utc) compile_variant "$setting" "" ;;
        utc_noyears) compile_variant "$setting" "-DCRON_DISABLE_YEARS" ;;
        *)
            echo "Unknown setting '$setting'. Supported: local local_noyears utc utc_noyears" >&2
            exit 2
            ;;
    esac
done

fail_count=0
total_count=0

echo "Scanning ccronexpr_test across timezone database"
printf "%-14s %-30s %-10s %-6s %s\n" "setting" "timezone" "result" "line" "pattern"
printf "%-14s %-30s %-10s %-6s %s\n" "-------" "--------" "------" "----" "-------"

for setting in $SETTINGS; do
    bin="$WORK_DIR/ccronexpr_test_${setting}"

    for tz in $TIMEZONES; do
        total_count=$((total_count + 1))
        log_file="$WORK_DIR/${setting}_${tz//\//_}.log"

        if [ "$HAVE_TIMEOUT" -eq 1 ]; then
            set +e
            { timeout $TIMEOUT_QUIET_FLAG "${TIMEOUT_SECS}s" env TZ="$tz" "$bin" >"$log_file" 2>&1; } 2>/dev/null
            run_code=$?
            set -e
        else
            set +e
            { env TZ="$tz" "$bin" >"$log_file" 2>&1; } 2>/dev/null
            run_code=$?
            set -e
        fi

        # Keep the original result code; stdbuf retry is diagnostics only.
        if [ "$run_code" -ne 0 ] && command -v stdbuf >/dev/null 2>&1; then
            rerun_log="$log_file.rerun"
            set +e
            if [ "$HAVE_TIMEOUT" -eq 1 ]; then
                { timeout $TIMEOUT_QUIET_FLAG "${TIMEOUT_SECS}s" env TZ="$tz" stdbuf -o0 "$bin" >"$rerun_log" 2>&1; } 2>/dev/null
            else
                { env TZ="$tz" stdbuf -o0 "$bin" >"$rerun_log" 2>&1; } 2>/dev/null
            fi
            set -e
            if [ -s "$rerun_log" ] && ! grep -Eq "libstdbuf\\.so: .*symbol not found" "$rerun_log"; then
                mv "$rerun_log" "$log_file"
            else
                rm -f "$rerun_log"
            fi
        fi

        if [ "$run_code" -eq 0 ]; then
            continue
        fi

        fail_count=$((fail_count + 1))
        line="$({ rg '^Line:' "$log_file" || true; } | tail -n 1 | sed 's/^Line: //')"
        pattern="$({ rg '^Pattern:' "$log_file" || true; } | tail -n 1 | sed 's/^Pattern: //')"
        [ -n "$line" ] || line="?"
        [ -n "$pattern" ] || pattern="?"
        printf "%-14s %-30s FAIL(%-4s) %-6s %s\n" "$setting" "$tz" "$run_code" "$line" "$pattern"

        expected="$({ rg '^Expected:' "$log_file" || true; } | tail -n 1 | sed 's/^Expected: //')"
        actual="$({ rg '^Actual:' "$log_file" || true; } | tail -n 1 | sed 's/^Actual: //')"
        if [ -n "$expected" ] || [ -n "$actual" ]; then
            [ -n "$expected" ] && echo "  expected: $expected"
            [ -n "$actual" ] && echo "  actual:   $actual"
        fi
    done
done

echo
echo "Summary: total=$total_count failures=$fail_count"
if [ "$fail_count" -ne 0 ]; then
    exit 1
fi
