#!/bin/bash
set -e
# Colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
CYAN='\e[36m'
RESET='\e[0m'
AQUA='\e[38;5;51m' 
MAGENTA='\e[35m'
ORANGE='\e[38;5;208m'
LAVENDER='\e[38;5;183m'
# ===============================
# Configuration
# ===============================
LOG_FILE="/tmp/tool_installer.log"
DEBUG=false
# ===============================
# Display Banner
# ===============================
show_banner() {
    echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━┓${RESET}"
    echo -e "${GREEN}┃   ${AQUA}Multi-OS Tool Installer${GREEN}           ┃ ${YELLOW} v6.0   ${GREEN}┃${RESET}"
    echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━┛${RESET}"
    echo -e "  🛠️  ${GREEN}Developed by: ${YELLOW}@mithun_jana${RESET}"
    echo -e "  👤  ${GREEN}User: ${MAGENTA}$USER${RESET}"
    echo -e "  🐧  ${GREEN}Detected OS: ${RED}$OS_TYPE${RESET}"
    
    # Show core dependencies status
    local core_deps=("curl" "wget" "git" "unzip")
    local deps_status=""
    
    for dep in "${core_deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            deps_status+="${GREEN}✓${LAVENDER}$dep${RESET} "
        else
            deps_status+="${RED}✗${LAVENDER}$dep${RESET} "
        fi
    done
    # Show yay status for Arch
    if [ "$OS_TYPE" = "arch" ]; then
        if command -v yay >/dev/null 2>&1; then
            echo -e "  📦  ${GREEN}AUR helper: ${GREEN}✓${ORANGE}yay ${RESET}"
        else
           echo -e "  📦  ${GREEN}AUR helper:${RED}✗${ORANGE}yay${RESET}"
        fi
    fi
    echo -e "  🔁  ${GREEN}Dependencies:${RESET} $deps_status"
    
    echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
}
# ===============================
# Logging Functions
# ===============================
log() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${MAGENTA}}"
    echo -e "${MAGENTA}${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_debug() {
    if [ "$DEBUG" = true ]; then
        local msg="$*"
        msg="${msg//$pkg/${YELLOW}$pkg${BLUE}}"
        echo -e "🔍 ${BLUE}DEBUG: ${msg}${RESET}" | tee -a "$LOG_FILE"
    fi
}

log_error() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${RED}}"
    echo -e "🔴 ${RED}ERROR: ${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_download() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${CYAN}}"
    echo -e "⬇️ ${LAVENDER}${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_install() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${GREEN}}"
    echo -e "🔁 ${BLUE}${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_success() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${GREEN}}"
    echo -e "🟢 ${GREEN}${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_info() {
    local msg="$*"
    msg="${msg//$pkg/${YELLOW}$pkg${CYAN}}"
    echo -e "💡 ${AQUA}${msg}${RESET}" | tee -a "$LOG_FILE"
}

log_warning() {
    local msg="$*"
    echo -e "⚠️ ${YELLOW}WARNING: ${msg}${RESET}" | tee -a "$LOG_FILE"
}
# ===============================
# Utility Functions
# ===============================
cleanup() {
    log_debug "Cleaning up temporary files"
    rm -rf /tmp/yay /tmp/ghauri /tmp/dirsearch /tmp/amass
}

trap cleanup EXIT
# ===============================
# System Detection
# ===============================
detect_os() {
    if [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/debian_version ] || [ -f /etc/kali-release ] || grep -q "Parrot" /etc/os-release 2>/dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
# ===============================
# Package Manager Functions
# ===============================
install_pkg() {
    local pkg="$1"
    log_install "install package: $pkg"
    
    case "$OS_TYPE" in
        "arch")
            if command -v yay >/dev/null 2>&1; then
                if ! yay -S --needed --noconfirm "$pkg"; then
                    log "yay failed for $pkg, trying pacman..."
                    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null
                    local pacman_exit=$?
                    if [ $pacman_exit -ne 0 ]; then
                        if [ $pacman_exit -eq 130 ]; then  # 130 is exit code for SIGINT
                            log_error "Installation interrupted by user"
                            return 130
                        else
                            log_error "failed to install $pkg"
                            return 1
                        fi
                    fi
                fi
            else
                sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null
                local pacman_exit=$?
                if [ $pacman_exit -ne 0 ]; then
                    if [ $pacman_exit -eq 130 ]; then
                        log_error "Installation interrupted by user"
                        return 130
                    else
                        log_error "failed to install $pkg"
                        return 1
                    fi
                fi
            fi
            ;;
        "debian")
            sudo apt-get update || {
                log_error "failed to update package lists"
                return 1
            }
            # Run apt-get with sudo and handle interruption
            sudo apt-get install -y "$pkg" 2>/dev/null
            local apt_exit=$?
            if [ $apt_exit -ne 0 ]; then
                if [ $apt_exit -eq 130 ]; then
                    log_error "Installation interrupted by user"
                    return 130
                else
                    log_error "failed to install $pkg"
                    return 1
                fi
            fi
            ;;
    esac
    log_success "$pkg Installation complete"
    return 0
}

install_pkg_aur() {
    local pkg="$1"
    if [ "$OS_TYPE" = "arch" ]; then
        log_install "install AUR package: $pkg"
        yay -S --needed --noconfirm "$pkg" || {
            log_error "failed to install AUR package: $pkg"
            return 1
        }
        log_success "Installed AUR package: $pkg"
    else
        log_info "AUR package '$pkg' not available on Debian. Attempting manual installation..."
        install_manual_debian "$pkg"
    fi
}

# ===============================
# Manual Installation for Debian
# ===============================
install_manual_debian() {
    local pkg="$1"
    log "Attempting manual installation for Debian: $pkg"
    
    case "$pkg" in
        "amass-bin")
            install_amass_manual ;;
        "subfinder")
            install_subfinder_manual ;;
        "nuclei")
            install_nuclei_manual ;;
        "feroxbuster")
            install_feroxbuster_manual ;;
        "stacer-git")
            install_stacer_manual ;;
        "burpsuitepro")
            install_burpsuitepro ;;
        "gau")
            install_gau_manual ;;
        "rustscan")
            install_rustscan_manual ;;
        "sublime-text-4")
            install_sublime_text ;;
        *) 
            log_error "No manual installation method for: $pkg"
            return 1 ;;
    esac
}
#=======sublime====
sublime_config(){
    echo "Configuring sublime Text..."
    
    # Correct paths using ~
    mkdir -p ~/.config/sublime-text/Packages
    mkdir -p ~/.config/sublime-text/Packages/User
    log_download "download catpucchine theme...."
    # Clone theme
    git clone https://github.com/catppuccin/sublime-text.git ~/.config/sublime-text/Packages/Catppuccin 2>/dev/null || true
    
    # Create settings
    cat > ~/.config/sublime-text/Packages/User/Preferences.sublime-settings <<'EOF'
{
    "font_size": 17,
    "theme": "auto",
    "color_scheme": "Catppuccin Macchiato.sublime-color-scheme",
    "dark_color_scheme": "Monokai.sublime-color-scheme",
    "light_color_scheme": "Celeste.sublime-color-scheme",
    "ignored_packages": [
        "Vintage"
    ]
}
EOF

    log_success " Sublime Text configured"
}
install_sublime_text() {
if [ "$OS_TYPE" = "arch" ]; then
    yay -S --needed --noconfirm sublime-text-4
    log "sublime configuration applied...."
    sublime_config
    return 0
fi
    if ! command -v subl >/dev/null 2>&1 && [ ! -f /opt/sublime_text/sublime_text ]; then
        log "install sublime Text 4 via direct download..."
        
        # Download the latest .deb package
        local download_url="https://download.sublimetext.com/sublime-text_build-4169_amd64.deb"
        local download_path="/tmp/sublime-text.deb"
        
        log_download "download sublime Text..."
        if wget -q --show-progress "$download_url" -O "$download_path"; then
            log_install "install sublime text..."
            sudo dpkg -i "$download_path" || {
                log "fixing dependencies..."
                sudo apt-get install -f -y                
            }
            
            # Cleanup
            rm -f "$download_path"
            
            if command -v subl >/dev/null 2>&1 || [ -f /opt/sublime_text/sublime_text ]; then
                log "sublime configuration applied..."
                sublime_config
                log_success "sublime install & configuration applied successful..."
            else
                log_error "sublime text installation failed"
                return 1
            fi
        else
            log_error "failed to download sublime text"
            return 1
        fi
        
    else
        log_success "sublime text already installed"
    fi
}
#=============
#==rust=========
install_rustscan_manual() {
# Skip manual installation on Arch - use AUR package instead
if [ "$OS_TYPE" = "arch" ]; then
    yay -S --needed --noconfirm rustscan
    return 0
fi
    if ! command -v rustscan >/dev/null 2>&1; then
        log_install "install rustscan manually..."
        
        # Get the latest release information
        local repo="bee-san/rustscan"
        local api_url="https://api.github.com/repos/$repo/releases/latest"
        
        log "fetching latest rustscan release info..."
        local release_info
        release_info=$(curl -s "$api_url")
        local latest_version
        latest_version=$(echo "$release_info" | grep -oP '"tag_name": "\K[^"]*')
        
        if [ -z "$latest_version" ]; then
            log_error "failed to get latest rustscan version"
            return 1
        fi
        
        log "latest rustscan version: $latest_version"
        
        # Extract download URL for .deb.zip file
        local download_url
        download_url=$(echo "$release_info" | grep -oP '"browser_download_url": "\K[^"]*' | grep -E ".*\.deb\.zip" | head -1)
        
        if [ -z "$download_url" ]; then
            log_error "No .deb.zip file found in latest release"
            log_info "available assets in release:"
            echo "$release_info" | grep -oP '"browser_download_url": "\K[^"]*'
            return 1
        fi
        
        local download_path="/tmp/rustscan.deb.zip"
        
        log_download "download rustscan from: $download_url"
        if wget -q --show-progress "$download_url" -O "$download_path"; then
            log "download completed successfully"
            
            # Extract the zip file
            log "extracting rustscan package..."
            if unzip -q "$download_path" -d /tmp/; then
                # Look for the .deb file
                local deb_file
                deb_file=$(find /tmp -name "*.deb" -type f | head -1)
                
                if [ -n "$deb_file" ] && [ -f "$deb_file" ]; then
                    log "Found deb package: $deb_file"
                    
                    # Install the .deb package
                    log_install "install rustscan..."
                    if sudo dpkg -i "$deb_file"; then
                        log_success "rustscan $latest_version installed successfully"
                    else
                        log "fixing dependencies..."
                        sudo apt-get install -f -y
                        
                        # Verify installation
                        if command -v rustscan >/dev/null 2>&1; then
                            log_success "rustscan $latest_version installed successfully after dependency fix"
                        else
                            log_error "rustscan installation failed even after dependency fix"
                            return 1
                        fi
                    fi
                else
                    log_error "no deb package found in the extracted files"
                    log_info "contents of extracted files:"
                    find /tmp -name "*.deb" -type f
                    return 1
                fi
            else
                log_error "failed to extract rustscan package"
                return 1
            fi
            
            # Cleanup
            log "cleaning up temporary files..."
            rm -f "$download_path"
            rm -f /tmp/*.deb
            rm -rf /tmp/rustscan*
            
        else
            log_error "failed to download rustscan from: $download_url"
            log_error "Please check your internet connection and try again"
            return 1
        fi
        
        # Verify installation
        if command -v rustscan >/dev/null 2>&1; then
            local version
            version=$(rustscan --version 2>/dev/null | head -1 || echo "$latest_version")
            log_success "rustscan installed successfully - version: $version"
        else
            log_error "rustscan installation verification failed"
            return 1
        fi
        
    else
        local version
        version=$(rustscan --version 2>/dev/null | head -1 || echo "unknown")
        log_success "rustscan already installed - version: $version"
    fi
}

install_gau_manual() {
    export PATH="/usr/local/bin:$PATH"
    pkg="gau"
    if ! command -v gau >/dev/null 2>&1; then
        log_install "install $pkg manually using Go..."
        
        # Install Go if not present
        if ! command -v go >/dev/null 2>&1; then
            log "install Go..."
            install_pkg golang-go || {
                log_error "failed to install Go"
                return 1
            }
        fi
        
        # Set GOPATH if not set
        if [ -z "$GOPATH" ]; then
            export GOPATH="$HOME/go"
            export PATH="$PATH:$GOPATH/bin"
        fi
        
        # Create GOPATH directories if they don't exist
        mkdir -p "$GOPATH/bin"
        
        log_install "install gau v2..."
        log_download "download gau package..."
        git clone https://github.com/lc/gau.git; \
        cd gau/cmd/gau; \
        go build; \
        sudo mv gau /usr/local/bin/; \
        gau --version;
        
        # Add GOPATH to shell rc if not already there
        if ! grep -q "GOPATH" "$HOME/.zshrc" 2>/dev/null; then
            echo "export GOPATH=\"\$HOME/go\"" >> "$HOME/.bashrc"
            log_info "Added GOPATH to ~/.bashrc"
        fi
        
        # Verify installation
        if  command -v gau >/dev/null 2>&1; then
            log_success "$pkg installed manually"
        else
            log_error "$pkg installation verification failed"
            return 1
        fi
    else
        log_success "$pkg already installed"
    fi
}

install_amass_manual() {
    if ! command -v amass >/dev/null 2>&1; then
        log_install "install Amass manually..."
        local latest_url
        latest_url=$(curl -s https://api.github.com/repos/OWASP/Amass/releases/latest | grep -oP '"browser_download_url": "\K(.*amass_.*_linux_amd64.zip)(?=")')
        if [ -n "$latest_url" ]; then
            wget -q "$latest_url" -O /tmp/amass.zip
            unzip -q /tmp/amass.zip -d /tmp/amass
            sudo cp /tmp/amass/amass_*/amass /usr/local/bin/
            sudo chmod +x /usr/local/bin/amass
            log_success "amass installed manually"
        else
            log_error "failed to download Amass"
            return 1
        fi
    else
        log_success "amass already installed"
    fi
}

install_subfinder_manual() {
    if ! command -v subfinder >/dev/null 2>&1; then
        log_install "install Subfinder manually..."
        local latest_url
        latest_url=$(curl -s https://api.github.com/repos/projectdiscovery/subfinder/releases/latest | grep -oP '"browser_download_url": "\K(.*subfinder_.*_linux_amd64.zip)(?=")')
        if [ -n "$latest_url" ]; then
            wget -q "$latest_url" -O /tmp/subfinder.zip
            unzip -q /tmp/subfinder.zip -d /tmp/subfinder
            sudo cp /tmp/subfinder/subfinder /usr/local/bin/
            sudo chmod +x /usr/local/bin/subfinder
            log_success "Subfinder installed manually"
        else
            log_error "failed to download Subfinder"
            return 1
        fi
    else
        log_success "Subfinder already installed"
    fi
}

install_nuclei_manual() {
    if ! command -v nuclei >/dev/null 2>&1; then
        log_download "download Nuclei package..."
        local latest_url
        latest_url=$(curl -s https://api.github.com/repos/projectdiscovery/nuclei/releases/latest | grep -oP '"browser_download_url": "\K(.*nuclei_.*_linux_amd64.zip)(?=")')
        if [ -n "$latest_url" ]; then
            wget -q "$latest_url" -O /tmp/nuclei.zip
            unzip -q /tmp/nuclei.zip -d /tmp/nuclei
            sudo cp /tmp/nuclei/nuclei /usr/local/bin/
            sudo chmod +x /usr/local/bin/nuclei
            log_success "nuclei installed manually"
        else
            log_error "failed to download Nuclei"
            return 1
        fi
    else
        log_success "nuclei already installed"
    fi
}

install_feroxbuster_manual() {
    if ! command -v feroxbuster >/dev/null 2>&1; then
        log_install "install feroxbuster manually..."
        # Try multiple methods to get the latest release URL
        local latest_url=""
        
        # Method 1: Direct download from GitHub releases
        local repo="epi052/feroxbuster"
        local api_url="https://api.github.com/repos/$repo/releases/latest"
        
        log "fetching latest feroxbuster release info..."
        local release_info
        release_info=$(curl -s "$api_url")
        
        # Extract download URL for Linux x86_64 binary
        latest_url=$(echo "$release_info" | grep -oP '"browser_download_url": "\K[^"]*' | grep -E "x86_64.*linux.*tar" | head -1)
        
        # Method 2: If first method fails, try alternative pattern matching
        if [ -z "$latest_url" ]; then
            log "trying alternative URL extraction..."
            latest_url=$(echo "$release_info" | grep -oP '"browser_download_url": "\K(.*feroxbuster.*linux.*x86_64[^"]*)' | head -1)
        fi
        
        if [ -n "$latest_url" ]; then
            # Extract filename from URL
            local filename
            filename=$(basename "$latest_url")
            local download_path="/tmp/$filename"
            
            log_download "download feroxbuster from: $latest_url"
            log "saving to: $download_path"
            
            # Download with proper filename
            if wget -q --show-progress "$latest_url" -O "$download_path"; then
                log "download completed successfully"
                
                # Extract based on file extension
                log "extracting archive..."
                if [[ "$filename" =~ \.tar\.xz$ ]]; then
                    tar -xf "$download_path" -C /tmp
                elif [[ "$filename" =~ \.tar\.gz$ ]]; then
                    tar -xzf "$download_path" -C /tmp
                elif [[ "$filename" =~ \.tar$ ]]; then
                    tar -xf "$download_path" -C /tmp
                else
                    log_error "unsupported archive format: $filename"
                    return 1
                fi
                
                # Find and copy the feroxbuster binary
                log "looking for feroxbuster binary..."
                local found_binary
                found_binary=$(find /tmp -name "feroxbuster" -type f -executable 2>/dev/null | head -1)
                
                if [ -n "$found_binary" ]; then
                    log "Found binary at: $found_binary"
                    sudo cp "$found_binary" /usr/local/bin/feroxbuster
                    sudo chmod +x /usr/local/bin/feroxbuster
                    
                    # Verify installation
                    if command -v feroxbuster >/dev/null 2>&1; then
                        local version
                        version=$(feroxbuster -V 2>/dev/null || echo "unknown")
                        log_success "feroxbuster installed successfully - version: $version"
                    else
                        log_success "feroxbuster installed manually (binary copied to /usr/local/bin/)"
                    fi
                else
                    # Alternative: look in common extraction directories
                    local alt_paths=(
                        "/tmp/feroxbuster"
                        "/tmp/feroxbuster/feroxbuster"
                        "/tmp/x86_64-linux-feroxbuster/feroxbuster"
                    )
                    
                    for alt_path in "${alt_paths[@]}"; do
                        if [ -f "$alt_path" ] && [ -x "$alt_path" ]; then
                            log "found binary at alternative path: $alt_path"
                            sudo cp "$alt_path" /usr/local/bin/feroxbuster
                            sudo chmod +x /usr/local/bin/feroxbuster
                            log_success "feroxbuster installed from alternative path"
                            break
                        fi
                    done
                    
                    if ! command -v feroxbuster >/dev/null 2>&1; then
                        log_error "Could not find feroxbuster binary in extracted files"
                        log_info "Contents of /tmp:"
                        find /tmp -maxdepth 1 -name "*ferox*" -o -name "feroxbuster*" 2>/dev/null || echo "No feroxbuster files found"
                        return 1
                    fi
                fi
                
                # Cleanup
                rm -f "$download_path"
                rm -rf /tmp/feroxbuster* /tmp/x86_64-linux-feroxbuster*
                
            else
                log_error "failed to download feroxbuster"
                return 1
            fi
            
        else
            log_error "failed to determine feroxbuster download URL"
            log_info "You can manually install it from: https://github.com/epi052/feroxbuster/releases"
            return 1
        fi
    else
        local version
        version=$(feroxbuster -V 2>/dev/null || echo "unknown")
        log_success "feroxbuster already installed - version: $version"
    fi
}
install_stacer_manual() {
    if ! command -v stacer >/dev/null 2>&1; then
        log_install "install stacer manually..."
        wget -q https://github.com/oguzhaninan/Stacer/releases/download/v1.1.0/stacer_1.1.0_amd64.deb -O /tmp/stacer.deb
        sudo dpkg -i /tmp/stacer.deb || sudo apt-get install -f -y
        log_success "stacer installed manually"
    else
        log_success "stacer already installed"
    fi
}

# ===============================
# Categories and Packages
# ===============================
declare -A categories

if [ "$OS_TYPE" = "arch" ]; then
    categories[vmware]="virtualbox-guest-utils open-vm-tools xf86-input-vmmouse"
    categories[reverse_engineering]="pyinstractor ghidra ILSpy" 
    categories[sound]="pipewire pipewire-pulse wireplumber"
    categories[recon]="amass-bin subfinder httpx nikto nuclei wpscan gau"
    categories[network]="netdiscover arp-scan nmap rustscan aircrack-ng wifite wireless_tools wpa_supplicant wireshark-qt"
    categories[bruteforce]="dirsearch feroxbuster ffuf gobuster crunch hashcat hydra john wordlists"
    categories[exploitation]="metasploit exploitdb social-engineer-toolkit sqlmap ghauri"
    categories[utils]="python3-pip nano git curl openssh git-dumper gnu-netcat net-tools openvpn zip "
    categories[productivity]="firefox gparted konsole nano neofetch qogir-icon-theme qterminal remmina stacer-git sublime-text-4 vim vlc xarchiver xterm"

else
    # Debian/Kali/Parrot packages with manual fallbacks
    categories[vmware]="open-vm-tools"
    categories[sound]="pipewire wireplumber alsa-utils pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack"
    categories[recon]="amass subfinder httpx-toolkit nikto nuclei wpscan gau"  
    categories[network]="netdiscover arp-scan nmap rustscan aircrack-ng wifite wireless-tools wpasupplicant wireshark"
    categories[bruteforce]="dirb dirbuster dirsearch feroxbuster ffuf gobuster crunch hashcat hydra john wordlists seclists"
    categories[exploitation]="metasploit-framework exploitdb set sqlmap ghauri powershell-empire"
    categories[utils]="sublime-text-4 python3-pip nano git curl openssh-client git-dumper netcat-openbsd net-tools openvpn zip "  # Will use manual install
    categories[productivity]="firefox gparted konsole nano qterminal remmina stacer-git vim vlc xarchiver xterm"  # Will use manual install
    categories[reverse_engineering]="pyinstractor ghidra ILSpy"
    categories[Active_Directory]="python3-impacket"
fi

# ===============================
# Install AUR helper (Arch only)
# ===============================
install_yay() {
    pkg="yay"
    if [ "$OS_TYPE" != "arch" ]; then
        log_info "Skipping yay installation (not on Arch Linux)"
        return
    fi
    
    if command -v yay >/dev/null 2>&1; then
        log
    else
        log_install "install yay..."
        sudo pacman -S --needed --noconfirm base-devel || {
            log_error "failed to install base-devel"
            return 1
        }
        cd /tmp
        if [ ! -d yay ]; then
            log_download "download yay package..."
            git clone https://aur.archlinux.org/yay.git || {
                log_error "failed to clone yay repository"
                return 1
            }
        fi
        cd yay
        makepkg -si --noconfirm || {
            log_error "failed to build and install yay"
            return 1
        }
        cd - > /dev/null
        log_success "yay installed successfully"
    fi
}

# ===============================
# Check if package exists and is installed
# ===============================
check_package_status() {
    local pkg="$1"
    local status=2

    set +e  # disable exit-on-error inside this function
        # Special case for pyinstractor
    if [ "$pkg" = "pyinstractor" ]; then
        if [ -d "$HOME/Desktop/pyinstractor" ]; then
            set -e
            return 1  # Installed
        fi
    fi
    if [ "$pkg" = "ILSpy" ]; then
        if [ -d "$HOME/Desktop/ILSpy" ]; then
            set -e
            return 1  # Installed
        fi
    fi
    # Check if package is installed
    if [ "$OS_TYPE" = "arch" ]; then
        if pacman -Q "$pkg" &>/dev/null; then
            set -e
            return 0  # Installed
        fi

        # Check if exists in repos
        if pacman -Si "$pkg" &>/dev/null; then
            set -e
            return 1  # Exists in repos, not installed
        fi

        # Check if exists in AUR
        if command -v yay >/dev/null 2>&1; then
            if yay -Si "$pkg" &>/dev/null; then
                set -e
                return 1  # Exists in AUR, not installed
            fi
        fi
    else
        # Debian-based check
        if dpkg -l "$pkg" &>/dev/null; then
            set -e
            return 0  # Installed
        fi

        # Check if exists in repositories
        if apt-cache show "$pkg" &>/dev/null; then
            set -e
            return 1  # Exists in repos, not installed
        fi
        
        # Check if we have manual installation method
        case "$pkg" in
            "amass-bin"|"subfinder"|"nuclei"|"feroxbuster"|"stacer-git"|"burpsuitepro"|"gau"|"rustscan"|"sublime-text-4"|"pyinstractor"|"ILSpy")
                set -e
                return 1  # Has manual installation method
                ;;
        esac
    fi

    set -e
    return 2  # Not found anywhere
}
#ensure package for existance pkg
ensure_pkg() {
    local pkg="$1"
    
    if check_package_status "$pkg"; then
        log_success "$pkg is already installed"
        return 0
    fi
    
    log_install "Installing $pkg..."
    install_pkg "$pkg"
    return $?  # Return the exit code from install_pkg
}
# ===============================
# Install Packages with existence check
# ===============================
install_packages() {
    local pkgs=("$@")
    local to_install=()
    local sound_installed=false
    local wordlist_installed=false
    local vmware_installed=false 
    
    log "Checking package status..."
    for pkg in "${pkgs[@]}"; do
        log_debug "Checking: $pkg"
        
        # Special handling for tools that need manual installation
        case "$pkg" in
            "ghauri"|"git-dumper"|"netdiscover"|"burpsuitepro"|"feroxbuster")
                if command -v "$pkg" &>/dev/null; then
                    log_success "$pkg is already installed."
                else
                    log "🔄 $pkg will be installed (manual setup)"
                    to_install+=("$pkg")
                fi
                ;;
                "pyinstractor")
                if [ -d "$HOME/Desktop/pyinstractor" ] && [ -f "$HOME/Desktop/pyinstractor/pyinstxtractor.py" ]; then
                    log_success "pyinstractor is already installed."
                else
                    log "🔄 pyinstractor will be installed (manual setup)"
                    to_install+=("$pkg")
                fi
                ;;
                "ILSpy")
                if [ -d "$HOME/Desktop/ILSpy" ]; then
                    log_success "ILSpy is already installed."
                else
                    log "🔄 ILSpy will be installed (manual setup)"
                    to_install+=("$pkg")
                fi
                ;;
                "gau")
                # Special case for gau
                if command -v gau &>/dev/null; then
                    log_success "gau is already installed."
                else
                    log "🔄 gau will be installed (manual setup)"
                    to_install+=("$pkg")
                fi
                ;;
            "dirsearch")
                if command -v dirsearch &>/dev/null; then
                    log_success "dirsearch is already installed."
                else
                    log "🔄 dirsearch will be installed (manual setup)"
                    to_install+=("$pkg")
                fi
                ;;
            "python3-pip")
                if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
                    log_success "python3-pip is already installed."
                else
                    log "🔄 pip will be installed."
                    to_install+=("$pkg")
                fi
                ;;
            "sublime-text-4")
                if command -v subl &>/dev/null; then
                log_success "sublime-text-4 is already installed (as 'subl' command)."
                else
                log "🔄 sublime-text-4 will be installed (manual setup)"
                to_install+=("$pkg")
                fi
                ;;
            *)
                if check_package_status "$pkg"; then
                    status=0
                else
                    status=$?
                fi
                
                case $status in
                    0) log_success "$pkg is already installed." ;;
                    1) log "🔄 $pkg will be installed."
                       to_install+=("$pkg") ;;
                    2) log_error "$pkg does not exist in repositories. Skipping." ;;
                esac
                ;;
        esac
    done
    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All packages are already installed"
        return
    fi
    echo
    log_install "Packages to install: ${YELLOW}${to_install[*]}${RESET}"
    read -rp "Continue with installation? (y/N): " confirm
    confirm=${confirm:-Y}
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        : # proceed
    else
        log_info "Installation cancelled."
        return 0
    fi

    # Install regular packages first
    local regular_packages=()
    local special_packages=()
    
    for pkg in "${to_install[@]}"; do
        case "$pkg" in
            "ghauri"|"dirsearch"|"git-dumper"|"netdiscover"|"feroxbuster"|"burpsuitepro"|"gau"|"rustscan"|"sublime-text-4"|"pyinstractor"|"ILSpy")
                special_packages+=("$pkg")
                ;;
            *)
                regular_packages+=("$pkg")
                ;;
        esac
    done

    # Install regular packages
    if [ ${#regular_packages[@]} -gt 0 ]; then
        log_install "install regular packages..."
        for pkg in "${regular_packages[@]}"; do
            if [[ "$pkg" =~ -bin$ ]] || [[ "$pkg" =~ -git$ ]]; then
                install_pkg_aur "$pkg"
            else
                install_pkg "$pkg"
            fi
        done
    fi

    # Install special packages
    for pkg in "${special_packages[@]}"; do
        case "$pkg" in
            "ghauri") install_ghauri ;;
            "dirsearch") install_dirsearch ;;
            "git-dumper") install_gitdumper ;;
            "netdiscover") install_netdiscover ;;
            "feroxbuster") install_feroxbuster ;;
            "burpsuitepro") install_burpsuitepro ;;
            "gau") install_gau_manual ;;
            "rustscan") install_rustscan_manual;;
            "sublime-text-4") install_sublime_text;;
            "pyinstractor") install_pyinstractor ;;
            "ILSpy") install_ILSpy ;;
        *)
        esac
    done
# Detect categories based ONLY on actually installed packages
    local sound_installed=false wordlist_installed=false vmware_installed=false
    for pkg in "${to_install[@]}"; do
        [[ " ${categories[sound]} " =~ $pkg ]] && sound_installed=true
        [[ " ${categories[bruteforce]} " =~ $pkg ]] && wordlist_installed=true
        [[ " ${categories[vmware]} " =~ $pkg ]] && vmware_installed=true
    done
    # Post-install hooks based on what was installed
    $sound_installed && post_sound_setup 2>/dev/null || true
    $wordlist_installed && post_wordlist_setup 2>/dev/null || true
    $vmware_installed && post_vmware_setup 2>/dev/null || true
}
# ===============================
# Validate Input Format
# ===============================
validate_input() {
    local input="$1"

    # Allow: letters, numbers, commas, spaces
    if [[ "$input" =~ ^[a-zA-Z0-9,\ ]+$ ]]; then
        return 0
    else
        return 1
    fi
}
# ===============================
# Parse selections (letters for categories, numbers for tools)
# ===============================
parse_mixed_selections() {
    local input="$1"
    local selections=()
    
    if ! validate_input "$input"; then
        log_error "Invalid input format"
        return 2
    fi
    
    IFS=',' read -ra ITEMS <<< "$input"
    for item in "${ITEMS[@]}"; do
        item=$(echo "$item" | tr -d ' ')
        if [[ "$item" =~ ^[a-zA-Z]$ ]]; then
            selections+=("CAT:$item")
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            if [[ "$item" -ge 1 && "$item" -le "${#ALL_TOOLS[@]}" ]]; then
                selections+=("TOOL:$item")
            else
                log_error "Invalid tool number: $item (valid range: 1-${#ALL_TOOLS[@]})"
                return 2
            fi
        else
            log_error "Invalid input: $item"
            return 2
        fi
    done
    printf '%s\n' "${selections[@]}"
    return 0
}
# ===============================
# Main Menu
# ===============================
show_menu() {
    echo -e "${YELLOW}[1]${GREEN} Install ALL categories${RESET}"
    echo -e "${YELLOW}[2] ${GREEN}Install by selection${RESET}"
    echo -e "${YELLOW}[3] ${GREEN}Burpsuite-Pro${RESET}"
    #echo -e "${YELLOW}[4] ${GREEN}Burpsuite-Pro-(stable)${RESET}"
    echo -e "${YELLOW}[4] ${GREEN}Oh-My-Zsh & Plugins${RESET}"
    echo -e "${YELLOW}[5] ${GREEN}Fish-shell & fisher${RESET}"
    echo -e "${YELLOW}[6] ${GREEN}Kitty-terminal & configuration${RESET}"
    echo -e "${YELLOW}[7] ${GREEN}Ulauncher & Catppuccin Theme${RESET}"
    echo -e "${YELLOW}[8] ${RED}Exit${RESET}"
}

# ===============================
# Install all categories
# ===============================
install_all_categories() {
    local all_pkgs=()
    for cat in "${!categories[@]}"; do
        read -ra tools <<< "${categories[$cat]}"
        all_pkgs+=("${tools[@]}")
    done
    log_install "install all categories..."
    install_packages "${all_pkgs[@]}"|| return 1 
}

# ===============================
# Install by selection 
# ===============================
install_by_selection() {
    # Initialize global arrays first
    declare -ga ALL_TOOLS=()
    declare -ga TOOL_TO_CATEGORY=()
    declare -ga CAT_ARRAY=()
    declare -ga CAT_LETTERS=()
    
    while true; do
        # Show categories and tools
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${YELLOW}  Categories & Tools         ${RESET}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        mapfile -t cat_array < <(printf '%s\n' "${!categories[@]}" | sort)
        local all_tools=()
        local tool_to_category=()
        local tool_counter=1
        
        local letters=( {a..z} )
        for i in "${!cat_array[@]}"; do
            local cat="${cat_array[$i]}"
            echo -e "${MAGENTA}[${letters[$i]}-${cat}]${RESET}"
            read -ra tools <<< "${categories[$cat]}"
            for tool in "${tools[@]}"; do
                echo "  [$tool_counter] $tool"
                all_tools+=("$tool")
                tool_to_category+=("$cat")
                ((tool_counter++))
            done
            echo
        done
        
        # Store in global arrays
        ALL_TOOLS=("${all_tools[@]}")
        TOOL_TO_CATEGORY=("${tool_to_category[@]}")
        CAT_ARRAY=("${cat_array[@]}")
        CAT_LETTERS=("${letters[@]}")
        
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "                   ${MAGENTA}Installation Options${RESET}                   "
        echo 
        echo -e "${YELLOW}Choose categories [letters], tools [numbers], or mix them. ${RESET}"
        echo -e "            ${YELLOW}Examples: a,c  |  15,23  |  a,15,23${RESET}            "
        echo -e "                        ${YELLOW}0 Go back to menu${RESET}                  "
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo
        echo -ne "${MAGENTA}Enter choice: ${RESET}" && read -r input
        
        if [[ "$input" == "0" ]]; then
            return
        fi
        
        if [[ -z "$input" ]]; then
            log_error "No input provided"
            echo -e "${BLUE}Press Enter to continue...${RESET}"; read -r
            continue
        fi

        local selections
        selections=$(parse_mixed_selections "$input")
        local parse_result=$?
        
        if [[ $parse_result -ne 0 ]]; then
            echo "Press Enter to continue..."; read -r
            continue
        fi

        local packages_to_install=()
        local selected_categories=()

        while IFS= read -r selection; do
            if [[ "$selection" =~ ^CAT:([a-zA-Z])$ ]]; then
                local letter="${BASH_REMATCH[1],,}"  # Convert to lowercase
                local cat_index=-1
                for i in "${!CAT_LETTERS[@]}"; do
                    if [[ "${CAT_LETTERS[$i],,}" == "$letter" ]]; then
                        cat_index=$i
                        break
                    fi
                done
                
                if [[ $cat_index -ge 0 && $cat_index -lt ${#CAT_ARRAY[@]} ]]; then
                    local cat_name="${CAT_ARRAY[$cat_index]}"
                    log "Selected category: $letter) $cat_name"
                    read -ra tools <<< "${categories[$cat_name]}"
                    packages_to_install+=("${tools[@]}")
                    selected_categories+=("$cat_name")
                else
                    log_error "Invalid category letter: $letter"
                fi
                
            elif [[ "$selection" =~ ^TOOL:([0-9]+)$ ]]; then
                local tool_num="${BASH_REMATCH[1]}"
                local tool_index=$((tool_num - 1))
                
                if [[ $tool_index -ge 0 && $tool_index -lt ${#ALL_TOOLS[@]} ]]; then
                    local tool="${ALL_TOOLS[$tool_index]}"
                    log "Selected tool: $tool_num) $tool"
                    packages_to_install+=("$tool")
                else
                    log_error "Invalid tool number: $tool_num"
                fi
            fi
        done <<< "$selections"

        if [[ ${#packages_to_install[@]} -gt 0 ]]; then
            echo
            echo "Final selection:"
            printf '  - %s\n' "${packages_to_install[@]}"
            echo
            install_packages "${packages_to_install[@]}"
            
            # Run post-install configurations
            for cat in "${selected_categories[@]}"; do
                [[ "$cat" == "vmware" ]] && post_vmware_setup
                [[ "$cat" == "sound" ]] && post_install_sound
                [[ "$cat" == "bruteforce" ]] && post_install_wordlist
                [[ "$cat" == "powershell-empire" ]] && post_log_powershell
            done
            [[ " ${packages_to_install[*]} " =~ " openssh " ]] && post_install_ssh
        else
            log_error "No valid selections made."
        fi
        
        echo "Press Enter to continue..."; read -r
    done
}
##########################
# powershell empire
##########################
post_log_powershell(){
    log_success "powershell-empire install is done..."
    log "run sudo powershell-empire"
    log "username= empireadmin password= password123"
}
########################
#ILSPY
#######################
install_ILSpy() {
    INSTALL_DIR="$HOME/Desktop/ILSpy"
    
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$INSTALL_DIR" || return 1
    
    # Download and extract both zips
    wget https://github.com/icsharpcode/AvaloniaILSpy/releases/download/v7.2-rc/Linux.x64.Release.zip
    unzip -q Linux.x64.Release.zip
    unzip -q -o ILSpy-linux-x64-Release.zip
    unzip -q -o ILSpy-linux-x64-Release.zip -d . 2>/dev/null
    
    # Find any executable named ILSpy
    local BINARY
    BINARY=$(find . -name "ILSpy" -type f -executable 2>/dev/null | head -1)
    if [ -n "$INSTALL_DIR" ]; then
        log_success "Download ILSpy success"
        echo -e "${LAVENDER}# download location $INSTALL_DIR ${RESET}"
        echo -e "${YELLOW}# run by ./ILSPY${RESET}"
    else 
        log_error "Download ILSpy failed"
    fi
    
    rm -f ./*.zip
}
###########################
#pyinstractor
##########################
install_pyinstractor() {
    INSTALL_DIR="$HOME/Desktop/pyinstractor"

    log_download "download pyinstractor in Desktop..."

    if [ -d "$INSTALL_DIR" ]; then
        log_info "pyinstractor directory already exists at $INSTALL_DIR"
        # Check if it was properly installed
        if [ -f "$INSTALL_DIR/pyinstxtractor.py" ]; then
            log_success "pyinstractor already installed"
            return 0
        else
            log_warning "Directory exists but installation might be incomplete"
            log "Removing existing directory..."
            rm -rf "$INSTALL_DIR"
        fi
    fi

    git clone https://github.com/extremecoders-re/pyinstxtractor.git "$INSTALL_DIR" || {
        log_error "Failed to clone pyinstractor repository"
        return 1
    }

    log_success "pyinstractor installed successfully at $INSTALL_DIR"
    log_info "You can run it from: $INSTALL_DIR"
    return 0
}
# ===============================
# kitty Configuration
# ===============================
#emoji
install_emoji_font() {
    log " Checking for existing emoji font..."

    # Check if emoji font already exists
    if fc-list | grep -qi "Noto Color Emoji"; then
        log_info " Emoji font already installed. Skipping installation."
        log_info " Refreshing font cache..."
        fc-cache -fv
        return 0
    fi

    log_install " Emoji font not found. Installing..."

    # Detect OS
    if [ -f /etc/arch-release ]; then

        sudo pacman -Sy --noconfirm noto-fonts-emoji

    elif [ -f /etc/debian_version ]; then

        sudo apt install -y fonts-noto-color-emoji

    else
        log_error " Unsupported distribution"
        return 1
    fi

    log_info " Refreshing font cache..."
    fc-cache -fv

    log_success "Emoji font installation complete!"
}
#nerd-font
install_hack_nerd_font() {
    local FONT_DIR="$HOME/.local/share/fonts/HackNerdFont"

    log_info "Installing Hack Nerd Font..."

    mkdir -p "$FONT_DIR"

    cd /tmp || return

    wget -q --show-progress \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip \
    -O Hack.zip

    unzip -o Hack.zip -d "$FONT_DIR" >/dev/null

    fc-cache -fv >/dev/null

    log_success "Hack Nerd Font installed successfully!"
}
kitty_conf(){
    TARGET="$HOME/.config/kitty/themes/catppuccin"
    TARGET1="$HOME/.config/kitty/themes/dracula"

for dir in "$TARGET" "$TARGET1"; do
    [ -d "$dir" ] && rm -rf "$dir"
done
    log_download "download kitty theme...."
    mkdir -p "$TARGET1"
    git clone https://github.com/dracula/kitty.git "$TARGET1"
    git clone https://github.com/catppuccin/kitty.git "$TARGET"
    mkdir -p ~/.config/kitty/themes
    #git clone https://github.com/catppuccin/kitty.git ~/.config/kitty/themes/catppuccin
    echo "nano syntax-highlighting configuration install.."
    curl https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh
    cat > ~/.config/kitty/kitty.conf <<'EOF'
# ==================================================
# CATPPUCCIN THEME
# ==================================================
include /home/$USER/.config/kitty/themes/catppuccin/themes/frappe.conf

allow_remote_control yes
listen_on unix:/tmp/kitty-$PID
# ==================================================
# FONT
# ==================================================
font_family      family="Hack Nerd Font"
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size 17
adjust_line_height 110%
adjust_column_width 100%

# ==================================================
# CURSOR
# ==================================================
cursor_shape block
cursor_blink_interval 0
cursor_stop_blinking_after 15.0
cursor_trail 200
cursor_trail_decay 0.1 0.4
cursor_trail_start_threshold 2
cursor_trail_color none
# ==================================================
# SCROLLBACK
# ==================================================
scrollback_lines 10000
wheel_scroll_multiplier 5.0

# ==================================================
# MOUSE
# ==================================================
copy_on_select yes
mouse_hide_wait 2.0

# ==================================================
# PERFORMANCE
# ==================================================
repaint_delay 10
input_delay 3
sync_to_monitor yes
repaint_delay 10
input_delay 3
# ==================================================
# WINDOW
# ==================================================
remember_window_size yes
initial_window_width 1000
initial_window_height 700
window_padding_width 8

# Transparency (required for blur via picom)
background_opacity 1.0

# ==================================================
# TAB BAR
# ==================================================
tab_bar_style powerline
tab_powerline_style angled
active_tab_font_style bold
inactive_tab_font_style normal
tab_title_template "{title}"

# ==================================================
# KEY BINDINGS
# ==================================================
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard

map ctrl+t new_tab
map ctrl+shift+w close_tab
map ctrl+shift+enter new_window

map shift+ctrl+right next_tab
map shift+ctrl+left previous_tab
map alt+f toggle_fullscreen
map ctrl+a launch --location=hsplit --cwd=current
map ctrl+left neighboring_window left
map ctrl+right neighboring_window right
map ctrl+up neighboring_window up
map ctrl+down neighboring_window down
map ctrl+shift+f toggle_layout stack

# ==================================================
# FOCUS CURRENT SPLIT + FULLSCREEN (ZOOM)
# ==================================================
map ctrl+z toggle_layout stack
# ==================================================
# SHELL
# ==================================================
shell /bin/zsh
# ==================================================
# MISC
# ==================================================
enable_audio_bell no
EOF

}
install_kitty() {
    log "applying kitty configuration..."
    if [ "$OS_TYPE" = "arch" ]; then
        ensure_pkg kitty iproute2 iptables iputils 
        install_hack_nerd_font
        install_emoji_font
        kitty_conf
        
        
        
    else
        # Debian kitty configuration
        ensure_pkg kitty 
        install_hack_nerd_font
        install_emoji_font
        kitty_conf
        
    fi
    log_success "kitty configuration applied!"
    log_success "kitty key BINDINGS Added.."
    log_success "ctrl+z(zoom),ctrl+a(split).."
    log_success "ctrl+arrow(to change split_terminal),ctrl+d(close_current_tab).."
    log_info "more configuration ~/.config/kitty/kitty.conf"
    log_info "more themes run --> kitten themes <> in terminal"
    log "change background theme type 'kitten themes' & press enter in terminal  "
}
#===========================
#   fish_shell + oh-my-fish
#===========================
fish_conf() {        
    log_download "install oh-my-fish..."
    # Check if fish is installed
    if ! command -v fish &> /dev/null; then
        log "fish is installed"
        return 1
    fi
    FISH_PATH="$(command -v fish)"
    # --- Ensure fish config dirs ---
    mkdir -p ~/.config/fish/functions
    mkdir -p ~/.config/fish/conf.d
    mkdir -p ~/.local/share/fish
    # Install fisher
    if ! fish -c "type -q fisher" >/dev/null 2>&1; then
        log_download "install Fisher..."
        rm -rf /tmp/fisher
        log_download "download fish package...."
        git clone https://github.com/jorgebucaran/fisher.git /tmp/fisher
        cp /tmp/fisher/functions/fisher.fish ~/.config/fish/functions/
        log_success " Fisher installed"
    else
        log_info "Fisher already installed"
    fi
    log_install "install nano syntax highlighting...."
    log_download "download packages..."
    curl -s https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh
    
    log_install "Configuring fish shell..."
    cat > ~/.config/fish/config.fish <<'EOF'
set -g fish_greeting
abbr -e gau

if command -q vivid
    set -Ux LS_COLORS (vivid generate catppuccin-mocha)
end
EOF
    # Run fish configuration using a heredoc
     fish <<'FISH_SCRIPT'
alias ip "ip -color=auto"
funcsave ip

function ping
    grc ping $argv
end

function ps
    grc ps $argv
end

function lsblk
    grc lsblk $argv
end

function ifconfig
    grc ifconfig $argv
end

function ss
    grc ss $argv
end

function nc
    grc nc $argv
end

function traceroute
    grc traceroute $argv
end

function curl
    grc curl $argv
end

function mount
    grc mount $argv
end

funcsave ping
funcsave ps
funcsave lsblk
funcsave ifconfig
funcsave ss
funcsave nc
funcsave traceroute
funcsave curl
funcsave mount 
# Ensure history directory exists
mkdir -p ~/.local/share/fish
FISH_SCRIPT
    # --- Install Fish plugins & theme ---
    log_install "install Fish plugins..."
    fish -c "
        fisher install \
            jorgebucaran/fisher \
            dracula/fish \
            catppuccin/fish \
            jhillyerd/plugin-git \
            edc/bass
    "
    # --- Set  theme ---
    yes | fish -c 'fish_config prompt save "scales"'
    echo 'fish_config theme choose "catppuccin-frappe"' >> ~/.config/fish/config.fish
    log_success "theme enabled"

# --- ZSH → Fish history migration ---
if [ -f "$HOME/.zsh_history" ]; then
    # Check if fish history already exists and has content
    if [ -f "$HOME/.local/share/fish/fish_history" ] && [ -s "$HOME/.local/share/fish/fish_history" ]; then
        log_info "Fish history already exists. Skipping import to avoid duplicates."
    else
        log "Importing zsh history..."
        
        mkdir -p "$HOME/.local/share/fish"
        touch "$HOME/.local/share/fish/fish_history"
        
        LC_ALL=C awk -F';' '
/^: [0-9]+:[0-9]+;/ {
    cmd = $2
    split($1, t, " ")
    timestamp = t[2]
    if (cmd != "")
        printf "- cmd: %s\n  when: %s\n", cmd, timestamp
}
' ~/.zsh_history >> ~/.local/share/fish/fish_history
        
        log_success "History import complete..."
    fi
else
    log "ZSH history not found"
fi
    # --- Update completions ---
    fish -c "fish_update_completions"
    log " Fish completions updated"
    # Check if fish is in /etc/shells
    FISH_PATH=$(which fish)
    if ! grep -q "$FISH_PATH" /etc/shells 2>/dev/null; then
        log "Adding fish to /etc/shells..."
        if command -v sudo &> /dev/null; then
            echo "$FISH_PATH" | sudo tee -a /etc/shells
        else
            echo "$FISH_PATH" | tee -a /etc/shells
        fi
    fi
    
FISH_PATH=$(command -v fish)
if [ -n "$FISH_PATH" ]; then
    log "Setting fish as default shell..."
    
    # Add to /etc/shells if not present
    if ! grep -q "$FISH_PATH" /etc/shells 2>/dev/null; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    
    # Change the shell - 
    sudo usermod -s /usr/bin/fish "$USER"
    
    echo " Fish will be your default shell after logout"
else
    echo "Error: Fish not found!"
fi
}
install_fish() {
    log_install "install fish..."
    
    if [ "$OS_TYPE" = "arch" ]; then
        echo "0. Returning main menu"
        echo "1. Superfast terminal kitty + Fish..?"
        echo "2. Install Fish only"
        echo -n "Enter choice (0,1 or 2): "
        read -r choice
        
        if [ "$choice" = "0" ]; then
                echo "Returning to main menu..."
                return 0
        fi  
        if [ "$choice" = "1" ]; then
            log_install "install fish & kitty in $OS_TYPE...."   
            sudo pacman -S --needed fish grc iproute2 vivid net-tools bat
            fish_conf
            echo 'set -gx BAT_THEME "Catppuccin Mocha"' >> ~/.config/fish/config.fish
            echo "alias cat='bat --paging=never'" >> ~/.config/fish/config.fish
            log_install "install kitty ....."  
            install_kitty
            log "add fish shell in kitty ...."
            # Replace /bin/zsh with fish in kitty.conf
            sed -i 's|/bin/zsh|/bin/fish|g' ~/.config/kitty/kitty.conf 2>/dev/null
            log_info "running kitty terminal"   
            exec kitty        
        else
            log_install "install fish in $OS_TYPE...."
            sudo pacman -S --needed fish grc iproute2 vivid net-tools bat
            fish_conf
            echo 'set -gx BAT_THEME "Catppuccin Mocha"' >> ~/.config/fish/config.fish
            echo "alias cat='bat --paging=never'" >> ~/.config/fish/config.fish
        fi
                
    else
        echo "0. Returning main menu"
        echo "1. Superfast terminal kitty + Fish..?"
        echo "2. Install Fish only"
        echo -n "Enter choice (0,1 or 2): "
        read -r choice
        
        if [ "$choice" = "0" ]; then
            echo "Returning to main menu..."
             return 0
        fi
        if [ "$choice" = "1" ]; then
            log_install "install fish & kitty in $OS_TYPE...."
            sudo apt install fish grc iproute2 vivid bat -y
            fish_conf
            echo 'set -gx BAT_THEME "Catppuccin Mocha"' >> ~/.config/fish/config.fish
            echo "alias cat='batcat --paging=never'" >> ~/.config/fish/config.fish
            log_download "install kitty..."
            install_kitty
            log "add fish shell in kitty ...."
            # Replace /bin/zsh with fish in kitty.conf
            sed -i 's|/bin/zsh|/bin/fish|g' ~/.config/kitty/kitty.conf 2>/dev/null
            log_info "running kitty terminal"
            exec kitty
            
        else
            log_install "install fish in $OS_TYPE...."
            sudo apt install fish grc iproute2 vivid bat
            fish_conf
            echo 'set -gx BAT_THEME "Catppuccin Mocha"' >> ~/.config/fish/config.fish
            echo "alias cat='batcat --paging=never'" >> ~/.config/fish/config.fish
        fi
    fi
    log_success "installation complete in $OS_TYPE...."
    log "reboot system to view changes...."
    log "change themes type fish_config & press enter in terminal"
}
# ===============================
# Ulauncher Installation & Configuration
# ===============================
install_ulauncher() {
    log_install "install Ulauncher..."
    
    # Install Ulauncher based on OS
    if [ "$OS_TYPE" = "arch" ]; then
        # Arch installation
        if command -v yay >/dev/null 2>&1; then
            yay -S --needed --noconfirm ulauncher || {
                log_error "failed to install Ulauncher"
                return 1
            }
        else
            sudo pacman -S --needed --noconfirm ulauncher || {
                log_error "failed to install Ulauncher"
                return 1
            }
        fi
    else
        
        log "Adding Ulauncher repository..."
        
     
        if grep -q "Kali" /etc/os-release 2>/dev/null; then
            # Kali-specific installation - use direct download instead of PPA
            log_download "download Ulauncher package ..."
            
            # Get latest version from GitHub
            local latest_version
            latest_version=$(curl -s https://api.github.com/repos/Ulauncher/Ulauncher/releases/latest | grep -oP '"tag_name": "\K[^"]*' | sed 's/v//')
            
            if [ -z "$latest_version" ]; then
                latest_version="5.15.4"  # Fallback version
            fi
            
            # Download the .deb package
            wget -q --show-progress "https://github.com/Ulauncher/Ulauncher/releases/download/${latest_version}/ulauncher_${latest_version}_all.deb" -O /tmp/ulauncher.deb || {
                # Try alternative URL format
                wget -q --show-progress "https://github.com/Ulauncher/Ulauncher/releases/download/v${latest_version}/ulauncher_${latest_version}_all.deb" -O /tmp/ulauncher.deb || {
                    log_error "failed to download Ulauncher package"
                    return 1
                }
            }
            
            # Install the .deb package
            log_install "install Ulauncher package..."
            sudo dpkg -i /tmp/ulauncher.deb || {
                log "Fixing dependencies..."
                sudo apt-get install -f -y
            }
            
            # Cleanup
            rm -f /tmp/ulauncher.deb
            
        else
            
            # Install required dependencies
            sudo apt-get install -y software-properties-common dirmngr apt-transport-https
            
            # Add the PPA properly
            sudo add-apt-repository -y ppa:agornostal/ulauncher
            sudo apt-get update
            sudo apt-get install -y ulauncher || {
                log_error "failed to install Ulauncher"
                return 1
            }
        fi
    fi
    
    # Verify installation
    if command -v ulauncher >/dev/null 2>&1; then
        log_success "Ulauncher installed successfully"
        # Configure Ulauncher
        configure_ulauncher
    else
        log_error "Ulauncher installation failed"
        return 1
    fi
}

# ===============================
# Configure Ulauncher with Catppuccin Theme
# ===============================
configure_ulauncher() {
    log_install "Configuring Ulauncher with Catppuccin theme..."

    # Define paths
    USER_THEMES_DIR="$HOME/.config/ulauncher/user-themes"
    
    # Create Ulauncher config directories
    mkdir -p "$USER_THEMES_DIR"
    mkdir -p "$HOME/.config/ulauncher/settings"

    # Stop Ulauncher if running
    pkill -f ulauncher 2>/dev/null || true
    sleep 1

    # Check if Ulauncher is installed
    if ! command -v ulauncher >/dev/null 2>&1; then
        log_error "Ulauncher is not installed. Please install it first."
        return 1
    fi

    # Install Catppuccin themes using the official installer
    log_download "download and running Catppuccin theme installer..."
    log_install "install all Catppuccin flavors with blue accent..."
    
    # Run the installer directly from GitHub
    if python3 <(curl -fsSL https://raw.githubusercontent.com/catppuccin/ulauncher/main/install.py) --flavor all --accent blue --radius 14; then
        log_success "Catppuccin themes installed successfully"
    else
        log_warning "failed to install all themes, trying default (Mocha Blue)..."
        if python3 <(curl -fsSL https://raw.githubusercontent.com/catppuccin/ulauncher/main/install.py); then
            log_success "Default Catppuccin Mocha Blue theme installed"
        else
            log_error "failed to install Catppuccin themes"
            return 1
        fi
    fi

    # Verify themes were installed
    log "Verifying theme installation..."
    
    # List all installed Catppuccin themes
    CATPPUCCIN_THEMES=$(find "$USER_THEMES_DIR" -maxdepth 1 -name "Catppuccin-*" -type d | sort)
    
    if [ -z "$CATPPUCCIN_THEMES" ]; then
        log_error "No Catppuccin themes found in $USER_THEMES_DIR"
        ls -la "$USER_THEMES_DIR"
        return 1
    fi
    
    log_success "Found Catppuccin themes:"
    echo "$CATPPUCCIN_THEMES" | while read -r theme; do
        echo "  - $(basename "$theme")"
    done
    
    # Use Catppuccin Mocha Blue as default (most popular)
    DEFAULT_THEME="Catppuccin-Mocha-Blue"
    
    if [ -d "$USER_THEMES_DIR/$DEFAULT_THEME" ]; then
        THEME_NAME="$DEFAULT_THEME"
        log_success "Using default theme: $THEME_NAME"
    else
        # Use the first Catppuccin theme found
        FIRST_THEME=$(basename "$(echo "$CATPPUCCIN_THEMES" | head -1)")
        THEME_NAME="$FIRST_THEME"
        log_success "Using first available theme: $THEME_NAME"
    fi

    # Write Ulauncher settings with the correct theme name and hotkey
    log_install "applying Ulauncher settings..."
    
    # Backup existing settings if they exist
    if [ -f "$HOME/.config/ulauncher/settings.json" ]; then
        cp "$HOME/.config/ulauncher/settings.json" "$HOME/.config/ulauncher/settings.json.bak"
        log_debug "Backed up existing settings"
    fi
    
    cat > "$HOME/.config/ulauncher/settings.json" <<EOF
{
    "blacklisted-apps": [],
    "clear-previous-query": true,
    "grab-mouse-pointer": false,
    "hotkey-show-app": "<Primary>space",
    "hotkey-show-apps": "<Super>space",
    "hotkey-show-apps-delay": 0,
    "max-recent-apps": 0,
    "render-on-screen": "default",
    "show-indicator-icon": true,
    "show-recent-apps": true,
    "terminal-command": "",
    "theme-name": "Catppuccin-Macchiato-Blue",
    "web-browser-command": ""
}
EOF
    
    log_success "Settings applied with theme: $THEME_NAME"

    # Configure autostart
    log_install "Configuring autostart..."
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/ulauncher.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ulauncher
Comment=Application launcher
Exec=ulauncher --hide-window
Icon=ulauncher
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    log_success "Autostart configured"

    # Start Ulauncher
    log "Starting Ulauncher..."
    nohup ulauncher --hide-window > /dev/null 2>&1 &
    sleep 3

    # Final verification
    if pgrep -f ulauncher > /dev/null; then
        log_info " Hotkey: ${YELLOW}ctrl+Space${RESET}"
        log_info "All installed Catppuccin themes:"
        find "$USER_THEMES_DIR" -maxdepth 1 -name "Catppuccin-*" -type d | while read -r theme; do
            theme_name=$(basename "$theme")
            if [ "$theme_name" = "$THEME_NAME" ]; then
                echo -e "   → ${GREEN}$theme_name${RESET} (current)"
            else
                echo -e "   - ${MAGENTA}$theme_name${RESET}"
            fi
        done
        log_info " To change theme: Open Ulauncher → Preferences → Theme"
    else
        log_error "Ulauncher failed to start. Check logs with: journalctl -xe"
    fi
}
#======================
#   Wordlist
#=====================
post_install_wordlist() {
    log "Applying wordlists configuration..."
    
    if [ "$OS_TYPE" = "arch" ]; then
        log "apply all configuration"
    else
        # Debian wordlist configuration
        log_install "install wordlists dependencies...."
        sudo apt install dirb dirbuster seclists -y
    fi
    log_success "wordlists downlaod completed...."
}
# ===============================
# Sound Configuration
# ===============================
post_install_sound() {
  log_success "🔊 Applying sound configuration..."
  mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
  cat > ~/.config/wireplumber/wireplumber.conf.d/50-alsa-config.conf <<'EOF'
monitor.alsa.rules = [
    {
        matches = [
            {
                node.name = "~alsa_output.*"
            }
        ]
        actions = {
            update-props = {
                api.alsa.period-size = 1024
                api.alsa.headroom = 8192
            }
        }
    }
]
EOF
  systemctl --user restart wireplumber pipewire pipewire-pulse
  log_success "Sound configuration applied!"
}
# ===============================
# Oh My Zsh + Plugins
# ===============================
install_ohmyzsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        log_install "install zsh..."
        install_pkg zsh
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_download "download Oh My Zsh..."
        # Verify the install script before executing
        local install_script
        install_script=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
        if echo "$install_script" | head -n 10 | grep -q "ohmyzsh"; then
            RUNZSH=no CHSH=no sh -c "$install_script"
        log_install "install Oh-My-Zsh complete.."
        else
            log_error "failed to download Oh My Zsh install script"
            return 1
        fi
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Install plugins
    log_download "Donwloading plugins ..."
    local plugins=(
        "https://github.com/zsh-users/zsh-autosuggestions"
        "https://github.com/zdharma-continuum/fast-syntax-highlighting"
        "https://github.com/marlonrichert/zsh-autocomplete"
    )

    for plugin in "${plugins[@]}"; do
        local plugin_name
        plugin_name=$(basename "$plugin")
        if [ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]; then
            git clone "$plugin" "$ZSH_CUSTOM/plugins/$plugin_name"
        fi
    done

    # Configure zshrc
    if grep -q "^plugins=" "$HOME/.zshrc"; then
        sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete)/' "$HOME/.zshrc"
    else
        echo 'plugins=(git zsh-autosuggestions fast-syntax-highlighting zsh-autocomplete)' >> "$HOME/.zshrc"
    fi

    if ! grep -q "unalias gau" "$HOME/.zshrc"; then
        echo 'unalias gau 2>/dev/null' >> "$HOME/.zshrc"        
    fi
    
    log_success "Oh My Zsh installed with plugins."
    log_info " Run zsh to start using Oh-My-Zsh"
}
# ===============================
# Burpsuite_pro
# ===============================
install_burpsuitepro() {
    local INSTALL_DIR="$HOME/Burpsuite-Professional"
    local BIN_PATH="/usr/local/bin/burpsuitepro"
    local BASE_URL="https://portswigger-cdn.net/burp/releases/download?product=pro&type=Jar&version="
    local TEMP_DIR="/tmp/burpsuite-$$"

    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    local CURRENT_DIR
    CURRENT_DIR=$(pwd)
    local installed_version=""
    local downloaded_jar=""
    local downloaded_version=""
    
    local INSTALLED_JAR
    INSTALLED_JAR=$(find "$INSTALL_DIR" -maxdepth 1 -name "burpsuite_pro_v*.jar" 2>/dev/null | head -1)
    INSTALLED_JAR=$(basename "$INSTALLED_JAR" 2>/dev/null || true)

    if [ -n "$INSTALLED_JAR" ]; then
        installed_version=$(echo "$INSTALLED_JAR" | grep -oP 'v\K[0-9.]+')
        log_info "Installed Version: $installed_version"
    else
        log_info "BurpSuite not currently installed."
    fi
    # ==========================================
    # Dependencies
    # ==========================================
    log_install "install dependencies..."

    if [ "$OS_TYPE" = "arch" ]; then
        ensure_pkg "axel"
        ensure_pkg "jdk21-openjdk"
        sudo archlinux-java set java-21-openjdk 2>/dev/null || true
    else
        ensure_pkg "axel"
        ensure_pkg "openjdk-21-jdk" || \
        ensure_pkg "openjdk-17-jdk" || \
        ensure_pkg "default-jdk"
    fi
    # ==========================================
    # Download Latest Jar to TEMP directory
    # ==========================================
    log_download "download latest BurpSuite Pro to temporary directory..."
    
    cd "$TEMP_DIR" || return 1

    # Download with axel (saves with original filename)
    axel -a "$BASE_URL"

    downloaded_jar=$(find "$TEMP_DIR" -maxdepth 1 -name "burpsuite_pro_v*.jar" 2>/dev/null | head -1)
    downloaded_jar=$(basename "$downloaded_jar" 2>/dev/null || true)

    if [ -z "$downloaded_jar" ]; then
        log_error "Download failed."
        rm -rf "$TEMP_DIR"
        cd "$CURRENT_DIR"
        return 1
    fi

    downloaded_version=$(echo "$downloaded_jar" | grep -oP 'v\K[0-9.]+')
    log_success "Downloaded Version: $downloaded_version"

    # ==========================================
    #Versions compare
    # ==========================================
    if [ -n "$installed_version" ]; then
        if [ "$installed_version" = "$downloaded_version" ]; then
            log_success "Downloaded version matches installed version ($installed_version)"
            log_info "Removing downloaded file from temp directory..."
            rm -f "$downloaded_jar"
            rm -rf "$TEMP_DIR"
            cd "$CURRENT_DIR"
            return 0
        else
            log_info "New version available: $downloaded_version (current: $installed_version)"
            echo -e "${YELLOW}Do you want to upgrade? (y/N): ${RESET}"
            read -r choice
            choice=${choice:-N}
            
            if [[ ! "$choice" =~ ^[Yy]$ ]]; then
                log_info "Upgrade cancelled. Removing downloaded file..."
                rm -f "$downloaded_jar"
                rm -rf "$TEMP_DIR"
                cd "$CURRENT_DIR"
                return 0
            fi
            
            # User confirmed - proceed with upgrade
            log_install "Proceeding with upgrade to version $downloaded_version..."
            
            # Kill any running BurpSuite processes
            pkill -f burpsuite 2>/dev/null || true
            
            # Remove old launcher and JAR
            sudo rm -f "$BIN_PATH"
            rm -f "$INSTALL_DIR/$INSTALLED_JAR"
            log_success "Old version removed."
        fi
    else
        # No installed version found
        log_download "Install BurpSuite Pro v$downloaded_version? (y/N): "
        read -r choice
        choice=${choice:-N}
        
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled. Removing downloaded file..."
            rm -f "$downloaded_jar"
            rm -rf "$TEMP_DIR"
            cd "$CURRENT_DIR"
            return 0
        fi
    fi
    # ==========================================
    #Move downloaded JAR to installation directory
    # ==========================================
    log_install "Moving BurpSuite Pro v$downloaded_version to installation directory..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Move the JAR file from temp to installation directory
    mv "$TEMP_DIR/$downloaded_jar" "$INSTALL_DIR/"
    log_success "JAR file moved to $INSTALL_DIR"

    # ==========================================
    # Loader from GitHub
    # ==========================================
    log_download "download loader of Burpsuite-Professional..."
    
    # Clone loader repo to a temporary directory (different from JAR temp)
    local LOADER_TEMP_DIR="/tmp/burpsuite-loader-$$"
    rm -rf "$LOADER_TEMP_DIR"
    git clone https://github.com/xiv3r/Burpsuite-Professional.git "$LOADER_TEMP_DIR"
    
    if [ ! -f "$LOADER_TEMP_DIR/loader.jar" ]; then
        log_error "loader.jar not found in repository"
        rm -rf "$LOADER_TEMP_DIR"
        rm -rf "$TEMP_DIR"
        cd "$CURRENT_DIR"
        return 1
    fi
    
    # Copy loader to installation directory
    cp "$LOADER_TEMP_DIR/loader.jar" "$INSTALL_DIR/"
    
    # Clean up loader temp directory
    rm -rf "$LOADER_TEMP_DIR"

    # ==========================================
    # burp Setup
    # ==========================================
    cd "$INSTALL_DIR" || return 1
    
    log_install "Creating launcher script..."

    # Create launcher script
    cat > burpsuitepro <<EOF
#!/bin/bash
java --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
     --add-opens=java.base/java.lang=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED \
     --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED \
     -javaagent:$INSTALL_DIR/loader.jar \
     -noverify \
     -jar $INSTALL_DIR/$downloaded_jar "\$@" &
EOF

    chmod +x burpsuitepro
    sudo cp burpsuitepro /usr/local/bin/

    # Clean up main temp directory
    rm -rf "$TEMP_DIR"

    log_success "BurpSuite Professional v$downloaded_version installed successfully!"
    log_info "Location: $INSTALL_DIR"
    log_info "Command: burpsuitepro"
    
    # Ask if user wants to run loader
    echo
    echo -e "${YELLOW}Do you want to run the loader to generate a license? (y/N): ${RESET}"
    read -r run_loader
    if [[ "$run_loader" =~ ^[Yy]$ ]]; then
        log "Running loader..."
        cd "$INSTALL_DIR" && java -jar loader.jar
    fi
    
    cd "$CURRENT_DIR"
    return 0
}
# ===============================
# Burpsuite_pro_latest
# ===============================
install_burpsuitepro_latest() {
    local INSTALL_DIR="$HOME/Burpsuitepro"
    local BIN_PATH="/usr/local/bin/burpsuitepro"
    local BASE_URL="https://portswigger-cdn.net/burp/releases/download?product=pro&type=linux&version="
    local TEMP_DIR="/tmp/burpsuite-$$"

    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    local CURRENT_DIR
    CURRENT_DIR=$(pwd)
    # ==========================================
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" 2>/dev/null || true
    
    local INSTALLED_sh=""
    local installed_version=""
    local downloaded_sh=""
    local downloaded_version=""
    
    INSTALLED_sh=$(find "$INSTALL_DIR" -maxdepth 1 -name "burpsuite_pro_linux_v*.sh" 2>/dev/null | head -1)
    INSTALLED_sh=$(basename "$INSTALLED_sh" 2>/dev/null || true)

    if [ -n "$INSTALLED_sh" ]; then
        installed_version=$(basename "$INSTALLED_sh" .sh | sed -E 's/.*_v([0-9_]+)/\1/' | tr '_' '.')
        log_info "Installed Version: $installed_version"
    else
        log_info "BurpSuite not currently installed."
    fi
    # ==========================================
    # Dependencies
    # ==========================================
    log_install "install dependencies..."

    if [ "$OS_TYPE" = "arch" ]; then
        ensure_pkg "axel"
        ensure_pkg "jdk21-openjdk"
        sudo archlinux-java set java-21-openjdk 2>/dev/null || true
    else
        ensure_pkg "axel"
        ensure_pkg "openjdk-21-jdk" || \
        ensure_pkg "openjdk-17-jdk" || \
        ensure_pkg "default-jdk"
    fi
    # ==========================================
    # Download Latest sh to TEMP directory
    # ==========================================
    log_download "download latest BurpSuite Pro to temporary directory..."
    
    cd "$TEMP_DIR" || return 1

    # Download with axel (saves with original filename)
    axel -a "$BASE_URL"

    downloaded_sh=$(find "$TEMP_DIR" -maxdepth 1 -name "burpsuite_pro_linux_v*.sh" 2>/dev/null | head -1)
    downloaded_sh=$(basename "$downloaded_sh" 2>/dev/null || true)

    if [ -z "$downloaded_sh" ]; then
        log_error "Download failed."
        rm -rf "$TEMP_DIR"
        cd "$CURRENT_DIR"
        return 1
    fi

    downloaded_version=$(basename "$downloaded_sh" .sh | sed -E 's/.*_v([0-9_]+)/\1/' | tr '_' '.')
    log_success "Downloaded Version: $downloaded_version"

    # ==========================================
    #Versions compare
    # ==========================================
    if [ -n "$installed_version" ]; then
        if [ "$installed_version" = "$downloaded_version" ]; then
            log_success "Downloaded version matches installed version ($installed_version)"
            log_info "Removing downloaded file from temp directory..."
            rm -f "$downloaded_sh"
            rm -rf "$TEMP_DIR"
            cd "$CURRENT_DIR"
            return 0
        else
            log_info "New version available: $downloaded_version (current: $installed_version)"
            echo -e "${YELLOW}Do you want to upgrade? (y/N): ${RESET}"
            read -r choice
            choice=${choice:-N}
            
            if [[ ! "$choice" =~ ^[Yy]$ ]]; then
                log_info "Upgrade cancelled. Removing downloaded file..."
                rm -f "$downloaded_sh"
                rm -rf "$TEMP_DIR"
                cd "$CURRENT_DIR"
                return 0
            fi
            
            # User confirmed - proceed with upgrade
            log_install "Proceeding with upgrade to version $downloaded_version..."
            
            # Kill any running BurpSuite processes
            pkill -f burpsuite 2>/dev/null || true
            
            # Remove old launcher and sh
            sudo rm -f "$BIN_PATH"
            rm -f "$INSTALL_DIR/$INSTALLED_sh"
            log_success "Old version removed."
        fi
    else
        # No installed version found
        log_download "Install BurpSuite Pro v$downloaded_version? (y/N): "
        read -r choice
        choice=${choice:-N}
        
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled. Removing downloaded file..."
            rm -f "$downloaded_sh"
            rm -rf "$TEMP_DIR"
            cd "$CURRENT_DIR"
            return 0
        fi
    fi
    # ==========================================
    #Move downloaded sh to installation directory
    # ==========================================
    log_install "Moving BurpSuite Pro v$downloaded_version to installation directory..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Move the sh file from temp to installation directory
    mv "$TEMP_DIR/$downloaded_sh" "$INSTALL_DIR/"
    cd "$INSTALL_DIR"
    chmod +x burpsuite_pro_linux_v*.sh
    ./burpsuite_pro_linux_v*.sh -q -dir "$INSTALL_DIR"
    log_success "installation file extract to $INSTALL_DIR"

    # ==========================================
    # Loader from GitHub
    # ==========================================
    log_download "download loader of Burpsuite-Professional..."
    
    # Clone loader repo to a temporary directory (different from JAR temp)
    local LOADER_TEMP_DIR="/tmp/burpsuite-loader-$$"
    rm -rf "$LOADER_TEMP_DIR"
    wget https://github.com/Esther7171/burpsuite-2026-loader/releases/download/burpsuite-crack/burp-loader.jar -P "$LOADER_TEMP_DIR"
    
    if [ ! -f "$LOADER_TEMP_DIR/burp-loader.jar" ]; then
        log_error "burp-loader.jar not found in repository"
        rm -rf "$LOADER_TEMP_DIR"
        rm -rf "$TEMP_DIR"
        cd "$CURRENT_DIR"
        return 1
    fi
    
    # Copy loader to installation directory
    cp "$LOADER_TEMP_DIR/burp-loader.jar" "$INSTALL_DIR/"
    
    # Clean up loader temp directory
    rm -rf "$LOADER_TEMP_DIR"

    # ==========================================
    # burp Setup
    # ==========================================
    cd "$INSTALL_DIR" || return 1
    
    log_install "Creating configuration script..."

    # Create custom script
    {
        echo "-XX:MaxRAMPercentage=50"
        echo "-include-options user.vmoptions"
        echo "-noverify"
        echo "-javaagent:burp-loader.jar"
        echo -n "-jar burpsuite_pro.jar"
    } > "$INSTALL_DIR/BurpSuitePro.vmoptions"
 # Clean up main temp directory
    rm -rf "$TEMP_DIR"

    log_success "BurpSuite Professional v$downloaded_version installed successfully!"
    log_info "Location: $INSTALL_DIR"
    log_info "search burpsuite in application"
    
    # Ask if user wants to run loader
    echo
    echo -e "${YELLOW}Do you want to run the loader to generate a license? (y/N): ${RESET}"
    read -r run_loader
    if [[ "$run_loader" =~ ^[Yy]$ ]]; then
        log "Running loader..."
        cd "$INSTALL_DIR" && java -jar burp-loader.jar
    fi
    
    cd "$CURRENT_DIR"
    return 0
}
# ===============================
# SSH Configuration
# ===============================
post_install_ssh() {
    log "Configuring SSH..."
    if [ "$OS_TYPE" = "arch" ]; then
        sudo systemctl enable sshd
        sudo systemctl start sshd
    else
        sudo systemctl enable ssh
        sudo systemctl start ssh
    fi
    log_success "SSH enabled!"
}

# ===============================
# VMware Configuration
# ===============================
post_vmware_setup() {
    log "VMware setup..."
    if [ "$OS_TYPE" = "arch" ]; then
        systemctl list-unit-files | grep -q vmtoolsd && { sudo systemctl enable --now vmtoolsd; log_success "vmtoolsd started"; }
        systemctl list-unit-files | grep -q vmware-vmblock-fuse && { sudo systemctl enable --now vmware-vmblock-fuse; log_success "vmware-vmblock-fuse started";}
        command -v vmware-user >/dev/null && vmware-user & disown
    else
        sudo systemctl enable --now open-vm-tools
        log_success "open-vm-tools started"
    fi
    log_success "VMware Tools configured. Reboot recommended."
}

# ===============================
# Special Tool Installations
# ===============================
install_ghauri() {
    if ! command -v ghauri >/dev/null; then
        log "install Ghauri..."
        log_download "download Dependencies..."
        install_pkg python3-pip
        
        log_download "download ghauri ..."
        git clone https://github.com/r0oth3x49/ghauri.git /tmp/ghauri
        pushd /tmp/ghauri || exit 1
        
        if [ "$OS_TYPE" = "arch" ]; then
            python3 -m pip install --upgrade -r requirements.txt --break-system-packages
            sudo python3 setup.py install
            sudo rm -rf /tmp/ghauri
        else
            pip3 install --upgrade -r requirements.txt --break-system-packages
            sudo python3 setup.py install 
            sudo rm -rf /tmp/ghauri
        fi
        
        popd
        log_success "ghauri installed."
    else
        log_success "ghauri already installed."
    fi
}

install_dirsearch() {
    if ! command -v dirsearch >/dev/null; then
        log_install "install dirsearch..."
        install_pkg python3-pip
        
        if [ "$OS_TYPE" = "arch" ]; then
            python3 -m pip install --upgrade dirsearch --break-system-packages
        else
            pip3 install --upgrade dirsearch  --break-system-packages
        fi
        log_success "dirsearch installed."
    else
        log_success "dirsearch already installed."
    fi
}

install_gitdumper() {
    if ! command -v git-dumper >/dev/null; then
        log_install "install git-dumper..."
        if [ "$OS_TYPE" = "arch" ]; then
            yay -S --needed --noconfirm python-pip
            python3 -m pip install --upgrade git-dumper --break-system-packages
        else
            pip3 install --upgrade git-dumper --break-system-packages
        fi
        log_success "git-dumper installed."
    else
        log_success "git-dumper already installed."
    fi
}

install_feroxbuster() {
    if ! command -v feroxbuster >/dev/null; then
        log_install "install feroxbuster..."
        if [ "$OS_TYPE" = "arch" ]; then
            install_pkg_aur feroxbuster
        else
            install_feroxbuster_manual
        fi
    else
        log_success "feroxbuster already installed."
    fi
}

install_netdiscover() {
    if ! command -v netdiscover >/dev/null; then
        log_install "install netdiscover..."
        if [ "$OS_TYPE" = "arch" ]; then
            install_pkg_aur netdiscover
        else
            install_pkg netdiscover
        fi
        log_success "netdiscover installed."
    else
        log_success "netdiscover already installed."
    fi
}
# ===============================
# Core Dependencies Installation
# ===============================
install_core_dependencies() {

    local core_deps=("curl" "wget" "git" "unzip" "python3")
    local missing_deps=()
    local pkg_manager=""

    echo -e "${CYAN}🔍 Checking core dependencies...${RESET}"

    # Detect missing system binaries
    for dep in "${core_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        else
            echo -e "  ✅ ${GREEN}$dep${RESET} already installed"
        fi
    done

    # Special check for pip (module-based check)
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo -e "  ⚠️ ${YELLOW}pip module missing${RESET}"

        case "$OS_TYPE" in
            arch)
                missing_deps+=("python-pip")
                ;;
            debian)
                missing_deps+=("python3-pip")
                ;;
        esac
    else
        echo -e "  ✅ ${GREEN}pip${RESET} already installed"
    fi

    # If nothing missing
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo
        return 0
    fi

    echo -e "${YELLOW}🔴 Missing: ${missing_deps[*]}${RESET}"
    echo -e "${CYAN}🔄 Installing missing dependencies...${RESET}"

    case "$OS_TYPE" in
        arch)
            pkg_manager="sudo pacman -S --needed --noconfirm"
            sudo pacman -Sy --noconfirm >/dev/null 2>&1 || {
                echo -e "${RED}❌ failed to update package database${RESET}"
                return 1
            }
            ;;
        debian)
            pkg_manager="sudo apt-get install -y"
            sudo apt-get update -qq >/dev/null 2>&1 || {
                echo -e "${RED}❌ failed to update package database${RESET}"
                return 1
            }
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS${RESET}"
            return 1
            ;;
    esac

    # Install all missing at once
    if $pkg_manager "${missing_deps[@]}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Installation completed${RESET}"
    else
        echo -e "${RED}❌ failed to install dependencies${RESET}"
        return 1
    fi

    # Ensure pip module works (extra safety)
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Attempting ensurepip...${RESET}"
        python3 -m ensurepip --upgrade >/dev/null 2>&1
    fi

    # Add ~/.local/bin to PATH if missing
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    echo -e "${GREEN}🎉 All core dependencies installed & verified${RESET}"
    return 0
}
# ===============================
# Main Script
# ===============================
main() {

    # Trap Ctrl+C
    trap 'echo -e "\n${RED}❌ Script interrupted | ${GREEN}See you again ${YELLOW}$USER ${RESET}"; exit 1' INT

    # Validate OS
    if [[ "$OS_TYPE" == "unknown" || -z "$OS_TYPE" ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi

    clear

    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  🚀  ${CYAN}Initializing Core Dependencies${RESET}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Install core dependencies first
    if ! install_core_dependencies; then
        log_error "Core dependency installation failed. Aborting."
        exit 1
    fi
    # Install yay only for Arch
    if [[ "$OS_TYPE" == "arch" ]]; then
        install_yay || {
            log_error "failed to install yay."
            exit 1
        }
    fi

    # ===============================
    # Interactive Menu Loop
    # ===============================
    while true; do
        clear
        show_banner
        show_menu

        echo -ne "${MAGENTA}Enter choice: ${RESET}" && read -r choice

        case "$choice" in
            1) install_all_categories ;;
            2) install_by_selection ;;
            3) install_burpsuitepro_latest ;;
            #4) install_burpsuitepro ;;
            4) install_ohmyzsh ;;
            5) install_fish ;;
            6) install_kitty ;;
            7) install_ulauncher ;;
            8)
                echo -e "\n${GREEN}✅ All tasks finished. See you again ${MAGENTA}$USER${RESET}"
                exit 0
                ;;
            *)
                log_error "Invalid choice."
                sleep 1
                ;;
        esac

        echo
        read -rp "Press Enter to continue..."
    done
}
# Run main function
main "$@"
