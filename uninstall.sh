#!/bin/bash
set -e

echo "Stopping service..."
systemctl stop conduit 2>/dev/null || true
systemctl disable conduit 2>/dev/null || true

echo "Removing files..."
rm -f /etc/systemd/system/conduit.service
rm -f /usr/local/bin/conduit
rm -rf /var/lib/conduit

systemctl daemon-reload

echo "Done."
