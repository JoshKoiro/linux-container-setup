#!/bin/bash
#================================================================================
# LXC Container Provisioning Script (Debian-based, Proxmox)
#================================================================================

# --- SCRIPT CONFIGURATION ---

# -- Timezone Configuration --
SET_TIMEZONE="America/New_York" # e.g., "UTC", "Europe/London"

# -- Package Group Toggles --
INSTALL_CORE_PACKAGES=true
INSTALL_NETWORK_PACKAGES=false
INSTALL_DEV_PACKAGES=false
INSTALL_MONITORING_PACKAGES=true

# -- Package Definitions --

CORE_PACKAGES=(
  "curl"
  "wget"
  "vim"
  "tree"
  "unzip"
  "zip"
  "git"
  "stow"
  "ca-certificates"
  "gnupg"
  "lsb-release"
  "tmux"
  "jp2a"
)

DEV_PACKAGES=(
  "build-essential"
  "python3"
  "python3-pip"
)

NETWORK_PACKAGES=(
  "net-tools"
  "iputils-ping"
  "dnsutils"
  "traceroute"
  "netcat-openbsd"
)

MONITORING_PACKAGES=(
  "iotop"
  "iftop"
  "btop"
  "ncdu"
  "screen"
)

CUSTOM_PACKAGES=(
  "cowsay"
)

# --- END OF CONFIGURATION ---
#================================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_USER=""
PKG_FRONTEND="apt" # will switch to nala if available

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_package() { echo -e "${PURPLE}[PACKAGE]${NC} $1"; }

check_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

prompt_input() {
  local prompt="$1" var_name="$2" validation_regex="$3" error_msg="$4"
  local input=""
  while true; do
    read -r -p "$prompt" input || true
    # allow empty input to pass when caller wants "keep current"
    if [[ -z "$input" ]] || [[ "$input" =~ $validation_regex ]]; then
      printf -v "$var_name" '%s' "$input"
      break
    else
      log_error "$error_msg"
    fi
  done
}

set_hostname_safe_files() {
  # Ensure /etc/hostname reflects the desired hostname
  local hn="$1"
  printf '%s\n' "$hn" >/etc/hostname

  # Update /etc/hosts 127.0.1.1 mapping appropriately (Debian convention)
  # Preserve other lines; replace existing 127.0.1.1 mapping if present, else append.
  if grep -qE '^[[:space:]]*127\.0\.1\.1[[:space:]]' /etc/hosts; then
    sed -i -E "s|^[[:space:]]*127\.0\.1\.1[[:space:]].*|127.0.1.1\t${hn}|" /etc/hosts
  else
    echo -e "127.0.1.1\t${hn}" >>/etc/hosts
  fi
}

set_hostname() {
  log_info "Setting hostname..."
  local current_hostname
  current_hostname=$(hostname)
  log_info "Current hostname: $current_hostname"
  local new_hostname=""
  prompt_input "Enter new hostname (or press Enter to keep '$current_hostname'): " new_hostname "^[a-zA-Z0-9-]+$" "Invalid hostname. Use only letters, numbers, and hyphens."

  if [[ -z "$new_hostname" ]]; then
    new_hostname="$current_hostname"
    log_info "Keeping current hostname: $new_hostname"
  fi

  # Prefer hostnamectl when available; fallback for minimal/systemd-absent environments inside some LXC templates
  if command -v hostnamectl >/dev/null 2>&1; then
    if hostnamectl set-hostname "$new_hostname"; then
      set_hostname_safe_files "$new_hostname"
      log_success "Hostname set to: $new_hostname"
      return
    else
      log_warning "hostnamectl failed in this container, falling back to file edits"
    fi
  fi

  echo "$new_hostname" >/etc/hostname
  set_hostname_safe_files "$new_hostname"
  hostname "$new_hostname" || true
  log_success "Hostname set to: $new_hostname"
}

create_user() {
  log_info "Creating non-root user..."
  local username=""
  prompt_input "Enter username for new user (or existing): " username "^[a-z_][a-z0-9_-]*$" "Invalid username. Use lowercase letters, numbers, underscores, and hyphens only."
  SCRIPT_USER="$username"

  if id "$username" >/dev/null 2>&1; then
    log_warning "User '$username' already exists"
    read -r -p "Continue using existing user? (y/N): " confirm || true
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log_info "Skipping user creation steps."
    else
      log_info "Continuing with existing user '$username'."
    fi
  else
    useradd -m -s /bin/bash "$username"
    log_success "User '$username' created"
    log_info "Setting password for user '$username'"
    passwd "$username"
  fi

  # Ensure sudo is installed and grant via sudo group and drop-in file (safer than editing /etc/sudoers)
  if ! dpkg -s sudo >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
  fi
  usermod -aG sudo "$username"
  # Ensure the group policy exists via sudoers.d
  if [[ ! -e /etc/sudoers.d/00-sudo-group ]]; then
    echo "%sudo ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-sudo-group
    chmod 0440 /etc/sudoers.d/00-sudo-group
  fi
  log_success "User '$username' granted sudo via group 'sudo'"
}

update_system() {
  log_info "Updating package lists..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  log_success "Package lists updated"

  log_info "Upgrading packages..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  log_success "Packages upgraded"

  log_info "Removing unnecessary packages..."
  DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
  log_success "Unnecessary packages removed"
}

install_nala() {
  log_info "Installing nala package manager..."
  if command -v nala >/dev/null 2>&1; then
    log_warning "Nala is already installed"
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -y nala || {
      log_warning "Failed to install nala; apt will remain the frontend"
      return
    }
    log_success "Nala package manager installed"
  fi

  if command -v nala >/dev/null 2>&1; then
    PKG_FRONTEND="nala"
    read -r -p "test mirrors for nala package manager? (y/N): " mirror_confirm || true
    if [[ ! "$mirror_confirm" =~ ^[Yy]$ ]]; then
      log_info "Skipping mirror test"
    else
      log_info "Configuring nala with fastest mirrors..."
      nala fetch --auto -y || log_warning "Could not automatically configure nala mirrors"
      log_success "Nala configuration step completed"

    fi

    log_info "Running Nala update"
    nala update
  fi
}

ensure_lists_fresh() {
  local lists_dir="/var/lib/apt/lists"
  if [[ ! -d "$lists_dir" ]] || [[ -z "$(ls -A "$lists_dir" 2>/dev/null)" ]]; then
    log_info "Apt lists missing; updating..."
    if [[ "$PKG_FRONTEND" == "nala" ]]; then
      DEBIAN_FRONTEND=noninteractive nala update -y || DEBIAN_FRONTEND=noninteractive apt-get update -y
    else
      DEBIAN_FRONTEND=noninteractive apt-get update -y
    fi
    return
  fi

  local last_update
  last_update=$(stat -c %Y "$lists_dir" 2>/dev/null || echo 0)
  local now
  now=$(date +%s)
  if ((now - last_update > 3600)); then
    log_info "Package lists are older than 1h; refreshing with $PKG_FRONTEND..."
    if [[ "$PKG_FRONTEND" == "nala" ]]; then
      DEBIAN_FRONTEND=noninteractive nala update -y || DEBIAN_FRONTEND=noninteractive apt-get update -y
    else
      DEBIAN_FRONTEND=noninteractive apt-get update -y
    fi
  fi
}

install_packages() {
  local packages=("$@")
  if [[ ${#packages[@]} -eq 0 ]]; then
    log_warning "No packages specified for installation"
    return
  fi
  log_package "Attempting to install: ${packages[*]}"

  ensure_lists_fresh

  if [[ "$PKG_FRONTEND" == "nala" ]] && command -v nala >/dev/null 2>&1; then
    if DEBIAN_FRONTEND=noninteractive nala install -y "${packages[@]}"; then
      log_success "Successfully installed: ${packages[*]}"
    else
      log_error "Failed to install some packages with nala: ${packages[*]}"
      return 1
    fi
  else
    log_warning "Using apt as frontend"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
      log_success "Successfully installed: ${packages[*]}"
    else
      log_error "Failed to install some packages with apt: ${packages[*]}"
      return 1
    fi
  fi
}

install_additional_packages() {
  log_info "Installing additional packages based on configuration..."

  if [[ "${INSTALL_CORE_PACKAGES}" == true ]] && [[ ${#CORE_PACKAGES[@]} -gt 0 ]]; then
    install_packages "${CORE_PACKAGES[@]}"
  fi
  if [[ "${INSTALL_DEV_PACKAGES}" == true ]] && [[ ${#DEV_PACKAGES[@]} -gt 0 ]]; then
    install_packages "${DEV_PACKAGES[@]}"
  fi
  if [[ "${INSTALL_NETWORK_PACKAGES}" == true ]] && [[ ${#NETWORK_PACKAGES[@]} -gt 0 ]]; then
    install_packages "${NETWORK_PACKAGES[@]}"
  fi
  if [[ "${INSTALL_MONITORING_PACKAGES}" == true ]] && [[ ${#MONITORING_PACKAGES[@]} -gt 0 ]]; then
    install_packages "${MONITORING_PACKAGES[@]}"
  fi
  if [[ ${#CUSTOM_PACKAGES[@]} -gt 0 ]]; then
    install_packages "${CUSTOM_PACKAGES[@]}"
  fi

  log_success "Additional packages installation completed"
}

post_install_config() {
  log_info "Performing post-installation configuration..."

  if [[ -n "$SET_TIMEZONE" ]]; then
    if command -v timedatectl >/dev/null 2>&1; then
      if timedatectl set-timezone "$SET_TIMEZONE"; then
        log_success "Timezone set to $SET_TIMEZONE"
      else
        log_error "Failed to set timezone with timedatectl. Verify '$SET_TIMEZONE'."
      fi
    else
      # Minimal fallback for non-systemd containers: symlink /etc/localtime
      if [[ -f "/usr/share/zoneinfo/$SET_TIMEZONE" ]]; then
        ln -sf "/usr/share/zoneinfo/$SET_TIMEZONE" /etc/localtime
        echo "$SET_TIMEZONE" >/etc/timezone
        log_success "Timezone set to $SET_TIMEZONE (fallback method)"
      else
        log_error "Timezone '$SET_TIMEZONE' not found under /usr/share/zoneinfo"
      fi
    fi
  fi

  if command -v git >/dev/null 2>&1 && [[ -n "$SCRIPT_USER" ]]; then
    log_info "Git detected. To configure for '$SCRIPT_USER':"
    log_info "  su - $SCRIPT_USER -c \"git config --global user.name 'Your Name'\""
    log_info "  su - $SCRIPT_USER -c \"git config --global user.email 'your.email@example.com'\""
  fi

  if [[ -n "$SCRIPT_USER" ]] && id "$SCRIPT_USER" >/dev/null 2>&1; then
    install -d -o "$SCRIPT_USER" -g "$SCRIPT_USER" "/home/$SCRIPT_USER/scripts"
    install -d -o "$SCRIPT_USER" -g "$SCRIPT_USER" "/home/$SCRIPT_USER/projects"
    log_success "Created standard directories for user '$SCRIPT_USER'"
  fi

  log_success "Post-installation configuration completed"
}

main() {
  log_info "Starting LXC container provisioning..."
  echo "================================================"
  echo "      LXC Container Provisioning Script"
  echo "================================================"

  check_root

  log_info "Performing initial package list update..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y || true

  set_hostname
  create_user
  update_system
  install_nala
  install_additional_packages
  post_install_config

  local total_packages=0
  [[ "$INSTALL_CORE_PACKAGES" == true ]] && total_packages=$((total_packages + ${#CORE_PACKAGES[@]}))
  [[ "$INSTALL_DEV_PACKAGES" == true ]] && total_packages=$((total_packages + ${#DEV_PACKAGES[@]}))
  [[ "$INSTALL_NETWORK_PACKAGES" == true ]] && total_packages=$((total_packages + ${#NETWORK_PACKAGES[@]}))
  [[ "$INSTALL_MONITORING_PACKAGES" == true ]] && total_packages=$((total_packages + ${#MONITORING_PACKAGES[@]}))
  total_packages=$((total_packages + ${#CUSTOM_PACKAGES[@]}))

  # Get local IP address
  local local_ip
  local_ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

  echo "================================================"
  log_success "Container provisioning completed successfully!"
  echo "================================================"
  echo
  log_info "Summary:"
  echo -e "  • Hostname:\t\t$(hostname)"
  echo -e "  • IP Address:\t\t${local_ip}"
  echo -e "  • New user:\t\t${SCRIPT_USER:-<none>}"
  echo -e "  • Package frontend:\t${PKG_FRONTEND}"
  echo -e "  • System:\t\tfully updated"
  echo -e "  • Packages selected:\t${total_packages}"
  echo -e "  • Login via ssh using:\tssh ${SCRIPT_USER:-<new-username>}@${local_ip}"
  echo
  log_info "Next steps:"
  echo "  • Reboot the container to ensure all changes take effect: sudo reboot"
  if [[ -n "${SCRIPT_USER:-}" ]]; then
    echo "  • Switch to new user: su - $SCRIPT_USER"
  fi
  echo
}

if [[ "${BASH_SOURCE:-}" == "${0}" ]] || [[ -z "${BASH_SOURCE:-}" ]]; then
  main "$@"
fi
