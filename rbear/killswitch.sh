# rbear/killswitch.sh — macOS pf firewall kill switch

save_pf_state() {
    if pfctl -s info 2>/dev/null | grep -q "^Status: Enabled"; then
        touch "$PF_WAS_ENABLED"
    else
        rm -f "$PF_WAS_ENABLED"
    fi
}

build_combined_pf() {
    local content last_rdr=0 last_anchor=0 lineno=0
    content="$(< /etc/pf.conf)"

    while IFS= read -r line; do
        lineno=$((lineno + 1))
        case "$line" in
            rdr-anchor*) last_rdr=$lineno ;;
            anchor*)
                [[ "$line" == "load anchor"* ]] || last_anchor=$lineno
                ;;
        esac
    done <<< "$content"

    lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        echo "$line"
        [[ $lineno -eq $last_rdr ]] && echo 'rdr-anchor "sshuttle*"'
        if [[ $lineno -eq $last_anchor ]]; then
            echo 'anchor "sshuttle*"'
            echo "anchor \"${ANCHOR_NAME}\""
        fi
    done <<< "$content"
}

release_pf_token() {
    [[ -f "$PF_TOKEN_FILE" ]] || return 0
    local token
    token="$(cat "$PF_TOKEN_FILE" 2>/dev/null || echo "")"
    if [[ -n "$token" ]]; then
        pfctl -X "$token" 2>/dev/null || true
        log "Released pf token $token"
    fi
    rm -f "$PF_TOKEN_FILE"
}

enable_killswitch() {
    log "Enabling kill switch"
    release_pf_token

    build_combined_pf > "$PF_CONF"

    local output
    if ! output="$(pfctl -f "$PF_CONF" 2>&1)"; then
        log "ERROR: pfctl -f failed: $output"
        return 1
    fi

    local anchor_rules
    anchor_rules="$(cat <<RULES
pass quick on lo0 all
pass out quick proto tcp from any to ${SSH_IP} port ${SSH_PORT}
pass in  quick proto tcp from ${SSH_IP} port ${SSH_PORT} to any
pass out quick proto icmp from any to ${SSH_IP}
pass in  quick proto icmp from ${SSH_IP} to any
pass out quick proto udp from any port 68 to 255.255.255.255 port 67
pass in  quick proto udp from any port 67 to any port 68
block drop all
RULES
)"

    if ! output="$(echo "$anchor_rules" | pfctl -a "$ANCHOR_NAME" -f - 2>&1)"; then
        log "ERROR: anchor load failed: $output"
        pfctl -a "$ANCHOR_NAME" -F all 2>/dev/null || true
        pfctl -f /etc/pf.conf 2>/dev/null || true
        return 1
    fi

    local token
    token="$(pfctl -E 2>&1 | grep -o 'Token : [0-9]*' | awk '{print $3}')" || true
    if [[ -n "$token" ]]; then
        echo "$token" > "$PF_TOKEN_FILE"
        log "pf enabled (token $token)"
    else
        pfctl -e 2>/dev/null || true
        log "pf enabled (no token)"
    fi
    log "Kill switch active"
}

disable_killswitch() {
    log "Disabling kill switch"
    release_pf_token
    pfctl -a "$ANCHOR_NAME" -F all 2>/dev/null || true
    pfctl -f /etc/pf.conf 2>/dev/null || true

    if [[ -f "$PF_WAS_ENABLED" ]]; then
        log "pf was enabled — leaving enabled"
    else
        pfctl -d 2>/dev/null || true
        log "pf disabled"
    fi
}
