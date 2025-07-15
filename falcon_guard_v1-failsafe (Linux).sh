#!/bin/bash

# Falcon Guard V.1 - Cloud Shell Edition
# Secure Anonymity Tool for Google Cloud Shell
# Version: 1.0-cloud

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
FALCON_HOME="$HOME/.falcon-guard"
TOR_CONFIG="$FALCON_HOME/torrc"
PROXY_CONFIG="$FALCON_HOME/proxychains.conf"
FIREFOX_PROFILE="$FALCON_HOME/firefox-profile"

# ASCII Banner
show_banner() {
    echo -e "${CYAN}"
    echo "  ███████╗ █████╗ ██╗      ██████╗ ██████╗ ███╗   ██╗"
    echo "  ██╔════╝██╔══██╗██║     ██╔════╝██╔═══██╗████╗  ██║"
    echo "  █████╗  ███████║██║     ██║     ██║   ██║██╔██╗ ██║"
    echo "  ██╔══╝  ██╔══██║██║     ██║     ██║   ██║██║╚██╗██║"
    echo "  ██║     ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║"
    echo "  ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "${PURPLE}"
    echo "   ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗     ██╗   ██╗ ██╗"
    echo "  ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗    ██║   ██║███║"
    echo "  ██║  ███╗██║   ██║███████║██████╔╝██║  ██║    ██║   ██║╚██║"
    echo "  ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║    ╚██╗ ██╔╝ ██║"
    echo "  ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝     ╚████╔╝  ██║"
    echo "   ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝       ╚═══╝   ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}    Cloud Shell Anonymous Browsing Tool${NC}"
    echo -e "${GREEN}    Version: 1.0-cloud | Optimized for Google Cloud Shell${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo
}

# Check Cloud Shell environment
check_cloud_shell() {
    echo -e "${BLUE}[INFO] Checking Google Cloud Shell environment...${NC}"
    
    if [[ -n "$DEVSHELL_PROJECT_ID" ]]; then
        echo -e "${GREEN}[OK] Running in Google Cloud Shell${NC}"
        echo -e "${CYAN}[INFO] Project ID: $DEVSHELL_PROJECT_ID${NC}"
    else
        echo -e "${YELLOW}[WARNING] Not running in Google Cloud Shell${NC}"
        echo -e "${YELLOW}[INFO] Some features may not work as expected${NC}"
    fi
    
    # Check available resources
    echo -e "${CYAN}[INFO] Available disk space: $(df -h $HOME | tail -1 | awk '{print $4}')${NC}"
    echo -e "${CYAN}[INFO] Memory: $(free -h | grep Mem | awk '{print $2}')${NC}"
}

# Create Falcon Guard directory structure
create_directories() {
    echo -e "${BLUE}[INFO] Creating Falcon Guard directories...${NC}"
    
    mkdir -p "$FALCON_HOME"
    mkdir -p "$FALCON_HOME/data"
    mkdir -p "$FALCON_HOME/logs"
    mkdir -p "$FALCON_HOME/bin"
    
    echo -e "${GREEN}[OK] Directory structure created${NC}"
}

# Install required packages
install_packages() {
    echo -e "${BLUE}[INFO] Installing required packages...${NC}"
    
    # Update package list
    sudo apt-get update -qq
    
    # Install packages
    local packages=("tor" "proxychains" "curl" "wget" "socat" "netcat")
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo -e "${YELLOW}[INFO] Installing $package...${NC}"
            sudo apt-get install -y "$package"
        else
            echo -e "${GREEN}[OK] $package is already installed${NC}"
        fi
    done
    
    # Install Firefox if not available
    if ! command -v firefox &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing Firefox...${NC}"
        sudo apt-get install -y firefox-esr
    fi
    
    echo -e "${GREEN}[OK] All packages installed${NC}"
}

# Configure Tor for Cloud Shell
configure_tor() {
    echo -e "${BLUE}[INFO] Configuring Tor for Cloud Shell...${NC}"
    
    # Create Tor configuration
    cat << EOF > "$TOR_CONFIG"
# Falcon Guard Tor Configuration for Cloud Shell
SocksPort 9050
ControlPort 9051
DataDirectory $FALCON_HOME/data/tor
PidFile $FALCON_HOME/data/tor.pid
Log notice file $FALCON_HOME/logs/tor.log

# Security settings
CookieAuthentication 1
CookieAuthFile $FALCON_HOME/data/tor/control_auth_cookie
AvoidDiskWrites 0
SafeLogging 1
HardwareAccel 0

# Circuit settings
CircuitBuildTimeout 60
LearnCircuitBuildTimeout 0
MaxCircuitDirtiness 600
NewCircuitPeriod 30
MaxClientCircuitsPending 16

# Entry guards
NumEntryGuards 3
UseEntryGuards 1

# Client settings
ClientOnly 1
ExitPolicy reject *:*

# DNS settings
DNSPort 5353
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10

# Bandwidth settings (Cloud Shell friendly)
BandwidthRate 1024 KB
BandwidthBurst 2048 KB
MaxMemInQueues 512 MB
EOF
    
    # Create data directory with proper permissions
    mkdir -p "$FALCON_HOME/data/tor"
    chmod 700 "$FALCON_HOME/data/tor"
    
    echo -e "${GREEN}[OK] Tor configured for Cloud Shell${NC}"
}

# Start Tor service
start_tor() {
    echo -e "${BLUE}[INFO] Starting Tor service...${NC}"
    
    # Kill any existing Tor processes
    pkill -f "tor -f $TOR_CONFIG" 2>/dev/null || true
    sleep 2
    
    # Start Tor in background
    tor -f "$TOR_CONFIG" &
    local tor_pid=$!
    
    # Save PID for cleanup
    echo $tor_pid > "$FALCON_HOME/data/tor.pid"
    
    # Wait for Tor to establish circuits
    echo -e "${YELLOW}[INFO] Waiting for Tor to establish circuits...${NC}"
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if netstat -tlnp 2>/dev/null | grep -q ":9050.*LISTEN"; then
            # Test Tor connection
            if timeout 10 curl -s --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip >/dev/null 2>&1; then
                echo -e "${GREEN}[OK] Tor service is running and circuits established${NC}"
                return 0
            fi
        fi
        
        attempts=$((attempts + 1))
        echo -e "${YELLOW}[INFO] Attempt $attempts/$max_attempts - Waiting for Tor...${NC}"
        sleep 3
    done
    
    # If we get here, Tor failed to start properly
    echo -e "${RED}[ERROR] Failed to start Tor service${NC}"
    echo -e "${YELLOW}[DEBUG] Checking Tor logs...${NC}"
    if [ -f "$FALCON_HOME/logs/tor.log" ]; then
        tail -20 "$FALCON_HOME/logs/tor.log"
    fi
    
    return 1
}

# Configure proxychains
setup_proxychains() {
    echo -e "${BLUE}[INFO] Configuring proxychains...${NC}"
    
    # Create proxychains config
    cat << EOF > "$PROXY_CONFIG"
# Proxychains configuration for Falcon Guard Cloud Shell
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0

[ProxyList]
socks5 127.0.0.1 9050
EOF
    
    echo -e "${GREEN}[OK] Proxychains configured${NC}"
}

# Create secure browsing environment
create_browser_env() {
    echo -e "${BLUE}[INFO] Creating secure browsing environment...${NC}"
    
    # Create Firefox profile directory
    mkdir -p "$FIREFOX_PROFILE"
    
    # Create user.js for security settings
    cat << EOF > "$FIREFOX_PROFILE/user.js"
// Falcon Guard Firefox Security Configuration for Cloud Shell
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "");
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.sendRefererHeader", 0);
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("media.peerconnection.enabled", false);
user_pref("geo.enabled", false);
user_pref("beacon.enabled", false);
user_pref("browser.send_pings", false);
user_pref("dom.battery.enabled", false);
user_pref("device.sensors.enabled", false);
user_pref("webgl.disabled", true);
user_pref("javascript.enabled", true);
user_pref("privacy.firstparty.isolate", true);
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("dom.storage.enabled", false);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", false);
user_pref("browser.cache.offline.enable", false);
user_pref("network.cookie.cookieBehavior", 1);
user_pref("security.tls.version.min", 3);
user_pref("browser.download.dir", "$FALCON_HOME/downloads");
user_pref("browser.download.folderList", 2);
EOF
    
    # Create downloads directory
    mkdir -p "$FALCON_HOME/downloads"
    
    echo -e "${GREEN}[OK] Secure browsing environment created${NC}"
}

# Test anonymity
test_anonymity() {
    echo -e "${BLUE}[INFO] Testing anonymity...${NC}"
    
    # Test direct connection first
    echo -e "${YELLOW}[INFO] Testing direct connection...${NC}"
    local direct_ip=$(timeout 10 curl -s https://httpbin.org/ip 2>/dev/null | grep -o '"origin":"[^"]*' | cut -d'"' -f4 2>/dev/null)
    
    if [ -n "$direct_ip" ]; then
        echo -e "${CYAN}[INFO] Direct IP: $direct_ip${NC}"
    else
        echo -e "${YELLOW}[WARNING] Could not determine direct IP${NC}"
    fi
    
    # Test Tor connection
    echo -e "${YELLOW}[INFO] Testing Tor connection...${NC}"
    local tor_check=$(timeout 15 curl -s --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null)
    
    if echo "$tor_check" | grep -q '"IsTor":true'; then
        echo -e "${GREEN}[OK] Tor connection is working${NC}"
        
        # Get Tor IP
        local tor_ip=$(echo "$tor_check" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo -e "${CYAN}[INFO] Tor IP: $tor_ip${NC}"
        
        # Get location info
        local location=$(timeout 10 curl -s --socks5 127.0.0.1:9050 "https://ipapi.co/$tor_ip/country_name" 2>/dev/null)
        if [ -n "$location" ]; then
            echo -e "${CYAN}[INFO] Apparent location: $location${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}[ERROR] Tor connection failed${NC}"
        return 1
    fi
}

# Launch secure browser
launch_browser() {
    echo -e "${BLUE}[INFO] Launching secure browser...${NC}"
    
    # Check if we're in Cloud Shell web environment
    if [ -n "$DEVSHELL_PROJECT_ID" ]; then
        echo -e "${YELLOW}[INFO] In Cloud Shell - browser will open in web preview${NC}"
        echo -e "${CYAN}[INFO] Use 'Web Preview' feature to access browser${NC}"
    fi
    
    # Kill any existing Firefox instances
    pkill firefox 2>/dev/null || true
    sleep 2
    
    # Launch Firefox with secure profile
    export DISPLAY=:0
    firefox --profile "$FIREFOX_PROFILE" --private-window --no-remote &
    
    echo -e "${GREEN}[OK] Secure browser launched${NC}"
    echo -e "${CYAN}[INFO] Firefox is configured to use Tor proxy${NC}"
}

# Create convenience scripts
create_scripts() {
    echo -e "${BLUE}[INFO] Creating convenience scripts...${NC}"
    
    # Create Tor restart script
    cat << EOF > "$FALCON_HOME/bin/restart-tor.sh"
#!/bin/bash
pkill -f "tor -f $TOR_CONFIG" 2>/dev/null || true
sleep 2
tor -f "$TOR_CONFIG" &
echo "Tor restarted"
EOF
    
    # Create proxy test script
    cat << EOF > "$FALCON_HOME/bin/test-proxy.sh"
#!/bin/bash
echo "Testing proxy connection..."
proxychains -f "$PROXY_CONFIG" curl -s https://check.torproject.org/api/ip
EOF
    
    # Create new identity script
    cat << EOF > "$FALCON_HOME/bin/new-identity.sh"
#!/bin/bash
echo "Getting new Tor identity..."
if [ -f "$FALCON_HOME/data/tor.pid" ]; then
    kill -HUP \$(cat "$FALCON_HOME/data/tor.pid") 2>/dev/null || true
    echo "New identity requested"
else
    echo "Tor not running"
fi
EOF
    
    # Make scripts executable
    chmod +x "$FALCON_HOME/bin/"*.sh
    
    echo -e "${GREEN}[OK] Convenience scripts created${NC}"
}

# Show usage information
show_usage() {
    echo -e "${CYAN}[USAGE] Falcon Guard Cloud Shell Commands:${NC}"
    echo -e "${YELLOW}Direct commands:${NC}"
    echo -e "  proxychains -f $PROXY_CONFIG curl https://check.torproject.org/api/ip"
    echo -e "  proxychains -f $PROXY_CONFIG wget https://example.com"
    echo -e "  proxychains -f $PROXY_CONFIG lynx https://example.com"
    echo
    echo -e "${YELLOW}Convenience scripts:${NC}"
    echo -e "  $FALCON_HOME/bin/restart-tor.sh    - Restart Tor service"
    echo -e "  $FALCON_HOME/bin/test-proxy.sh     - Test proxy connection"
    echo -e "  $FALCON_HOME/bin/new-identity.sh   - Request new Tor identity"
    echo
    echo -e "${YELLOW}Log files:${NC}"
    echo -e "  $FALCON_HOME/logs/tor.log          - Tor service logs"
    echo
}

# Cleanup function
cleanup() {
    echo -e "${BLUE}[INFO] Cleaning up...${NC}"
    
    # Stop Tor service
    if [ -f "$FALCON_HOME/data/tor.pid" ]; then
        local tor_pid=$(cat "$FALCON_HOME/data/tor.pid")
        kill $tor_pid 2>/dev/null || true
        rm -f "$FALCON_HOME/data/tor.pid"
    fi
    
    # Kill any remaining processes
    pkill -f "tor -f $TOR_CONFIG" 2>/dev/null || true
    pkill firefox 2>/dev/null || true
    
    echo -e "${GREEN}[OK] Cleanup completed${NC}"
}

# Status check
check_status() {
    echo -e "${BLUE}[INFO] Checking Falcon Guard status...${NC}"
    
    # Check Tor process
    if pgrep -f "tor -f $TOR_CONFIG" > /dev/null; then
        echo -e "${GREEN}[OK] Tor service is running${NC}"
        
        # Check if port is listening
        if netstat -tlnp 2>/dev/null | grep -q ":9050.*LISTEN"; then
            echo -e "${GREEN}[OK] Tor SOCKS proxy is listening on port 9050${NC}"
        else
            echo -e "${RED}[ERROR] Tor SOCKS proxy is not listening${NC}"
        fi
    else
        echo -e "${RED}[ERROR] Tor service is not running${NC}"
    fi
    
    # Check Firefox
    if pgrep firefox > /dev/null; then
        echo -e "${GREEN}[OK] Firefox is running${NC}"
    else
        echo -e "${YELLOW}[INFO] Firefox is not running${NC}"
    fi
    
    # Show log tail
    if [ -f "$FALCON_HOME/logs/tor.log" ]; then
        echo -e "${CYAN}[INFO] Recent Tor log entries:${NC}"
        tail -5 "$FALCON_HOME/logs/tor.log"
    fi
}

# Main menu
show_menu() {
    echo -e "${YELLOW}[MENU] Select an option:${NC}"
    echo -e "${CYAN}1) Full Setup and Launch${NC}"
    echo -e "${CYAN}2) Test Anonymity${NC}"
    echo -e "${CYAN}3) Launch Browser Only${NC}"
    echo -e "${CYAN}4) Check Status${NC}"
    echo -e "${CYAN}5) Show Usage Information${NC}"
    echo -e "${CYAN}6) Restart Tor${NC}"
    echo -e "${CYAN}7) Cleanup and Exit${NC}"
    echo -e "${CYAN}8) Exit${NC}"
    echo
    read -p "Enter your choice [1-8]: " choice
}

# Main function
main() {
    show_banner
    check_cloud_shell
    
    # Set up trap for cleanup on exit
    trap cleanup EXIT
    
    while true; do
        show_menu
        
        case $choice in
            1)
                echo -e "${GREEN}[INFO] Starting full setup...${NC}"
                create_directories
                install_packages
                configure_tor
                start_tor
                if [ $? -eq 0 ]; then
                    setup_proxychains
                    create_browser_env
                    create_scripts
                    test_anonymity
                    launch_browser
                    show_usage
                    echo -e "${GREEN}[SUCCESS] Falcon Guard V.1 Cloud Shell setup completed!${NC}"
                else
                    echo -e "${RED}[ERROR] Setup failed. Check the logs above.${NC}"
                fi
                echo -e "${YELLOW}[INFO] Press Enter to continue or Ctrl+C to exit${NC}"
                read
                ;;
            2)
                test_anonymity
                echo -e "${YELLOW}[INFO] Press Enter to continue${NC}"
                read
                ;;
            3)
                launch_browser
                echo -e "${YELLOW}[INFO] Press Enter to continue${NC}"
                read
                ;;
            4)
                check_status
                echo -e "${YELLOW}[INFO] Press Enter to continue${NC}"
                read
                ;;
            5)
                show_usage
                echo -e "${YELLOW}[INFO] Press Enter to continue${NC}"
                read
                ;;
            6)
                echo -e "${BLUE}[INFO] Restarting Tor...${NC}"
                start_tor
                echo -e "${YELLOW}[INFO] Press Enter to continue${NC}"
                read
                ;;
            7)
                cleanup
                echo -e "${GREEN}[INFO] Cleanup completed. Exiting...${NC}"
                exit 0
                ;;
            8)
                echo -e "${GREEN}[INFO] Exiting Falcon Guard V.1${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Invalid option. Please choose 1-8${NC}"
                ;;
        esac
    done
}

# Run main function
main "$@"
