# rbear/cmd_check.sh — IP leak testing and continuous monitoring

IP_CHECK_HOSTS=(
    "https://ifconfig.me"
    "https://api.ipify.org"
    "https://ipecho.net/plain"
    "https://checkip.amazonaws.com"
    "https://ident.me"
    "https://www.cloudflare.com/cdn-cgi/trace"
)

extract_ip() {
    local host="$1" raw="$2"
    [[ "$host" == *"cloudflare"* ]] && raw="$(echo "$raw" | grep '^ip=' | cut -d= -f2)"
    echo "$raw" | tr -d '[:space:]'
}

short_host() {
    local h="${1#https://}"
    h="${h#http://}"
    echo "${h%%/*}"
}

check_host() {
    local host="$1" expected="$2" timeout="${3:-5}"
    local ts raw ip

    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    local exit_code=0
    raw="$(curl -sSf --max-time "$timeout" "$host" 2>&1)" || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        local err
        err="$(echo "$raw" | tail -1)"
        : "${err:=connection failed}"
        printf "${C_YELLOW}%s CURL ERROR | %s | %s${C_RESET}\n" "$ts" "$(short_host "$host")" "$err"
        return 1
    fi

    ip="$(extract_ip "$host" "$raw")"

    if [[ "$ip" == "$expected" ]]; then
        printf "${C_GREEN}%s OK       | %s | ip=%s${C_RESET}\n" "$ts" "$(short_host "$host")" "$ip"
        return 0
    else
        printf "${C_RED}%s MISMATCH | %s | expected=%s | got=%s${C_RESET}\n" "$ts" "$(short_host "$host")" "$expected" "$ip"
        return 2
    fi
}

cmd_check() {
    require_server

    local host_count=${#IP_CHECK_HOSTS[@]}
    local ts

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "${C_CYAN}%s Expected IP: ${C_WHITE}%s${C_RESET}\n" "$ts" "$SSH_IP"
    printf "${C_CYAN}%s Running full scan...${C_RESET}\n\n" "$ts"

    local ok=0 fail=0 errors=0

    for host in "${IP_CHECK_HOSTS[@]}"; do
        check_host "$host" "$SSH_IP" 5
        case $? in
            0) ok=$((ok + 1)) ;;
            1) errors=$((errors + 1)) ;;
            2) fail=$((fail + 1)) ;;
        esac
    done

    echo ""
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ $fail -gt 0 ]]; then
        printf "${C_RED}%s RESULT — %d/%d mismatch, %d errors${C_RESET}\n\n" "$ts" "$fail" "$host_count" "$errors"
    elif [[ $errors -eq $host_count ]]; then
        printf "${C_RED}%s RESULT — all %d checks failed${C_RESET}\n\n" "$ts" "$host_count"
    else
        printf "${C_GREEN}%s ALL CLEAR — %d/%d confirmed IP %s${C_RESET}\n\n" "$ts" "$ok" "$host_count" "$SSH_IP"
    fi

    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "${C_CYAN}%s Continuous monitoring | Ctrl+C to stop${C_RESET}\n\n" "$ts"
    trap 'printf "\n%s Stopped.\n" "$(date "+%Y-%m-%d %H:%M:%S")"; exit 0' INT TERM

    while true; do
        check_host "${IP_CHECK_HOSTS[$(( RANDOM % host_count ))]}" "$SSH_IP" 1 || true
        sleep 1
    done
}
