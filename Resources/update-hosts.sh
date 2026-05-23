#!/bin/bash
# Pomodoro hosts file manager.
# Usage:
#   pomodoro-hosts apply "site1.com,site2.com"
#   pomodoro-hosts clear
#
# Maintains a managed block in /etc/hosts between START/END markers
# so we never touch entries the user added by hand.

set -euo pipefail

HOSTS=/etc/hosts
START_MARKER="# >>> POMODORO BLOCK START >>>"
END_MARKER="# <<< POMODORO BLOCK END <<<"

flush_dns() {
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
}

clear_block() {
    local tmp
    tmp=$(mktemp)
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 == start { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip { print }
    ' "$HOSTS" > "$tmp"
    cat "$tmp" > "$HOSTS"
    rm -f "$tmp"
}

case "${1:-}" in
    apply)
        domains="${2:-}"
        clear_block
        if [ -n "$domains" ]; then
            {
                echo ""
                echo "$START_MARKER"
                IFS=',' read -ra arr <<< "$domains"
                for d in "${arr[@]}"; do
                    [ -z "$d" ] && continue
                    # 0.0.0.0 / :: route nowhere — browsers fail faster than against the loopback addresses.
                    echo "0.0.0.0 $d"
                    echo "0.0.0.0 www.$d"
                    echo ":: $d"
                    echo ":: www.$d"
                done
                echo "$END_MARKER"
            } >> "$HOSTS"
        fi
        flush_dns
        ;;
    clear)
        clear_block
        flush_dns
        ;;
    *)
        echo "Usage: $0 {apply <domains>|clear}" >&2
        exit 1
        ;;
esac
