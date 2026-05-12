#!/bin/bash

# ============================================
#   MendyFi Auto Installer + Service Setup
#   github.com/mendylivium/mendyfi
# ============================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Config ---
BASE_URL="https://github.com/mendylivium/mendyfi/raw/master/binaries"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="mendyfi"
SERVICE_NAME="mendyfi"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
WORK_DIR="/opt/mendyfi"       # This is where .env, *.db, and generated files will be stored
RUN_USER="root"               # Change this if you have a dedicated user

# --- Auto-detect Architecture ---
detect_arch() {
    local machine
    machine=$(uname -m)

    case "$machine" in
        x86_64)
            ARCH_SUFFIX="amd64"
            ;;
        aarch64 | arm64)
            ARCH_SUFFIX="arm64"
            ;;
        armv7l | armv7)
            ARCH_SUFFIX="armv7"
            ;;
        armv6l)
            warn "Detected armv6l — attempting to use the armv7 binary (may not work)."
            ARCH_SUFFIX="armv7"
            ;;
        i386 | i686)
            ARCH_SUFFIX="386"
            ;;
        *)
            error "Unknown architecture: $machine. Please install manually."
            ;;
    esac

    BINARY_URL="${BASE_URL}/mendyfi-linux-${ARCH_SUFFIX}"
    info "Detected architecture : ${machine}  →  binary: mendyfi-linux-${ARCH_SUFFIX}"
}

# ============================================
# Helper functions
# ============================================

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo bash $0"
    fi
}

check_dependencies() {
    info "Checking dependencies..."
    for cmd in curl wget systemctl openssl; do
        if ! command -v $cmd &>/dev/null; then
            warn "$cmd not found, attempting to install..."
            apt-get install -y $cmd 2>/dev/null || yum install -y $cmd 2>/dev/null || \
                error "Failed to install $cmd. Please install it manually."
        fi
    done
    success "Dependencies OK."
}

collect_server_ips() {
    local public_ip lan_ips

    public_ip=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)

    if command -v ip >/dev/null 2>&1; then
        lan_ips=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    else
        lan_ips=$(hostname -I 2>/dev/null | tr ' ' '\n')
    fi

    SERVER_IPS=()

    if [[ -n "$public_ip" ]]; then
        SERVER_IPS+=("$public_ip")
    fi

    while IFS= read -r ip_addr; do
        [[ -z "$ip_addr" ]] && continue

        local exists=false
        for existing in "${SERVER_IPS[@]}"; do
            if [[ "$existing" == "$ip_addr" ]]; then
                exists=true
                break
            fi
        done

        if [[ "$exists" == false ]]; then
            SERVER_IPS+=("$ip_addr")
        fi
    done <<< "$lan_ips"
}

generate_tls_certificate() {
    info "Generating TLS certificate (CN + SAN with public/LAN IPs)..."

    collect_server_ips

    if [[ ${#SERVER_IPS[@]} -eq 0 ]]; then
        warn "No IP address detected. Skipping TLS certificate generation."
        return
    fi

    local cn_ip san_entries cert_conf key_file cert_file
    cn_ip="${SERVER_IPS[0]}"
    key_file="${WORK_DIR}/key.pem"
    cert_file="${WORK_DIR}/cert.pem"
    cert_conf=$(mktemp)

    san_entries=""
    for ip_addr in "${SERVER_IPS[@]}"; do
        if [[ -z "$san_entries" ]]; then
            san_entries="IP:${ip_addr}"
        else
            san_entries=",${san_entries},IP:${ip_addr}"
            san_entries="${san_entries#,}"
        fi
    done

    cat > "$cert_conf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
CN = ${cn_ip}

[v3_req]
subjectAltName = ${san_entries}
EOF

    if openssl req -x509 -newkey rsa:2048 -keyout "$key_file" -out "$cert_file" -days 365 -nodes -subj "/CN=${cn_ip}" -extensions v3_req -config "$cert_conf" >/dev/null 2>&1; then
        chmod 600 "$key_file"
        chmod 644 "$cert_file"
        success "TLS certificate generated: ${cert_file}"
        success "TLS key generated: ${key_file}"
        info "Certificate IPs: ${SERVER_IPS[*]}"
    else
        warn "Failed to generate TLS certificate. You can run OpenSSL manually later."
    fi

    rm -f "$cert_conf"
}

# ============================================
# Step 1: Download binary
# ============================================

setup_workdir() {
    info "Creating working directory: ${WORK_DIR} ..."
    mkdir -p "$WORK_DIR"
    chown -R "${RUN_USER}:${RUN_USER}" "$WORK_DIR"
    chmod 750 "$WORK_DIR"
    success "Working directory OK: ${WORK_DIR}"
    success "All generated files (.env, *.db) will be saved here."
}

download_binary() {
    detect_arch
    info "Downloading MendyFi binary..."

    TMP_FILE=$(mktemp)
    
    if curl -fsSL "$BINARY_URL" -o "$TMP_FILE"; then
        success "Download successful."
    elif wget -q "$BINARY_URL" -O "$TMP_FILE"; then
        success "Download successful (wget)."
    else
        error "Failed to download the binary. Check your internet connection or URL."
    fi

    # Verify file is not empty
    if [[ ! -s "$TMP_FILE" ]]; then
        error "Downloaded file is empty. The URL may be incorrect."
    fi

    # Move to install dir
    mv "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    success "Binary installed at ${INSTALL_DIR}/${BINARY_NAME}"
}

# ============================================
# Step 2: Create systemd service
# ============================================

create_service() {
    info "Creating systemd service..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=MendyFi Service
Documentation=https://github.com/mendylivium/mendyfi
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${WORK_DIR}
ExecStart=${INSTALL_DIR}/${BINARY_NAME}
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mendyfi

# Optional: if mendyfi uses a .env file, uncomment this
# EnvironmentFile=${WORK_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

    success "Service file created: ${SERVICE_FILE}"
}

# ============================================
# Step 3: Enable and start service
# ============================================

enable_service() {
    info "Reloading systemd daemon..."
    systemctl daemon-reload

    info "Enabling ${SERVICE_NAME} service (auto-start on boot)..."
    systemctl enable "$SERVICE_NAME"

    info "Starting ${SERVICE_NAME} service..."
    systemctl start "$SERVICE_NAME"

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "MendyFi service is now RUNNING!"
    else
        warn "Service failed to start. Check the logs:"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager
    fi
}

# ============================================
# Show status
# ============================================

show_status() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}   MendyFi Installation Complete!${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "  Binary   : ${INSTALL_DIR}/${BINARY_NAME}  (linux-${ARCH_SUFFIX})"
    echo -e "  Service  : ${SERVICE_NAME}"
    echo -e "  Work Dir : ${WORK_DIR}  ← .env, *.db, and generated files are stored here"
    echo ""
    echo -e "  Useful commands:"
    echo -e "  ${YELLOW}systemctl status ${SERVICE_NAME}${NC}     - view status"
    echo -e "  ${YELLOW}systemctl stop ${SERVICE_NAME}${NC}       - stop service"
    echo -e "  ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}    - restart service"
    echo -e "  ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}     - monitor logs"
    echo ""
}

# ============================================
# Uninstall option
# ============================================

uninstall() {
    warn "Uninstalling MendyFi..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    rm -f "${INSTALL_DIR}/${BINARY_NAME}"
    systemctl daemon-reload

    echo ""
    read -rp "$(echo -e "${YELLOW}[WARN]${NC} Also delete the work directory and all data in ${WORK_DIR}? [y/N]: ")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$WORK_DIR"
        success "Work directory removed."
    else
        warn "Work directory preserved: ${WORK_DIR}"
    fi
    success "MendyFi has been uninstalled."
    exit 0
}

# ============================================
# Main
# ============================================

case "${1:-install}" in
    install)
        check_root
        check_dependencies
        setup_workdir
        generate_tls_certificate
        download_binary
        create_service
        enable_service
        show_status
        ;;
    uninstall)
        check_root
        uninstall
        ;;
    *)
        echo "Usage: sudo bash $0 [install|uninstall]"
        exit 1
        ;;
esac