# rbear/cmd_status.sh — Display rbear service status

cmd_status() {
    echo ""
    echo -e "${C_WHITE}═══════════════════════════════════════${C_RESET}"
    echo -e "${C_WHITE}            rbear status               ${C_RESET}"
    echo -e "${C_WHITE}═══════════════════════════════════════${C_RESET}"
    echo ""

    # ── Daemon ──
    echo -e "${C_CYAN}  Daemon${C_RESET}"
    local dpid
    dpid="$(read_pid_file "$DAEMON_PID_FILE")"
    if [[ -n "$dpid" ]] && process_alive "$dpid"; then
        echo -e "    Status:    ${C_GREEN}RUNNING${C_RESET}"
        echo -e "    PID:       ${C_WHITE}${dpid}${C_RESET}"
        local uptime
        uptime="$(ps -o etime= -p "$dpid" 2>/dev/null | xargs)" || true
        [[ -n "$uptime" ]] && echo -e "    Uptime:    ${C_WHITE}${uptime}${C_RESET}"
    elif [[ -n "$dpid" ]]; then
        echo -e "    Status:    ${C_RED}NOT RUNNING${C_RESET}"
        echo -e "    Detail:    ${C_YELLOW}stale PID file (${dpid})${C_RESET}"
    else
        echo -e "    Status:    ${C_DIM}NOT RUNNING${C_RESET}"
    fi
    echo ""

    # ── Tunnel ──
    echo -e "${C_CYAN}  Tunnel${C_RESET}"
    local spid
    spid="$(read_pid_file "$TUNNEL_PID_FILE")"
    if [[ -n "$spid" ]] && process_alive "$spid"; then
        echo -e "    Status:    ${C_GREEN}RUNNING${C_RESET}"
        echo -e "    PID:       ${C_WHITE}${spid}${C_RESET}"
    elif [[ -n "$spid" ]]; then
        echo -e "    Status:    ${C_RED}NOT RUNNING${C_RESET}"
        echo -e "    Detail:    ${C_YELLOW}stale PID file (${spid})${C_RESET}"
    else
        echo -e "    Status:    ${C_DIM}NOT RUNNING${C_RESET}"
    fi
    local proc_count
    proc_count="$(pgrep -fc '[s]shuttle' 2>/dev/null || echo "0")"
    if [[ "$proc_count" -gt 0 ]]; then
        local color="$C_GREEN"
        [[ "$proc_count" -gt 3 ]] && color="$C_YELLOW"
        [[ "$proc_count" -gt 6 ]] && color="$C_RED"
        echo -e "    Processes: ${color}${proc_count}${C_RESET}"
    fi
    echo ""

    # ── Kill Switch ──
    echo -e "${C_CYAN}  Kill Switch${C_RESET}"
    local rules
    rules="$(pfctl -a "$ANCHOR_NAME" -s rules 2>/dev/null || echo "")"
    if [[ -n "$rules" ]]; then
        echo -e "    Anchor:    ${C_GREEN}ACTIVE${C_RESET}"
        echo "$rules" | while IFS= read -r rule; do
            echo -e "      ${C_DIM}${rule}${C_RESET}"
        done
    else
        echo -e "    Anchor:    ${C_DIM}INACTIVE${C_RESET}"
    fi
    if pfctl -s info 2>/dev/null | grep -q "^Status: Enabled"; then
        echo -e "    pf:        ${C_GREEN}enabled${C_RESET}"
    else
        echo -e "    pf:        ${C_DIM}disabled${C_RESET}"
    fi
    echo ""

    # ── Network ──
    echo -e "${C_CYAN}  Network${C_RESET}"
    local pub_ip
    pub_ip="$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null || echo "")"
    if [[ -n "$pub_ip" ]]; then
        echo -e "    Public IP: ${C_WHITE}${pub_ip}${C_RESET}"
    else
        echo -e "    Public IP: ${C_RED}unavailable${C_RESET}"
    fi

    if [[ -n "$SSH_IP" ]]; then
        if [[ "$pub_ip" == "$SSH_IP" ]]; then
            echo -e "    Expected:  ${C_GREEN}${SSH_IP} (match)${C_RESET}"
        else
            echo -e "    Expected:  ${C_RED}${SSH_IP} (MISMATCH)${C_RESET}"
        fi
    fi

    local gw iface
    gw="$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')" || true
    iface="$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')" || true
    [[ -n "$gw" ]] && echo -e "    Gateway:   ${C_DIM}${gw}${C_RESET}"
    [[ -n "$iface" ]] && echo -e "    Interface: ${C_DIM}${iface}${C_RESET}"
    echo ""

    # ── DNS ──
    echo -e "${C_CYAN}  DNS${C_RESET}"
    local dns_result=""
    if command -v dig &>/dev/null; then
        dns_result="$(dig +short +time=3 google.com 2>/dev/null | head -1)" || true
    elif command -v nslookup &>/dev/null; then
        nslookup -timeout=3 google.com >/dev/null 2>&1 && dns_result="ok"
    fi
    if [[ -n "$dns_result" ]]; then
        echo -e "    Resolve:   ${C_GREEN}OK${C_RESET} ${C_DIM}(google.com -> ${dns_result})${C_RESET}"
    else
        echo -e "    Resolve:   ${C_RED}FAIL${C_RESET}"
    fi

    local dns_servers
    dns_servers="$(scutil --dns 2>/dev/null | grep 'nameserver\[' | head -3 | awk '{print $3}' | paste -sd ', ' -)" || true
    [[ -n "$dns_servers" ]] && echo -e "    Servers:   ${C_DIM}${dns_servers}${C_RESET}"
    echo ""

    # ── Config ──
    echo -e "${C_CYAN}  Config${C_RESET}"
    echo -e "    Server:    ${C_DIM}${SSH_USER}@${SSH_IP:-(not set)}:${SSH_PORT}${C_RESET}"
    echo -e "    SSH Key:   ${C_DIM}${SSH_KEY:-none}${C_RESET}"
    local max_retries_display
    [[ "${MAX_RETRIES:-0}" == "0" ]] && max_retries_display="unlimited" || max_retries_display="$MAX_RETRIES"
    echo -e "    Reconnect: ${C_DIM}${RECONNECT_DELAY}s delay, max ${max_retries_display} retries${C_RESET}"
    echo -e "    Log:       ${C_DIM}${LOG_FILE}${C_RESET}"
    echo ""
    echo -e "${C_WHITE}═══════════════════════════════════════${C_RESET}"
}
