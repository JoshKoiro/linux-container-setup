#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-$HOME/.ssh/config}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "=== Batch SSH Key Setup ==="
echo "Using config: $CONFIG_FILE"
echo ""

# Parse config into blocks
awk '
    /^Host / {host=$2; next}
    /HostName/ {print host " HOSTNAME " $2}
    /User/ {print host " USER " $2}
    /IdentityFile/ {print host " KEY " $2}
' "$CONFIG_FILE" | while read -r alias field value; do
    case "$field" in
        HOSTNAME) eval "hname_$alias=$value" ;;
        USER) eval "user_$alias=$value" ;;
        KEY) eval "key_$alias=$value" ;;
    esac
done

# Iterate through host aliases
grep "^Host " "$CONFIG_FILE" | awk '{print $2}' | while read -r alias; do
    HOST_NAME=$(eval echo "\$hname_$alias")
    HOST_USER=$(eval echo "\$user_$alias")
    KEY_PATH=$(eval echo "\$key_$alias")

    echo "--- Setting up host: $alias ($HOST_USER@$HOST_NAME) ---"

    if [[ -z "$HOST_NAME" || -z "$HOST_USER" || -z "$KEY_PATH" ]]; then
        echo "Missing info for $alias, skipping."
        continue
    fi

    # Generate key if missing
    if [[ ! -f "$KEY_PATH" ]]; then
        echo "Generating key at $KEY_PATH ..."
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$alias-key"
    fi

    # Copy pubkey to remote
    echo "Copying public key to $HOST_USER@$HOST_NAME ..."
    ssh-copy-id -i "${KEY_PATH}.pub" "$HOST_USER@$HOST_NAME" || echo "Failed to copy key for $alias."

    echo "Done with $alias."
    echo ""
done

echo "=== Batch setup complete ==="
