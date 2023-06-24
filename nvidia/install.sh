#!/usr/bin/env bash
# basic build and install script for nv_fan_control
# run as root

set -euo pipefail

fan_controller=${fan_controller:-/sys/class/hwmon/hwmon4/pwm3}
service_file=/etc/systemd/system/nv_fan_control.service

# Check that golang is installed
if ! [ -x "$(command -v go)" ]; then
  echo 'Error: golang is not installed.' >&2
  exit 1
fi

go build nv_fan_control.go -o /usr/local/sbin/nv_fan_control
chmod +x /usr/local/sbin/nv_fan_control

cp nv_fan_control.service "$service_file"

read -p "Enter the path to the fan device [/sys/class/hwmon/hwmon4/pwm3]: " fan_controller

# Check that the fan controller exists, if it does update the service file
if [ -d "$fan_controller" ]; then
  echo "Fan controller found at $fan_controller"
  sed -i "s|/sys/class/hwmon/hwmon4/pwm3|$fan_controller|g" "$service_file"
else
  echo "Fan controller not found at $fan_controller"
  exit 1
fi

systemctl daemon-reload
systemctl enable nv_fan_control.service --now

# check that nv_fan_control is running
sleep 1
if ! [ -x "$(command -v nv_fan_control)" ]; then
  echo 'Error: nv_fan_control is not running!' >&2
  exit 1
fi

echo "nv_fan_control installed successfully"
