# 🐧 REM - Arch chroot for Containers

![License: MIT](https://img.shields.://opensource.org/licenses/MITio/badge/Arch%20Linux-1793D1?logo/badge/Container-Ready-green)

A complete Arch Linux chroot environment that runs inside Ubuntu-based containers, perfect for RunPod GPU instances. Get the power of Arch Linux's rolling releases and AUR packages while maintaining compatibility with containerized workflows.

## 🚀 Quick Start

```bash
# In your RunPod container's /workspace directory:
git clone https://github.com/yourusername/arch-chroot-runpod.git
cd rem
find . -type f -iname "*.sh" -exec chmod +x {}
./start.sh
```

## Tips
add this code in the end of you container startup script (start from root)

```bash 
find /path/to/rem -type f -iname "*.sh" -exec chmod +x {}
/path/to/rem/.start.sh
```
That's it! The setup automatically:
- ✅ Downloads and installs Arch Linux bootstrap
- ✅ Configures container-safe environment
- ✅ Creates user with sudo access
- ✅ Sets up SSL certificates and networking
- ✅ Generates secure credentials
- ✅ Creates persistent storage

## ✨ Features

### 🔧 **Complete Arch Linux Environment**
- Full Arch Linux userspace with `pacman` package manager
- Access to official repositories and AUR packages
- Rolling release updates and cutting-edge software
- Persistent across container restarts

### 🐳 **Container Optimized**
- Works without privileged access or special permissions
- Handles `/dev/null`, `/dev/zero`, and device node limitations
- Container-safe mount operations with graceful fallbacks
- SSL certificate integration from Ubuntu host

### 👤 **User Management**
- Auto-generated secure passwords (or configurable)
- Passwordless sudo access for development
- Support for multiple shells (bash, zsh, fish)
- Proper user environment and home directory setup

### 🎮 **GPU Ready**
- Compatible with NVIDIA drivers and CUDA
- GPU passthrough support for AI/ML workloads
- Easy installation of GPU-accelerated packages

### 🛠️ **Developer Friendly**
- Git integration with proper SSL configuration
- Development tools and build environments
- Shell customization (Oh-My-Zsh, Starship, etc.)
- Package installation helpers and shortcuts

## 📁 Directory Structure

After setup, your workspace will look like:

```
/workspace/
├── arch-chroot-runpod/        # This repository  
│   ├── start.sh               # Main setup script
│   ├── scripts/               # Modular setup components
│   │   ├── 01-install-deps.sh
│   │   ├── 02-generate-config.sh
│   │   ├── 03-setup-bootstrap.sh
│   │   ├── 04-setup-mounts.sh
│   │   ├── 05-run-fixes.sh
│   │   ├── 06-setup-users.sh
│   │   └── 07-create-helpers.sh
│   └── fixes/                 # Container compatibility fixes
│       ├── fix-ssl-certs.sh
│       ├── fix-essential-devices.sh
│       ├── fix-mtab.sh
│       ├── fix-network.sh
│       └── fix-pacman.sh
├── arch-root/                 # Arch Linux chroot (persistent)
├── arch-config.txt           # Generated credentials & config
├── enter-arch.sh             # Enter as root
├── enter-arch-user.sh        # Enter as user
├── show-credentials.sh       # Display login info
└── tools/                    # Management utilities
    ├── install-packages.sh
    ├── quick-setup.sh
    ├── dev-setup.sh
    └── dashboard.sh
```

## 🎯 Usage Examples

### Daily Development Workflow

```bash
# Enter your Arch environment as user
./enter-arch-user.sh

# Install development tools
sudo pacman -S git vim python nodejs npm docker

# Install from AUR (using yay)
./tools/install-packages.sh yay base-devel
yay -S visual-studio-code-bin

# Set up development environment
./tools/dev-setup.sh
```

### Package Management

```bash
# Install individual packages
./tools/install-packages.sh git python nodejs

# Install development essentials
./tools/quick-setup.sh

# Update system
./enter-arch.sh
pacman -Syu
```

### GPU/AI Development

```bash
# Install NVIDIA userspace libraries
./enter-arch.sh
pacman -S nvidia-utils cuda

# Install PyTorch with CUDA
pacman -S python-pytorch-cuda

# Test GPU access
nvidia-smi
```

## 🔑 Credentials & Security

Credentials are auto-generated and saved to `/workspace/arch-config.txt`:

```bash
# View current credentials
./show-credentials.sh

# Change passwords
nano /workspace/arch-config.txt
./tools/change-passwords.sh
```

**Default Setup:**
- **Root password:** Auto-generated (12 characters)
- **User:** `developer` with auto-generated password
- **Sudo:** Passwordless sudo enabled for convenience
- **Shell:** Bash by default, easily changeable to zsh/fish

## 🛠️ Advanced Configuration

### Custom User & Passwords

```bash
# Set before running setup
export ARCH_USER="myusername"
export ARCH_USER_PASS="mypassword"
export ARCH_ROOT_PASS="myrootpass"
./start.sh
```

### Shell Customization

```bash
# Install and configure zsh with Oh-My-Zsh
./tools/setup-shell.sh

# Or manually
./enter-arch-user.sh
sudo pacman -S zsh
chsh -s /usr/bin/zsh
```

### Development Environment

```bash
# Full development setup with Git, editors, and tools
./tools/dev-setup.sh

# Custom package collections
./tools/install-packages.sh neovim docker kubectl helm terraform
```

## 🐛 Troubleshooting

### Common Issues

**Permission denied errors:**
```bash
# Run the essential devices fix
./fixes/fix-essential-devices.sh
```

**Package installation fails:**
```bash
# Clear pacman cache and retry
./enter-arch.sh
rm -f /var/lib/pacman/db.lck
pacman -Sy
```

**User login issues:**
```bash
# Debug user setup
./debug-setup.sh

# Recreate user
./enter-arch.sh
userdel -r developer
./scripts/06-setup-users.sh
```

### Debug Information

```bash
# Comprehensive system check
./tools/dashboard.sh

# Check specific components
./debug-setup.sh
```

## 🔧 Container Compatibility

This project handles several container limitations:

- **Device nodes** - Creates working `/dev/null`, `/dev/zero`, etc.
- **Mount restrictions** - Graceful fallbacks for `/proc`, `/sys`, `/dev`
- **SSL certificates** - Copies from Ubuntu host for HTTPS access
- **File descriptors** - Proper `/dev/fd` setup for shells and tools
- **User authentication** - Container-safe user switching

## 🚀 RunPod Integration

Perfect for RunPod workflows:

1. **GPU Access** - Inherits GPU access from host container
2. **Persistent Storage** - Survives container restarts in `/workspace`
3. **No Privileges Required** - Works in standard RunPod containers
4. **Network Access** - Full internet connectivity for package downloads
5. **SSH Compatible** - Works with RunPod's SSH access

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Report Issues** - Container compatibility problems, package conflicts
2. **Add Fixes** - New compatibility fixes for different environments
3. **Improve Documentation** - Usage examples, troubleshooting guides
4. **Feature Requests** - New tools, better automation

### Development Setup

```bash
git clone https://github.com/yourusername/arch-chroot-runpod.git
cd arch-chroot-runpod

# Test your changes
./start.sh
./tools/dashboard.sh
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Arch Linux](https://archlinux.org/) for the amazing distribution
- [RunPod](https://runpod.io/) for GPU cloud infrastructure
- Container community for compatibility solutions

## ⭐ Star History

If this project helped you, please consider giving it a star! It helps others discover this tool.

---

**Made with ❤️ for the Arch Linux and container communities**

> *"I use Arch btw... in containers"* 🐧🐳