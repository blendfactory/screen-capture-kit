#!/bin/sh
# afterFileEdit: when a Dart file was edited, run dart fix then dart format on that path only.
# Cursor passes JSON on stdin; stdout must be JSON. Exit 0 so the hook result is applied.

set -eu

payload=$(cat) || payload='{}'
ROOT="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"
cd "$ROOT" 2>/dev/null || {
  printf '%s\n' '{}'
  exit 0
}

file_path=$(printf '%s' "$payload" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    path = data.get('file_path') or ''
    if not path.endswith('.dart'):
        sys.exit(1)
    print(path, end='')
except Exception:
    sys.exit(1)
" 2>/dev/null) || {
  printf '%s\n' '{}'
  exit 0
}

dart fix --apply "$file_path" >/dev/null 2>&1 || true
dart format "$file_path" >/dev/null 2>&1 || true

printf '%s\n' '{}'
exit 0
