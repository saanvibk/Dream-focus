#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_command="${FLUTTER_COMMAND:-flutter}"

cd "$project_root"
exec "$flutter_command" run \
  --debug \
  -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 8080 \
  "$@"
