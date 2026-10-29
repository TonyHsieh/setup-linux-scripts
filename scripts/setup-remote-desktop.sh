#!/usr/bin/env bash
# ==============================================================================
# setup-remote-desktop.sh
# Multi-Platform Remote Desktop Setup & Management (RDP / Screen Sharing).
# Supports Arch/CachyOS (KDE Plasma 6 Wayland via krdp), WSL2, and macOS.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/local-services/.env"
if [ ! -f "$ENV_FILE" ] && [ -f "${HOME}/.local/share/local-services/.env" ]; then
  ENV_FILE="${HOME}/.local/share/local-services/.env"
fi

ACTION="up"
for arg in "$@"; do
  case "$arg" in
    --status)
      ACTION="status"
      ;;
    --down)
      ACTION="down"
      ;;
    --up)
      ACTION="up"
      ;;
    -h|--help)
      echo "Usage: $0 [--up | --status | --down]"
      echo ""
      echo "Commands:"
      echo "  --up       Install, configure, and enable Remote Desktop on this host (default)"
      echo "  --status   Inspect Remote Desktop listening ports, services, and Tailnet addresses"
      echo "  --down     Stop and disable Remote Desktop on this host"
      exit 0
      ;;
  esac
done

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_platform() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "darwin"
  elif grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    echo "wsl"
  elif [ -f /etc/os-release ] && grep -qiE "cachyos|arch" /etc/os-release; then
    echo "arch"
  elif [ -f /etc/os-release ] && grep -qiE "ubuntu|debian" /etc/os-release; then
    echo "debian"
  else
    echo "linux"
  fi
}

PLATFORM="$(detect_platform)"

# Determine Machine Identifier
TARGET_MACHINE=""
if [ -f "$ENV_FILE" ]; then
  TARGET_MACHINE="$(grep '^TS_MACHINE_ID=' "$ENV_FILE" | cut -d'=' -f2 | tr -d ' "')"
fi
if [ -z "$TARGET_MACHINE" ]; then
  HOST_STRING="$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "")"
  if [[ "$HOST_STRING" =~ [Ee][Nn][Vv][Yy] ]]; then
    TARGET_MACHINE="envy"
  elif [[ "$HOST_STRING" =~ [Aa][Ss][Uu][Ss] ]]; then
    TARGET_MACHINE="asus"
  elif [[ "$HOST_STRING" =~ [Aa][Rr][Cc][Hh] ]]; then
    TARGET_MACHINE="arch"
  else
    TARGET_MACHINE="$(hostname -s 2>/dev/null | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  fi
  TARGET_MACHINE="${TARGET_MACHINE:-laptop}"
fi

# ------------------------------------------------------------------------------
# Action: Down
# ------------------------------------------------------------------------------
if [ "$ACTION" = "down" ]; then
  echo "==> Stopping Remote Desktop server..."
  case "$PLATFORM" in
    arch|debian|linux)
      systemctl --user stop app-org.kde.krdpserver.service 2>/dev/null || true
      systemctl --user stop plasma-krdp.service 2>/dev/null || true
      systemctl --user stop krdpserver.service 2>/dev/null || true
      echo "✓ Stopped KDE KRDP user services."
      ;;
    darwin)
      run_sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
      echo "✓ Stopped macOS Screen Sharing."
      ;;
    wsl)
      echo "ℹ️  WSL remote desktop relies on Windows host Remote Desktop or WSLg."
      ;;
  esac
  exit 0
fi

# ------------------------------------------------------------------------------
# Action: Status
# ------------------------------------------------------------------------------
if [ "$ACTION" = "status" ]; then
  echo "======================================================================"
  echo "🔍 Remote Desktop Status (${PLATFORM})"
  echo "======================================================================"
  PORT_3389_ACTIVE=false
  PORT_5900_ACTIVE=false

  if command -v ss >/dev/null 2>&1; then
    if ss -tuln 2>/dev/null | grep -q ":3389 "; then PORT_3389_ACTIVE=true; fi
    if ss -tuln 2>/dev/null | grep -q ":5900 "; then PORT_5900_ACTIVE=true; fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln 2>/dev/null | grep -q ":3389 "; then PORT_3389_ACTIVE=true; fi
    if netstat -tuln 2>/dev/null | grep -q ":5900 "; then PORT_5900_ACTIVE=true; fi
  fi

  TS_IP="$(tailscale ip -4 2>/dev/null || echo "Tailscale IP pending")"
  TS_STATUS="$(tailscale status --json 2>/dev/null || true)"
  MAGIC_DNS="$(echo "$TS_STATUS" | jq -r '.Self.DNSName // empty' 2>/dev/null || true)"
  MAGIC_DNS="${MAGIC_DNS%.}"

  case "$PLATFORM" in
    arch|debian|linux)
      echo "  Engine:             KDE KRDP (Wayland Native RDP Server)"
      if [ "$PORT_3389_ACTIVE" = true ]; then
        echo "  RDP Port (3389):    ✅ LISTENING"
      else
        echo "  RDP Port (3389):    ⚠️ NOT LISTENING (Run '$0 --up' to start)"
      fi
      ;;
    darwin)
      echo "  Engine:             macOS Screen Sharing (Apple VNC)"
      if [ "$PORT_5900_ACTIVE" = true ]; then
        echo "  VNC Port (5900):    ✅ LISTENING"
      else
        echo "  VNC Port (5900):    ⚠️ NOT LISTENING (Run '$0 --up' to start)"
      fi
      ;;
    wsl)
      echo "  Engine:             WSLg / Windows Host Remote Desktop"
      echo "  RDP Port (3389):    $(if [ "$PORT_3389_ACTIVE" = true ]; then echo "✅ LISTENING"; else echo "ℹ️ Check Windows Host RDP"; fi)"
      ;;
  esac

  echo "  Tailscale Host:     ${TARGET_MACHINE}"
  echo "  Tailscale IPv4:     ${TS_IP}"
  [ -n "$MAGIC_DNS" ] && echo "  MagicDNS FQDN:      ${MAGIC_DNS}"
  echo ""
  echo "📱 Native Remote Desktop Clients (iPhone / iPad / Mac / Windows / Linux):"
  if [ "$PLATFORM" = "darwin" ]; then
    echo "  • macOS Screen Sharing / VNC:  vnc://${TARGET_MACHINE}:5900"
    [ -n "$MAGIC_DNS" ] && echo "  • FQDN VNC URL:                vnc://${MAGIC_DNS}:5900"
  else
    echo "  • Microsoft Remote Desktop:    ${TARGET_MACHINE}:3389"
    [ -n "$MAGIC_DNS" ] && echo "  • FQDN RDP Target:             ${MAGIC_DNS}:3389"
    echo "  • Remmina / FreeRDP (Linux):   rdp://${TARGET_MACHINE}:3389"
  fi
  echo ""
  echo "🌐 Dedicated Web Browser Gateway (Port 443 TLS + Port 80 301 Redirect):"
  if [ -n "$MAGIC_DNS" ]; then
    TAILNET_SUFFIX="$(echo "$TS_STATUS" | jq -r '.MagicDNSSuffix // empty' 2>/dev/null || true)"
    echo "  • URL:                         https://desktop-${TARGET_MACHINE}.${TAILNET_SUFFIX}"
  else
    echo "  • URL:                         https://desktop-${TARGET_MACHINE}.<your-tailnet>.ts.net"
  fi
  echo "======================================================================"
  exit 0
fi

# ------------------------------------------------------------------------------
# Action: Up (Install & Configure Remote Desktop)
# ------------------------------------------------------------------------------
echo "======================================================================"
echo "🚀 Setting up Remote Desktop for ${TARGET_MACHINE} (${PLATFORM})"
echo "======================================================================"

case "$PLATFORM" in
  arch)
    # 1. Install krdp if missing
    if ! pacman -Qi krdp >/dev/null 2>&1; then
      echo "==> Installing krdp (KDE Plasma 6 Wayland RDP server) via pacman..."
      run_sudo pacman -Sy --needed --noconfirm krdp
    fi

    # 2. Authorize via XDG Desktop Portal / Flatpak permission database
    if command -v flatpak >/dev/null 2>&1; then
      echo "==> Configuring XDG portal remote desktop authorization..."
      flatpak permission-set kde-authorized remote-desktop org.kde.krdpserver yes 2>/dev/null || true
    fi

    # 3. Generate self-signed SSL key/cert for encrypted RDP
    KRDP_CERT_DIR="${HOME}/.local/share/krdpserver"
    mkdir -p "${KRDP_CERT_DIR}"
    if [ ! -f "${KRDP_CERT_DIR}/krdp.crt" ] || [ ! -f "${KRDP_CERT_DIR}/krdp.key" ]; then
      echo "==> Generating RDP SSL certificate in ${KRDP_CERT_DIR}..."
      openssl req -nodes -new -x509 \
        -keyout "${KRDP_CERT_DIR}/krdp.key" \
        -out "${KRDP_CERT_DIR}/krdp.crt" \
        -days 3650 \
        -subj "/CN=krdp-${TARGET_MACHINE}" >/dev/null 2>&1
      chmod 600 "${KRDP_CERT_DIR}/krdp.key"
    fi

    # 4. Write configuration in krdpserverrc via kwriteconfig6
    if command -v kwriteconfig6 >/dev/null 2>&1; then
      echo "==> Configuring krdpserverrc..."
      kwriteconfig6 --file krdpserverrc --group General --key Certificate "${KRDP_CERT_DIR}/krdp.crt"
      kwriteconfig6 --file krdpserverrc --group General --key CertificateKey "${KRDP_CERT_DIR}/krdp.key"
      kwriteconfig6 --file krdpserverrc --group General --key GenerateCertificate false
      kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true
    fi

    # 5. Fix system user PAM authentication (NoNewPrivileges=false for unix_chkpwd)
    echo "==> Configuring systemd user override for PAM unix_chkpwd..."
    OVERRIDE_DIR="${HOME}/.config/systemd/user/app-org.kde.krdpserver.service.d"
    mkdir -p "${OVERRIDE_DIR}"
    cat << 'EOF' > "${OVERRIDE_DIR}/override.conf"
[Service]
NoNewPrivileges=false
EOF
    systemctl --user daemon-reload 2>/dev/null || true

    # 6. Enable and start KRDP user systemd service
    echo "==> Starting KDE KRDP service..."
    SERVICE_STARTED=false
    for unit in app-org.kde.krdpserver.service plasma-krdp.service krdpserver.service; do
      if systemctl --user start "$unit" 2>/dev/null; then
        systemctl --user enable "$unit" 2>/dev/null || true
        SERVICE_STARTED=true
        echo "✓ Successfully started user unit: $unit"
        break
      fi
    done

    if [ "$SERVICE_STARTED" = false ]; then
      echo "ℹ️  Could not start KRDP via systemd unit directly."
      echo "👉 Open KDE System Settings ➔ Networking ➔ Remote Desktop and enable 'Remote Desktop'."
    fi
    ;;

  darwin)
    echo "==> Enabling macOS Screen Sharing (VNC port 5900)..."
    run_sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
    run_sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    echo "✓ macOS Screen Sharing enabled."
    echo "👉 Ensure 'Screen Sharing' is toggled ON under System Settings ➔ General ➔ Sharing."
    ;;

  wsl)
    echo "==> WSL2 Remote Desktop Configuration:"
    echo "ℹ️  WSL2 GUI applications run natively via WSLg."
    echo "👉 To remote desktop into Windows host: Enable 'Remote Desktop' in Windows Settings ➔ System ➔ Remote Desktop."
    echo "   Connect via '${TARGET_MACHINE}:3389' using Microsoft Remote Desktop over Tailscale."
    ;;
esac

echo ""
exec "$0" --status
