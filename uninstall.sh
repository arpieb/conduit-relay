#!/bin/bash
# Conduit Relay + Dashboard Uninstaller
# Handles both native (systemd) and Docker installations
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Conduit Uninstaller${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo)${NC}"
  exit 1
fi

# Detect what's installed
NATIVE_RELAY=false
NATIVE_DASHBOARD=false
DOCKER_CONTAINERS=false

[ -f /etc/systemd/system/conduit.service ] || [ -f /usr/local/bin/conduit ] && NATIVE_RELAY=true
[ -f /etc/systemd/system/conduit-dashboard.service ] || [ -d /opt/conduit-dashboard ] && NATIVE_DASHBOARD=true
docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE '^conduit(-relay|-dashboard|-caddy)?$' && DOCKER_CONTAINERS=true

echo "This will remove:"
$NATIVE_RELAY && echo "  - Conduit relay (native/systemd)"
$NATIVE_DASHBOARD && echo "  - Conduit dashboard (native/systemd)"
$DOCKER_CONTAINERS && echo "  - Docker containers (conduit-relay, conduit-dashboard, conduit-caddy)"
$DOCKER_CONTAINERS && echo "  - Docker volumes (conduit-relay-data, conduit-dashboard-data, etc.)"
[ -d /opt/conduit ] && echo "  - Docker compose files (/opt/conduit)"
echo ""

if ! $NATIVE_RELAY && ! $NATIVE_DASHBOARD && ! $DOCKER_CONTAINERS; then
  echo "Nothing to uninstall."
  exit 0
fi

read -r -p "Continue? [y/N]: " CONFIRM < /dev/tty
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""

# ════════════════════════════════════════════════════════════════
# Docker cleanup
# ════════════════════════════════════════════════════════════════
if $DOCKER_CONTAINERS; then
  echo "Stopping Docker containers..."

  # Stop and remove containers
  for container in conduit-relay conduit-dashboard conduit-caddy conduit; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
      echo "  Removing $container..."
      docker stop "$container" 2>/dev/null || true
      docker rm "$container" 2>/dev/null || true
    fi
  done

  # Remove volumes
  echo "Removing Docker volumes..."
  for volume in conduit-relay-data conduit-dashboard-data conduit-caddy-data conduit-caddy-config conduit-data; do
    if docker volume ls -q 2>/dev/null | grep -q "^${volume}$"; then
      echo "  Removing volume $volume..."
      docker volume rm "$volume" 2>/dev/null || true
    fi
  done
fi

# Remove Docker compose directory
if [ -d /opt/conduit ]; then
  echo "Removing /opt/conduit..."
  rm -rf /opt/conduit
fi

# ════════════════════════════════════════════════════════════════
# Native (systemd) cleanup
# ════════════════════════════════════════════════════════════════

# Stop and remove relay
if systemctl is-active --quiet conduit 2>/dev/null; then
  echo "Stopping conduit relay..."
  systemctl stop conduit
fi
if [ -f /etc/systemd/system/conduit.service ]; then
  echo "Removing conduit service..."
  systemctl disable conduit 2>/dev/null || true
  rm -f /etc/systemd/system/conduit.service
fi
if [ -f /usr/local/bin/conduit ]; then
  echo "Removing conduit binary..."
  rm -f /usr/local/bin/conduit
fi
if [ -d /var/lib/conduit ]; then
  echo "Removing conduit data..."
  rm -rf /var/lib/conduit
fi
if getent passwd conduit >/dev/null 2>&1; then
  echo "Removing conduit user..."
  userdel conduit 2>/dev/null || true
fi

# Stop and remove dashboard
if systemctl is-active --quiet conduit-dashboard 2>/dev/null; then
  echo "Stopping dashboard..."
  systemctl stop conduit-dashboard
fi
if [ -f /etc/systemd/system/conduit-dashboard.service ]; then
  echo "Removing dashboard service..."
  systemctl disable conduit-dashboard 2>/dev/null || true
  rm -f /etc/systemd/system/conduit-dashboard.service
fi
if [ -d /opt/conduit-dashboard ]; then
  echo "Removing dashboard files..."
  rm -rf /opt/conduit-dashboard
fi

# Remove monitoring user sudoers
if [ -f /etc/sudoers.d/conduit-dashboard ]; then
  echo "Removing sudoers config..."
  rm -f /etc/sudoers.d/conduit-dashboard
fi

# Reload systemd
systemctl daemon-reload 2>/dev/null || true

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
