#!/usr/bin/env bash

set -euo pipefail

echo "=== SSH Key Setup Wizard ==="

# Step 1: gather user input
read -rp "Enter a short nickname for this host: " HOST_ALIAS
read -rp "Enter the remote hostname or IP: " HOST_NAME
read -rp "Enter the remote username: " HOST_USER
read -rp "Enter filename for key (will be stored in ~/.ssh/): " KEY_NAME
read -rp "Optional comment for key: " KEY_COMMENT

KEY_PATH="$HOME/.ssh/$KEY_NAME"

# Step 2: generate keypair
if [[ -f "$KEY_PATH" ]]; then
    echo "Key $KEY_PATH already exists, skipping generation."
else
    echo "Generating ed25519 keypair..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$KEY_COMMENT"
fi

# Step 3: copy pubkey to remote
echo "Copying public key to $HOST_USER@$HOST_NAME ..."
ssh-copy-id -i "${KEY_PATH}.pub" "$HOST_USER@$HOST_NAME"

# Step 4: update ~/.ssh/config
CONFIG_FILE="$HOME/.ssh/config"
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

echo "=== Done! ==="
echo "Try connecting with: ssh $HOST_ALIAS"