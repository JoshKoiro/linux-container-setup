#!/bin/bash

# Proxmox LXC Container Creation Script
# Usage: ./create-lxc-container.sh [--debug] <config.yaml>

set -euo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DEBUG=false
CONFIG_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <config.yaml>

Creates an LXC container in Proxmox using API based on YAML configuration.

OPTIONS:
    --debug     Enable debug mode for detailed progress tracking
    --help      Show this help message

ARGUMENTS:
    config.yaml Path to the YAML configuration file

EXAMPLE:
    $0 mycontainer.yaml
    $0 --debug production-web.yaml

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG=true
                log_debug "Debug mode enabled"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$CONFIG_FILE" ]]; then
                    CONFIG_FILE="$1"
                else
                    log_error "Multiple config files specified"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "Configuration file is required"
        usage
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Check and install dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("curl" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check for yq specifically (has different installation methods)
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "Missing dependencies: ${missing_deps[*]}"
        
        # Detect package manager and install
        if command -v apt-get &> /dev/null; then
            log_info "Installing dependencies using apt..."
            for dep in "${missing_deps[@]}"; do
                if [[ "$dep" == "yq" ]]; then
                    # Install yq from GitHub releases
                    log_info "Installing yq..."
                    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                    sudo chmod +x /usr/local/bin/yq
                else
                    sudo apt-get update -qq && sudo apt-get install -y "$dep"
                fi
            done
        elif command -v yum &> /dev/null; then
            log_info "Installing dependencies using yum..."
            for dep in "${missing_deps[@]}"; do
                if [[ "$dep" == "yq" ]]; then
                    log_info "Installing yq..."
                    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                    sudo chmod +x /usr/local/bin/yq
                else
                    sudo yum install -y "$dep"
                fi
            done
        else
            log_error "Could not detect package manager. Please install: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    log_debug "All dependencies satisfied"
}

# Load environment variables
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    log_debug "Loading environment variables from $ENV_FILE"
    
    # Source the .env file
    set -a
    source "$ENV_FILE"
    set +a
    
    # Validate required environment variables
    local required_vars=("PROXMOX_HOST" "PROXMOX_USER" "PROXMOX_TOKEN_NAME" "PROXMOX_TOKEN_SECRET")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: $var"
            exit 1
        fi
    done
    
    log_debug "Environment variables loaded successfully"
}

# Validate YAML structure
validate_yaml() {
    log_info "Validating YAML configuration..."
    
    # Check if file is valid YAML
    if ! yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax in $CONFIG_FILE"
        exit 1
    fi
    
    # Check required fields
    local required_fields=("container.node" "container.template" "container.resources.memory")
    
    for field in "${required_fields[@]}"; do
        if ! yq eval ".$field" "$CONFIG_FILE" > /dev/null 2>&1 || [[ "$(yq eval ".$field" "$CONFIG_FILE")" == "null" ]]; then
            log_error "Required field missing: $field"
            exit 1
        fi
    done
    
    log_debug "YAML validation passed"
}

# Get next available container ID
get_next_vmid() {
    local node="$1"
    log_debug "Getting next available container ID for node: $node"
    
    local response
    response=$(curl -s -k \
        -H "Authorization: PVEAPIToken=${PROXMOX_USER}@pam!${PROXMOX_TOKEN_NAME}=${PROXMOX_TOKEN_SECRET}" \
        "https://${PROXMOX_HOST}:8006/api2/json/cluster/nextid")
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to connect to Proxmox API"
        exit 1
    fi
    
    local vmid
    vmid=$(echo "$response" | jq -r '.data')
    
    if [[ "$vmid" == "null" ]] || [[ -z "$vmid" ]]; then
        log_error "Failed to get next available container ID"
        exit 1
    fi
    
    log_debug "Next available container ID: $vmid"
    echo "$vmid"
}

# Build API parameters from YAML
build_api_params() {
    local config_file="$1"
    local vmid="$2"
    
    log_debug "Building API parameters from YAML configuration"
    
    # Start building the API parameters
    local params="vmid=${vmid}"
    
    # Basic container settings
    local template
    template=$(yq eval '.container.template' "$config_file")
    params="${params}&ostemplate=${template}"
    
    # Hostname
    local hostname
    hostname=$(yq eval '.container.hostname // ""' "$config_file")
    if [[ -n "$hostname" && "$hostname" != "null" ]]; then
        params="${params}&hostname=${hostname}"
    fi
    
    # Root password (from env if specified)
    local password
    password=$(yq eval '.container.password // ""' "$config_file")
    if [[ -n "$password" && "$password" != "null" ]]; then
        # Check if it's an environment variable reference
        if [[ "$password" =~ ^\$\{(.+)\}$ ]]; then
            local env_var="${BASH_REMATCH[1]}"
            password="${!env_var:-}"
        fi
        if [[ -n "$password" ]]; then
            params="${params}&password=${password}"
        fi
    fi
    
    # SSH public key
    local ssh_keys
    ssh_keys=$(yq eval '.container.ssh_keys // ""' "$config_file")
    if [[ -n "$ssh_keys" && "$ssh_keys" != "null" ]]; then
        # URL encode the SSH keys
        ssh_keys=$(printf '%s' "$ssh_keys" | curl -s -o /dev/null -w '%{url_effective}' --get --data-urlencode "ssh-public-keys=$ssh_keys" "")
        ssh_keys="${ssh_keys##*=}"
        params="${params}&ssh-public-keys=${ssh_keys}"
    fi
    
    # Resources
    local memory
    memory=$(yq eval '.container.resources.memory' "$config_file")
    params="${params}&memory=${memory}"
    
    local swap
    swap=$(yq eval '.container.resources.swap // 512' "$config_file")
    params="${params}&swap=${swap}"
    
    local cores
    cores=$(yq eval '.container.resources.cores // 1' "$config_file")
    params="${params}&cores=${cores}"
    
    local cpulimit
    cpulimit=$(yq eval '.container.resources.cpulimit // ""' "$config_file")
    if [[ -n "$cpulimit" && "$cpulimit" != "null" ]]; then
        params="${params}&cpulimit=${cpulimit}"
    fi
    
    local cpuunits
    cpuunits=$(yq eval '.container.resources.cpuunits // ""' "$config_file")
    if [[ -n "$cpuunits" && "$cpuunits" != "null" ]]; then
        params="${params}&cpuunits=${cpuunits}"
    fi
    
    # Storage
    local rootfs
    local storage
    storage=$(yq eval '.container.storage.storage // "local-lvm"' "$config_file")
    local size
    size=$(yq eval '.container.storage.size // "8"' "$config_file")
    rootfs="${storage}:${size}"
    params="${params}&rootfs=${rootfs}"
    
    # Network configuration
    local net_count=0
    while true; do
        local net_config
        net_config=$(yq eval ".container.network[$net_count] // null" "$config_file")
        if [[ "$net_config" == "null" ]]; then
            break
        fi
        
        local net_string="name="
        net_string+=$(yq eval ".container.network[$net_count].name" "$config_file")
        
        local bridge
        bridge=$(yq eval ".container.network[$net_count].bridge // \"vmbr0\"" "$config_file")
        net_string+=",bridge=${bridge}"
        
        local ip
        ip=$(yq eval ".container.network[$net_count].ip // \"dhcp\"" "$config_file")
        if [[ "$ip" != "dhcp" ]]; then
            net_string+=",ip=${ip}"
            
            local gw
            gw=$(yq eval ".container.network[$net_count].gateway // \"\"" "$config_file")
            if [[ -n "$gw" && "$gw" != "null" ]]; then
                net_string+=",gw=${gw}"
            fi
        fi
        
        local firewall
        firewall=$(yq eval ".container.network[$net_count].firewall // \"\"" "$config_file")
        if [[ -n "$firewall" && "$firewall" != "null" ]]; then
            net_string+=",firewall=${firewall}"
        fi
        
        params="${params}&net${net_count}=${net_string}"
        ((net_count++))
    done
    
    # If no network was specified, add default
    if [[ $net_count -eq 0 ]]; then
        params="${params}&net0=name=eth0,bridge=vmbr0,ip=dhcp"
    fi
    
    # Additional mount points
    local mp_count=0
    while true; do
        local mp_config
        mp_config=$(yq eval ".container.mountpoints[$mp_count] // null" "$config_file")
        if [[ "$mp_config" == "null" ]]; then
            break
        fi
        
        local mp_storage
        mp_storage=$(yq eval ".container.mountpoints[$mp_count].storage" "$config_file")
        local mp_size
        mp_size=$(yq eval ".container.mountpoints[$mp_count].size" "$config_file")
        local mp_path
        mp_path=$(yq eval ".container.mountpoints[$mp_count].path" "$config_file")
        
        local mp_string="${mp_storage}:${mp_size},mp=${mp_path}"
        
        local backup
        backup=$(yq eval ".container.mountpoints[$mp_count].backup // \"\"" "$config_file")
        if [[ -n "$backup" && "$backup" != "null" ]]; then
            mp_string+=",backup=${backup}"
        fi
        
        params="${params}&mp${mp_count}=${mp_string}"
        ((mp_count++))
    done
    
    # Container options
    local unprivileged
    unprivileged=$(yq eval '.container.options.unprivileged // true' "$config_file")
    params="${params}&unprivileged=${unprivileged}"
    
    local onboot
    onboot=$(yq eval '.container.options.onboot // false' "$config_file")
    params="${params}&onboot=${onboot}"
    
    local start
    start=$(yq eval '.container.options.start // false' "$config_file")
    params="${params}&start=${start}"
    
    # Protection
    local protection
    protection=$(yq eval '.container.options.protection // false' "$config_file")
    params="${params}&protection=${protection}"
    
    # DNS settings
    local nameserver
    nameserver=$(yq eval '.container.dns.nameserver // ""' "$config_file")
    if [[ -n "$nameserver" && "$nameserver" != "null" ]]; then
        params="${params}&nameserver=${nameserver}"
    fi
    
    local searchdomain
    searchdomain=$(yq eval '.container.dns.searchdomain // ""' "$config_file")
    if [[ -n "$searchdomain" && "$searchdomain" != "null" ]]; then
        params="${params}&searchdomain=${searchdomain}"
    fi
    
    # Tags
    local tags
    tags=$(yq eval '.container.tags // ""' "$config_file")
    if [[ -n "$tags" && "$tags" != "null" ]]; then
        params="${params}&tags=${tags}"
    fi
    
    # Description
    local description
    description=$(yq eval '.container.description // ""' "$config_file")
    if [[ -n "$description" && "$description" != "null" ]]; then
        # URL encode the description
        description=$(printf '%s' "$description" | curl -s -o /dev/null -w '%{url_effective}' --get --data-urlencode "description=$description" "")
        description="${description##*=}"
        params="${params}&description=${description}"
    fi
    
    log_debug "API parameters built: $params"
    echo "$params"
}

# Create the container
create_container() {
    local node="$1"
    local params="$2"
    
    log_info "Creating container on node: $node"
    log_debug "API parameters: $params"
    
    local response
    response=$(curl -s -k -w "\n%{http_code}" \
        -H "Authorization: PVEAPIToken=${PROXMOX_USER}@pam!${PROXMOX_TOKEN_NAME}=${PROXMOX_TOKEN_SECRET}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "$params" \
        "https://${PROXMOX_HOST}:8006/api2/json/nodes/${node}/lxc")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | head -n -1)
    
    log_debug "HTTP response code: $http_code"
    log_debug "Response body: $response_body"
    
    if [[ "$http_code" -ne 200 ]]; then
        log_error "Failed to create container. HTTP code: $http_code"
        log_error "Response: $response_body"
        exit 1
    fi
    
    # Parse the task ID for monitoring
    local task_id
    task_id=$(echo "$response_body" | jq -r '.data // empty')
    
    if [[ -n "$task_id" && "$task_id" != "null" ]]; then
        log_info "Container creation task started: $task_id"
        monitor_task "$node" "$task_id"
    else
        log_info "Container created successfully"
    fi
}

# Monitor task progress
monitor_task() {
    local node="$1"
    local task_id="$2"
    
    log_info "Monitoring task progress..."
    
    while true; do
        local status_response
        status_response=$(curl -s -k \
            -H "Authorization: PVEAPIToken=${PROXMOX_USER}@pam!${PROXMOX_TOKEN_NAME}=${PROXMOX_TOKEN_SECRET}" \
            "https://${PROXMOX_HOST}:8006/api2/json/nodes/${node}/tasks/${task_id}/status")
        
        local task_status
        task_status=$(echo "$status_response" | jq -r '.data.status // "unknown"')
        
        local task_exitstatus
        task_exitstatus=$(echo "$status_response" | jq -r '.data.exitstatus // "null"')
        
        log_debug "Task status: $task_status, Exit status: $task_exitstatus"
        
        case "$task_status" in
            "stopped")
                if [[ "$task_exitstatus" == "OK" ]]; then
                    log_info "Container created successfully!"
                    return 0
                else
                    log_error "Container creation failed with status: $task_exitstatus"
                    return 1
                fi
                ;;
            "running")
                if [[ "$DEBUG" == "true" ]]; then
                    echo -n "."
                fi
                sleep 2
                ;;
            *)
                log_warn "Unknown task status: $task_status"
                sleep 2
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    
    log_info "Starting LXC container creation process"
    log_debug "Configuration file: $CONFIG_FILE"
    
    check_dependencies
    load_env
    validate_yaml
    
    # Get node from YAML
    local node
    node=$(yq eval '.container.node' "$CONFIG_FILE")
    
    # Get next available container ID
    local vmid
    vmid=$(get_next_vmid "$node")
    
    log_info "Using container ID: $vmid"
    
    # Build API parameters
    local params
    params=$(build_api_params "$CONFIG_FILE" "$vmid")
    
    # Create the container
    create_container "$node" "$params"
    
    log_info "LXC container creation process completed"
    log_info "Container ID: $vmid"
    log_info "Node: $node"
}

# Run main function with all arguments
main "$@"