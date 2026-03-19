#!/bin/sh
# stop: when the agent run completes successfully, run fix/analyze/test and
# request a follow-up if something fails. Cursor only applies stdout JSON when
# the hook exits 0; followup_message is used for status "completed" only.

set -eu

payload=$(cat) || payload='{}'
ROOT="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"
cd "$ROOT" 2>/dev/null || {
  printf '%s\n' '{}'
  exit 0
}

status=$(printf '%s' "$payload" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('status', '') or '')
except Exception:
    print('')
" 2>/dev/null) || status=''

# Avoid running the full suite on abort/error; those are not "done" states for verification.
if [ "$status" != "completed" ]; then
  printf '%s\n' '{}'
  exit 0
fi

dart fix --apply . >/dev/null 2>&1 || true

if ! dart analyze; then
  printf '%s\n' '{"followup_message": "Verification failed: fix dart analyze issues (see analyzer output above if visible) and try again."}'
  exit 0
fi

if ! dart test; then
  printf '%s\n' '{"followup_message": "Verification failed: fix dart test failures and try again."}'
  exit 0
fi

printf '%s\n' '{}'
exit 0
