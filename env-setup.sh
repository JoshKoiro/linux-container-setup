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
    # echo -e "\n--- Starting: $title ---" | tee -a "$LOG_FILE"

    # We wrap the *entire gum spin command* inside `script`.
    # `script` creates a pty, making gum believe it's in an interactive session,
    # thus enabling the spinner. The output of this pty is then piped to tee.
    script -q /dev/null -c "gum spin --spinner points --title \"$title\" -- $cmd_str" | tee -a "$LOG_FILE"
}

# --- Download Function ---
# Downloads a file from a URL to a specified destination
# Usage: download "https://example.com/file.txt" "/path/to/destination/file.txt"
# or:    download "https://example.com/file.txt" "/path/to/destination/directory/"
download() {
    if [ $# -ne 2 ]; then
        error "download function requires exactly 2 arguments: URL and destination"
        error "Usage: download \"https://example.com/file.txt\" \"/path/to/destination\""
        return 1
    fi
    
    local url="$1"
    local destination="$2"
    local download_tool="curl"
    local filename=""
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        error "Invalid URL format: $url"
        return 1
    fi
    
    # Check which download tool is available
    if command -v curl >/dev/null 2>&1; then
        download_tool="curl"
        debug "Using curl for download"
    elif command -v wget >/dev/null 2>&1; then
        download_tool="wget"
        debug "Using wget for download"
    else
        error "Neither curl nor wget is available for downloading"
        return 1
    fi
    
    # Determine if destination is a directory or file
    if [[ "$destination" == */ ]]; then
        # Destination is a directory
        local dest_dir="$destination"
        filename=$(basename "$url")
        local full_path="${dest_dir}${filename}"
    else
        # Destination is a file path
        local dest_dir=$(dirname "$destination")
        filename=$(basename "$destination")
        local full_path="$destination"
    fi
    
    # Create destination directory if it doesn't exist
    if [[ ! -d "$dest_dir" ]]; then
        debug "Creating directory: $dest_dir"
        mkdir -p "$dest_dir" || {
            error "Failed to create directory: $dest_dir"
            return 1
        }
    fi
    
    # Check if file already exists
    if [[ -f "$full_path" ]]; then
        warn "File already exists: $full_path"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Download cancelled by user"
            return 0
        fi
    fi
    
    # Perform the download using the load function for consistency
    local download_title="Downloading $(basename "$url") to $dest_dir"
    
    case "$download_tool" in
        "curl")
            load "$download_title" curl -fsSL -o "$full_path" "$url"
            ;;
        "wget")
            load "$download_title" wget -q -O "$full_path" "$url"
            ;;
    esac
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log "Successfully downloaded: $full_path"
        return 0
    else
        error "Download failed with exit code: $exit_code"
        # Clean up partial download
        [[ -f "$full_path" ]] && rm "$full_path"
        return $exit_code
    fi
}

# --- Enhanced Download Function for Config Files ---
# Downloads config files from a git repository with smart path handling
# Usage: download_config "https://raw.githubusercontent.com/user/repo/main/config/nvim/init.lua" "~/.config/nvim/"
download_config() {
    if [ $# -ne 2 ]; then
        error "download_config function requires exactly 2 arguments: URL and config destination"
        error "Usage: download_config \"https://raw.githubusercontent.com/JoshKoiro/linux-container-setup/main/config/file\" \"~/.config/destination/\""
        return 1
    fi
    
    local url="$1"
    local config_dest="$2"
    
    # Expand tilde in destination path
    config_dest="${config_dest/#\~/$HOME}"
    
    # Ensure destination ends with a slash for directory
    [[ "$config_dest" != */ ]] && config_dest="$config_dest/"
    
    download "$url" "$config_dest"
}

updateBashrc() { 
# Example usage:
# updateBashrc "export PATH=\$PATH:/usr/local/bin"
# updateBashrc "alias ll='ls -la'"
    
    # Check if a parameter was provided
    if [ $# -eq 0 ]; then
        error "no parameter provided for updateBashrc"
        return 1
    fi
    
    local text_to_add="$1"
    local bashrc_file="$HOME/.bashrc"
    
    # Create .bashrc if it doesn't exist
    if [ ! -f "$bashrc_file" ]; then
        touch "$bashrc_file"
        log "Created new .bashrc file"
    fi
    
    # Check if the text already exists in .bashrc
    if grep -Fxq "$text_to_add" "$bashrc_file"; then
        warn "Text already exists in .bashrc - no changes made"
        return 0
    else
        # Append the text to .bashrc
        echo "$text_to_add" >> "$bashrc_file"
        if [ $? -eq 0 ]; then
            log "Successfully added to .bashrc: $text_to_add"
        else
            error "Error: Failed to write to .bashrc"
            return 1
        fi
    fi
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

# Custom configurations - Example downloads
# You can now use the download function like this:
repo_url="https://raw.githubusercontent.com/JoshKoiro/linux-container-setup/main/"

# Example: Download a custom nvim config file
# download_config "https://raw.githubusercontent.com/yourusername/dotfiles/main/nvim/init.lua" "~/.config/nvim/"

# Example: Download fzf configuration
# download_config "https://raw.githubusercontent.com/yourusername/dotfiles/main/fzf/fzf.bash" "~/.config/fzf/"

# Example: Download eza configuration
# download "https://raw.githubusercontent.com/yourusername/dotfiles/main/eza/config" "$HOME/.config/eza/config"

# Example: Download btop configuration
# download_config "https://raw.githubusercontent.com/yourusername/dotfiles/main/btop/btop.conf" "~/.config/btop/"

# Example: Download tmux configuration
download ${repo_url}/configs/.tmux.conf "$HOME/.tmux.conf"