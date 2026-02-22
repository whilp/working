#!/bin/bash
# run-ah.sh: wrapper around ah that logs timing diagnostics.
#
# usage: run-ah.sh <timeout_seconds> <ah_binary> [ah_args...]
#
# logs timestamps to stderr so they appear in CI output even when
# ah itself produces no output (e.g. API timeout).

set -euo pipefail

timeout_secs=$1; shift
ah_bin=$1; shift

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

echo "  [run-ah] $(ts) starting (timeout=${timeout_secs}s, model=${AH_MODEL:-unknown})" >&2

start=$(date +%s)
rc=0
timeout "$timeout_secs" "$ah_bin" "$@" || rc=$?
end=$(date +%s)
elapsed=$((end - start))

if [ "$rc" -eq 124 ]; then
    echo "  [run-ah] $(ts) timed out after ${elapsed}s (limit=${timeout_secs}s)" >&2
elif [ "$rc" -ne 0 ]; then
    echo "  [run-ah] $(ts) exited ${rc} after ${elapsed}s" >&2
else
    echo "  [run-ah] $(ts) done in ${elapsed}s" >&2
fi

exit "$rc"
