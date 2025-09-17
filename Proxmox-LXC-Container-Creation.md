# Proxmox LXC Container Creation Script

This shell script automates the creation of LXC containers in Proxmox using the Proxmox VE API. It uses YAML configuration files for container specifications and environment variables for API authentication.

## Features

- ✅ Create LXC containers via Proxmox API using token authentication
- ✅ Full configuration through YAML files (version-control friendly)
- ✅ Secure credential management via .env files
- ✅ Auto-generation of container IDs
- ✅ Comprehensive container configuration options
- ✅ Automatic dependency installation
- ✅ YAML validation before execution
- ✅ Debug mode for detailed progress tracking
- ✅ Support for multiple Proxmox nodes
- ✅ Compatible with Proxmox VE 8.x

## Prerequisites

- Proxmox VE server (tested with 8.4.13)
- API token created in Proxmox
- Linux system with internet access (for dependency installation)
- Bash shell

## Quick Start

### 1. Setup API Token in Proxmox

1. Log into your Proxmox web interface
2. Navigate to **Datacenter > Permissions > API Tokens**
3. Click **Add** to create a new token
4. Fill in:
   - **User**: `root@pam` (or your preferred user)
   - **Token ID**: Choose a name (e.g., `lxc-creation`)
   - **Privilege Separation**: Uncheck (for full permissions)
5. Click **Add** and **save the generated secret** (you won't see it again)

### 2. Download and Setup Script

```bash
# Make the script executable
chmod +x create-lxc-container.sh

# Copy the environment template
cp .env.example .env

# Edit the .env file with your Proxmox details
nano .env
```

### 3. Configure Your Container

```bash
# Copy the example configuration
cp container-config.yaml my-container.yaml

# Edit the configuration to match your needs
nano my-container.yaml
```

### 4. Create the Container

```bash
# Basic usage
./create-lxc-container.sh my-container.yaml

# With debug output
./create-lxc-container.sh --debug my-container.yaml
```

## Configuration

### Environment Variables (.env)

Create a `.env` file with your Proxmox credentials:

```bash
PROXMOX_HOST=your-proxmox-host.example.com
PROXMOX_USER=root
PROXMOX_TOKEN_NAME=lxc-creation
PROXMOX_TOKEN_SECRET=your-secret-here
DEFAULT_ROOT_PASSWORD=secure-password-123

# SSH Keys (optional) - can reference these in YAML files
ADMIN_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7... admin@workstation"
DEV_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... developer@laptop"

# Multiple SSH keys (newline separated)
TEAM_SSH_KEYS="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7... admin@workstation
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... developer@laptop
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD9... ops@server"
```

**Security Note**: Keep your `.env` file secure and never commit it to version control!

### YAML Configuration

The YAML configuration file defines all aspects of your container. Here's a minimal example:

```yaml
container:
  node: "pve"
  template: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  hostname: "webserver"
  resources:
    memory: 1024
  network:
    - name: "eth0"
      bridge: "vmbr0"
      ip: "dhcp"
```

### Available Configuration Options

| Section | Field | Description | Required | Default |
|---------|-------|-------------|----------|---------|
| `container.node` | - | Target Proxmox node | ✅ | - |
| `container.template` | - | OS template path | ✅ | - |
| `container.hostname` | - | Container hostname | ❌ | - |
| `container.password` | - | Root password | ❌ | - |
| `container.ssh_keys` | - | SSH public keys | ❌ | - |
| `resources.memory` | - | Memory in MB | ✅ | - |
| `resources.swap` | - | Swap in MB | ❌ | 512 |
| `resources.cores` | - | CPU cores | ❌ | 1 |
| `resources.cpulimit` | - | CPU limit (percentage) | ❌ | - |
| `resources.cpuunits` | - | CPU priority weight | ❌ | 1024 |
| `storage.storage` | - | Storage backend | ❌ | local-lvm |
| `storage.size` | - | Root disk size (GB) | ❌ | 8 |
| `network` | - | Network interfaces array | ❌ | DHCP on vmbr0 |
| `mountpoints` | - | Additional storage array | ❌ | - |
| `options.unprivileged` | - | Unprivileged container | ❌ | true |
| `options.onboot` | - | Start on boot | ❌ | false |
| `options.start` | - | Start after creation | ❌ | false |
| `options.protection` | - | Deletion protection | ❌ | false |
| `dns.nameserver` | - | DNS servers | ❌ | - |
| `dns.searchdomain` | - | DNS search domain | ❌ | - |
| `container.tags` | - | Container tags | ❌ | - |
| `container.description` | - | Container description | ❌ | - |

## Usage Examples

### Basic Web Server

```yaml
container:
  node: "pve"
  template: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  hostname: "webserver"
  password: "${DEFAULT_ROOT_PASSWORD}"
  resources:
    memory: 2048
    cores: 2
  storage:
    size: "20"
  network:
    - name: "eth0"
      bridge: "vmbr0"
      ip: "192.168.1.100/24"
      gateway: "192.168.1.1"
  options:
    onboot: true
    start: true
  tags: "web,production"
```

### Development Container

```yaml
container:
  node: "pve"
  template: "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  hostname: "dev-environment"
  ssh_keys: |
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... developer@laptop
  resources:
    memory: 4096
    cores: 4
  mountpoints:
    - storage: "local-lvm"
      size: "50"
      path: "/home/projects"
  network:
    - name: "eth0"
      bridge: "vmbr0"
      ip: "dhcp"
  tags: "development,debian"
```

### Using SSH Keys from Environment Variables

You can reference SSH keys stored in your `.env` file to keep them out of your YAML configurations:

**In your .env file:**
```bash
ADMIN_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7... admin@workstation"
TEAM_SSH_KEYS="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7... admin@workstation
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... developer@laptop
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD9... ops@server"
```

**In your YAML configuration:**
```yaml
container:
  node: "pve"
  template: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  hostname: "secure-server"
  # Reference a single SSH key from .env
  ssh_keys: "${ADMIN_SSH_KEY}"
  # Or reference multiple keys
  # ssh_keys: "${TEAM_SSH_KEYS}"
  resources:
    memory: 2048
  network:
    - name: "eth0"
      bridge: "vmbr0"
      ip: "dhcp"
  options:
    start: true
  tags: "production,secure"
```

This approach keeps sensitive SSH keys out of your version-controlled YAML files while maintaining flexibility.

### Multiple Network Interfaces

```yaml
container:
  node: "pve"
  template: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  hostname: "router"
  resources:
    memory: 1024
  network:
    - name: "eth0"
      bridge: "vmbr0"
      ip: "192.168.1.10/24"
      gateway: "192.168.1.1"
    - name: "eth1"
      bridge: "vmbr1"
      ip: "10.0.1.1/24"
      firewall: false
```

## Command Line Options

```bash
./create-lxc-container.sh [OPTIONS] <config.yaml>

OPTIONS:
    --debug     Enable debug mode for detailed progress tracking
    --help      Show help message

EXAMPLES:
    ./create-lxc-container.sh mycontainer.yaml
    ./create-lxc-container.sh --debug production-web.yaml
```

## Troubleshooting

### Common Issues

1. **"Authentication failed"**
   - Verify your API token credentials in `.env`
   - Ensure the token has sufficient permissions
   - Check that the Proxmox hostname/IP is correct

2. **"Template not found"**
   - Verify the template exists on the specified node
   - Check the template path in your YAML configuration
   - Ensure templates are downloaded: `pveam update && pveam available`

3. **"Storage not found"**
   - Verify storage backend exists on the target node
   - Check storage name in Proxmox UI under Node > Disks

4. **"Network bridge not found"**
   - Verify bridge exists on the target node
   - Check bridge configuration in Proxmox UI

### Debug Mode

Use `--debug` flag for detailed troubleshooting information:

```bash
./create-lxc-container.sh --debug my-container.yaml
```

This will show:
- Dependency checking details
- YAML validation steps  
- API parameter construction
- HTTP requests/responses
- Task monitoring progress

### Container Templates

To list available templates:

```bash
# Update template list
pveam update

# List available templates
pveam available

# Download a template
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

## Security Considerations

- Store API credentials securely in `.env` files
- Use unprivileged containers when possible
- Implement proper firewall rules
- Regular updates of container templates
- Consider using SSH keys instead of passwords
- Review container privileges and capabilities

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.