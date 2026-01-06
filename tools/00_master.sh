#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

show_help() {
  cat <<'EOF'
Simple Stream - Master Automation Entry Point

This repo is a timeboxed demo. Deployment is blocked after the expiration date enforced by deploy_all.sql.

Usage:
  ./tools/00_master.sh deploy
  ./tools/00_master.sh test [--all|--step N]
  ./tools/00_master.sh cleanup
  ./tools/00_master.sh help

Commands:
  deploy   Print Snowsight "Run All" deployment instructions (deploy_all.sql)
  test     Run the local setup + simulator helper (tools/02_setup_and_test.sh)
  cleanup  Print cleanup instructions (sql/99_cleanup/cleanup.sql)
  help     Show this message
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    show_help
    ;;
  deploy)
    cat <<EOF
Deployment (Snowsight):
1. Open Snowsight and create a new SQL worksheet.
2. Copy the full contents of:
   $PROJECT_ROOT/deploy_all.sql
3. Paste into the worksheet and click "Run All".

Note: deploy_all.sql enforces demo expiration and will block deployment if expired.
EOF
    ;;
  test)
    exec "$SCRIPT_DIR/02_setup_and_test.sh" "$@"
    ;;
  cleanup)
    cat <<'EOF'
Cleanup (Snowsight):
Run this script in a Snowsight worksheet:
  @sql/99_cleanup/cleanup.sql
EOF
    ;;
  *)
    echo "ERROR: Unknown command: $cmd" >&2
    echo "" >&2
    show_help >&2
    exit 2
    ;;
esac
