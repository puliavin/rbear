#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBEAR_LIB="${SCRIPT_DIR}/rbear"

source "${RBEAR_LIB}/config.sh"
source "${RBEAR_LIB}/helpers.sh"
source "${RBEAR_LIB}/killswitch.sh"
source "${RBEAR_LIB}/tunnel.sh"
source "${RBEAR_LIB}/daemon.sh"
source "${RBEAR_LIB}/cmd_status.sh"
source "${RBEAR_LIB}/cmd_check.sh"

main() {
    local cmd="${1:-}"

    case "$cmd" in
        configure) cmd_configure ;;
        start)     require_config; cmd_start  ;;
        stop)      load_config;    cmd_stop   ;;
        status)    require_config; cmd_status ;;
        check)     require_config; cmd_check  ;;
        *)
            echo "Usage: $0 {configure|start|stop|status|check}"
            echo ""
            echo "Commands:"
            echo "  configure  Create rbear.conf configuration file"
            echo "  start      Start rbear daemon (requires root)"
            echo "  stop       Stop rbear daemon (requires root)"
            echo "  status     Show rbear status"
            echo "  check      Test IP across multiple services"
            exit 1
            ;;
    esac
}

main "$@"
