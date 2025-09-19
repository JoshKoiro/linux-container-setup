#!/bin/bash

# --- Configuration ---
# All detailed output will be appended to this file.
LOG_FILE="setup.log"

# --- Logging Functions ---
log() {
  gum log --time rfc822 --structured --level info -- "$@"
}
debug() {
  gum log --time rfc822 --structured --level debug -- "$@"
}
warn() {
  gum log --time rfc822 --structured --level warn -- "$@"
}
error() {
  gum log --time rfc822 --structured --level error -- "$@"
}
fatal() {
  gum log --time rfc822 --structured --level fatal -- "$@"
  exit 1
}

# --- Main Spinner Function ---
# This version runs the entire `gum spin` command inside of `script`
# to create a pseudo-terminal (pty), which allows the spinner animation
# to work correctly while its output is being piped to `tee`.
# Usage: load "Title for the spinner..." command and its arguments
load() {
    local title="$1"
    shift # Remove the title from the argument list
    local cmd_str
    # Safely quote the command and its arguments into a single string
    printf -v cmd_str '%q ' "$@"

    # Announce the start of the command.
    echo -e "\n--- Starting: $title ---" | tee -a "$LOG_FILE"

    # We wrap the *entire gum spin command* inside `script`.
    # `script` creates a pty, making gum believe it's in an interactive session,
    # thus enabling the spinner. The output of this pty is then piped to tee.
    script -q /dev/null -c "gum spin --show-output --spinner points --title \"$title\" -- $cmd_str" | tee -a "$LOG_FILE"
}

# --- Script Logic ---

# Clear the log file for a fresh run.
> "$LOG_FILE"

log "Starting environment setup..."
debug "The log file for this session is located at: $LOG_FILE"

# Call the load function with a custom title for each step.
load "Installing eza..." brew install eza
load "Updating Homebrew formulas..." brew update

# Download and Install Neovim
load "Installing neovim..." brew install neovim

# Download and Install fzf
load "Installing fzf..." brew install fzf

# Download and Install Lazygit (for Lazyvim)
load "Installing lazygit..." brew install lazygit

# Download and Install ripgrep for lazyvim
load "Installing ripgrep..." brew install ripgrep

# Configure base Lazyvim configuration
# backup base config
load "Backing up lazyvim configuration..." mv ~/.config/nvim{,.bak}

# clone the repo for Lazyvim
load "Cloning repo for lazyvim..." git clone https://github.com/LazyVim/starter ~/.config/nvim

# remove the .git folder
load "Removing .git folder for lazyvim template...." rm -rf ~/.config/nvim/.git

# Custom configurations

    # Download customizations

    # fzf

    # eza

    # nvim

    # btop

    # pandoc

    # fzf

    # tmux



