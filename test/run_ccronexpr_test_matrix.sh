#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${TMPDIR:-/tmp}/ccronexpr_test_matrix.$$"

COMPILERS_ENV="${COMPILERS:-}"
if [ -n "$COMPILERS_ENV" ]; then
    COMPILERS="$COMPILERS_ENV"
    REQUIRE_COMPILERS=1
else
    COMPILERS="cc musl-gcc"
    REQUIRE_COMPILERS=0
fi
TIMEOUT_SECS="${TIMEOUT_SECS:-45}"
CFLAGS_COMMON="${CFLAGS_COMMON:--Wextra -std=c89 -O2 -fPIC}"
MODES="${MODES:-relaxed strict}"
TIMEZONES="${TIMEZONES:-UTC
Europe/London Europe/Prague Europe/Berlin Europe/Moscow Europe/Dublin Europe/Istanbul Europe/Kyiv Europe/Lisbon Europe/Volgograd
America/New_York America/Toronto America/Chicago America/Denver America/Los_Angeles America/Sao_Paulo America/Phoenix America/St_Johns America/Indiana/Indianapolis America/Anchorage America/Halifax
America/Santiago America/Asuncion America/Coyhaique America/Punta_Arenas
Asia/Tokyo Asia/Shanghai Asia/Kolkata Asia/Singapore Asia/Dubai Asia/Jerusalem Asia/Kathmandu Asia/Tehran Asia/Seoul Asia/Dhaka
Australia/Sydney Australia/Adelaide Australia/Lord_Howe
Pacific/Auckland Pacific/Honolulu Pacific/Chatham Pacific/Apia Pacific/Kiritimati
Africa/Johannesburg Africa/Casablanca Africa/Cairo
Antarctica/Troll Antarctica/Palmer
Egypt}"
if [ "${XFAIL_MATRIX+x}" = "x" ]; then
    XFAIL_MATRIX="${XFAIL_MATRIX:-}"
else
    # Keep default empty; caller/CI can provide XFAIL_MATRIX if needed.
    XFAIL_MATRIX=""
fi

compiler_specs=()
seen_compilers=" "
for cc_bin in $COMPILERS; do
    [ -n "$cc_bin" ] || continue
    case "$seen_compilers" in
        *" $cc_bin "*) continue ;;
    esac
    seen_compilers="${seen_compilers}${cc_bin} "
    if ! command -v "$cc_bin" >/dev/null 2>&1; then
        if [ "$REQUIRE_COMPILERS" -eq 1 ]; then
            echo "Compiler not found: $cc_bin" >&2
            exit 2
        fi
        echo "Skipping missing compiler: $cc_bin" >&2
        continue
    fi
    cc_tag="$(printf '%s' "$cc_bin" | tr -c '[:alnum:]_' '_')"
    compiler_specs+=("${cc_tag}|${cc_bin}")
done

if [ "${#compiler_specs[@]}" -eq 0 ]; then
    echo "No usable compilers available in: $COMPILERS" >&2
    exit 2
fi

mode_specs=()
for mode in $MODES; do
    case "$mode" in
        relaxed) mode_specs+=("relaxed|") ;;
        strict) mode_specs+=("strict|-DCRON_STRICT_MATCH") ;;
        *)
            echo "Unknown mode '$mode'. Supported: relaxed strict" >&2
            exit 2
            ;;
    esac
done

if [ "${#mode_specs[@]}" -eq 0 ]; then
    echo "No usable modes in: $MODES" >&2
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

settings=(
    "local|-DCRON_USE_LOCAL_TIME"
    "local_noyears|-DCRON_USE_LOCAL_TIME -DCRON_DISABLE_YEARS"
    "utc|"
    "utc_noyears|-DCRON_DISABLE_YEARS"
)

echo "Compiling ccronexpr_test variants into $WORK_DIR"
for compiler in "${compiler_specs[@]}"; do
    cc_tag="${compiler%%|*}"
    cc_bin="${compiler#*|}"
    for mode_spec in "${mode_specs[@]}"; do
        mode_name="${mode_spec%%|*}"
        mode_defs="${mode_spec#*|}"
        for setting in "${settings[@]}"; do
            name="${setting%%|*}"
            defs="${setting#*|}"
            out_bin="$WORK_DIR/ccronexpr_test_${cc_tag}_${mode_name}_${name}"

            # shellcheck disable=SC2086
            "$cc_bin" $CFLAGS_COMMON $mode_defs $defs \
                "$ROOT_DIR/ccronexpr_test.c" "$ROOT_DIR/ccronexpr.c" \
                -I"$ROOT_DIR" -o "$out_bin"
        done
    done
done

pass_count=0
fail_count=0
timeout_count=0
xfail_count=0
xpass_count=0

echo
printf "%-12s %-10s %-16s %-24s %-10s\n" "compiler" "mode" "setting" "timezone" "result"
printf "%-12s %-10s %-16s %-24s %-10s\n" "--------" "----" "-------" "--------" "------"

for compiler in "${compiler_specs[@]}"; do
    cc_tag="${compiler%%|*}"
    cc_bin="${compiler#*|}"
    cc_base="${cc_bin##*/}"
    for mode_spec in "${mode_specs[@]}"; do
        mode_name="${mode_spec%%|*}"
        for setting in "${settings[@]}"; do
            name="${setting%%|*}"
            bin="$WORK_DIR/ccronexpr_test_${cc_tag}_${mode_name}_${name}"

            for tz in $TIMEZONES; do
                log_file="$WORK_DIR/${cc_tag}_${mode_name}_${name}_${tz//\//_}.log"

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

                is_xfail=0
                for x in $XFAIL_MATRIX; do
                    if [ "$x" = "$name:$tz" ] \
                       || [ "$x" = "$mode_name:$name:$tz" ] \
                       || [ "$x" = "$cc_tag:$name:$tz" ] \
                       || [ "$x" = "$cc_bin:$name:$tz" ] \
                       || [ "$x" = "$cc_base:$name:$tz" ] \
                       || [ "$x" = "$mode_name:$cc_tag:$name:$tz" ] \
                       || [ "$x" = "$mode_name:$cc_bin:$name:$tz" ] \
                       || [ "$x" = "$mode_name:$cc_base:$name:$tz" ]; then
                        is_xfail=1
                        break
                    fi
                done

                if [ "$run_code" -eq 0 ] && [ "$is_xfail" -eq 1 ]; then
                    result="XPASS"
                    xpass_count=$((xpass_count + 1))
                    pass_count=$((pass_count + 1))
                elif [ "$run_code" -eq 0 ]; then
                    result="PASS"
                    pass_count=$((pass_count + 1))
                elif [ "$is_xfail" -eq 1 ]; then
                    result="XFAIL($run_code)"
                    xfail_count=$((xfail_count + 1))
                elif [ "$run_code" -eq 124 ]; then
                    result="TIMEOUT"
                    timeout_count=$((timeout_count + 1))
                else
                    result="FAIL($run_code)"
                    fail_count=$((fail_count + 1))
                fi

                printf "%-12s %-10s %-16s %-24s %-10s\n" "$cc_tag" "$mode_name" "$name" "$tz" "$result"
                if [ "$run_code" -ne 0 ]; then
                    tail -n 6 "$log_file" | sed '/^timeout: the monitored command dumped core$/d; s/^/  /'
                fi
            done
        done
    done
done

echo
echo "Summary: pass=$pass_count fail=$fail_count timeout=$timeout_count xfail=$xfail_count xpass=$xpass_count"

if [ "$fail_count" -ne 0 ] || [ "$timeout_count" -ne 0 ]; then
    exit 1
fi
