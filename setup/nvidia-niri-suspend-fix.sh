#!/bin/bash

# https://github.com/0xFMD/hyprland-suspend-fix/tree/main

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "must be run as root. Please use sudo."
    exit 1
fi

# Create the niri-suspend.service systemd service file
cat > /etc/systemd/system/niri-suspend.service << 'EOF'
[Unit]
Description=Pause niri before NVIDIA suspend
Before=systemd-suspend.service
Before=systemd-hibernate.service
Before=nvidia-suspend.service
Before=nvidia-hibernate.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/pkill -STOP -x niri

[Install]
WantedBy=systemd-suspend.service
WantedBy=systemd-hibernate.service
EOF

# Create the niri-resume.service systemd service file
cat > /etc/systemd/system/niri-resume.service << 'EOF'
[Unit]
Description=Resume niri after NVIDIA suspend
After=systemd-suspend.service
After=systemd-hibernate.service
After=nvidia-resume.service

[Service]
Type=oneshot
ExecStart=/usr/bin/pkill -CONT -x niri

[Install]
WantedBy=systemd-suspend.service
WantedBy=systemd-hibernate.service
EOF

# Reload the systemd daemon and enable the newly created services
systemctl daemon-reload
systemctl enable niri-suspend
systemctl enable niri-resume

echo "Installation complete!"
