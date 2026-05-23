#!/bin/bash
# One-time setup: installs the hosts helper to /usr/local/bin and
# adds a sudoers rule so Pomodoro can call it without a password prompt.
#
# Run once:  bash ~/pomodoro/setup-sudoers.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running with sudo (you'll be prompted once)..."
    exec sudo --preserve-env=USER "$0" "$@"
fi

USER_NAME="${SUDO_USER:-$USER}"
HELPER_PATH="/usr/local/bin/pomodoro-hosts"
SOURCE_SCRIPT="$(cd "$(dirname "$0")" && pwd)/Resources/update-hosts.sh"

if [ ! -f "$SOURCE_SCRIPT" ]; then
    echo "Error: cannot find $SOURCE_SCRIPT" >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 755 "$SOURCE_SCRIPT" "$HELPER_PATH"

SUDOERS_FILE="/etc/sudoers.d/pomodoro"
TMP_SUDOERS="$(mktemp)"
echo "$USER_NAME ALL=(root) NOPASSWD: $HELPER_PATH" > "$TMP_SUDOERS"

if ! visudo -c -f "$TMP_SUDOERS" >/dev/null; then
    echo "Error: sudoers entry failed validation — aborted." >&2
    rm -f "$TMP_SUDOERS"
    exit 1
fi

install -m 440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"

echo "Installed:"
echo "  helper:  $HELPER_PATH"
echo "  rule:    $SUDOERS_FILE"
echo "Pomodoro can now manage /etc/hosts without prompting."
