#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.ssh/config"
SSH_DIR="$HOME/.ssh"

usage() {
    echo "Usage: $0 [setup|cleanup]"
    exit 1
}

[[ $# -eq 1 ]] || usage

MODE="$1"

if [[ "$MODE" == "setup" ]]; then
    echo "=== SSH Key Setup Wizard ==="
    read -rp "Enter a short nickname for this host (e.g. 'docker'): " HOST_ALIAS
    read -rp "Enter the remote hostname or IP (e.g. 'docker.gnomehub.home'): " HOST_NAME
    read -rp "Enter the remote username (e.g. 'josh'): " HOST_USER
    read -rp "Enter filename for key (will be stored in ~/.ssh/, e.g. 'id_ed25519_docker'): " KEY_NAME
    read -rp "Optional comment for key (e.g. 'docker-access'): " KEY_COMMENT

    KEY_PATH="$SSH_DIR/$KEY_NAME"

    # Step 1: generate key
    if [[ -f "$KEY_PATH" ]]; then
        echo "Key $KEY_PATH already exists, skipping generation."
    else
        echo "Generating ed25519 keypair..."
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$KEY_COMMENT"
    fi

    # Step 2: copy pubkey to remote
    echo "Copying public key to $HOST_USER@$HOST_NAME ..."
    ssh-copy-id -i "${KEY_PATH}.pub" "$HOST_USER@$HOST_NAME"

    # Step 3: update ~/.ssh/config
    if ! grep -q "Host $HOST_ALIAS" "$CONFIG_FILE" 2>/dev/null; then
        echo "Updating $CONFIG_FILE ..."
        {
            echo ""
            echo "Host $HOST_ALIAS"
            echo "    HostName $HOST_NAME"
            echo "    User $HOST_USER"
            echo "    IdentityFile $KEY_PATH"
        } >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo "Config entry added."
    else
        echo "Config already has an entry for $HOST_ALIAS, skipping."
    fi

    echo "=== Setup complete. Try: ssh $HOST_ALIAS ==="

elif [[ "$MODE" == "cleanup" ]]; then
    echo "=== SSH Key Cleanup ==="
    read -rp "Enter the host alias to remove: " HOST_ALIAS

    # Remove config entry
    if grep -q "Host $HOST_ALIAS" "$CONFIG_FILE"; then
        echo "Removing config entry for $HOST_ALIAS..."
        # use awk to delete block from "Host alias" until next "Host"
        awk -v alias="$HOST_ALIAS" '
        BEGIN {del=0}
        /^Host / {
            if ($2==alias) {del=1; next}
            else if (del==1) {del=0}
        }
        del==0 {print}
        ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        echo "No config entry for $HOST_ALIAS."
    fi

    # Remove key files
    KEY_FILE=$(grep -A2 "Host $HOST_ALIAS" "$CONFIG_FILE" 2>/dev/null | grep IdentityFile | awk '{print $2}' || true)
    if [[ -n "$KEY_FILE" && -f "$KEY_FILE" ]]; then
        echo "Deleting key files $KEY_FILE and ${KEY_FILE}.pub..."
        rm -f "$KEY_FILE" "${KEY_FILE}.pub"
    fi

    echo "Note: you’ll need to manually remove the public key from ~/.ssh/authorized_keys on the remote host."
    echo "=== Cleanup complete ==="

else
    usage
fi
