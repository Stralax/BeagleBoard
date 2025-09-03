#!/bin/bash

# Preveri, če je geslo podano
if [ -z "$1" ]; then
  #echo "Uporaba: $0 <geslo_za_HMAC>"
  exit 1
fi

SECRET_KEY="$1"

# --- Statične spremenljivke naprave ---
cpu_vendor="SiFive"
cpu_arch=$(uname -m)
cpu_model=$(awk -F: '/isa/ {print $2}' /proc/cpuinfo | paste -sd, -)
cpu_hartid=$(grep hart /proc/cpuinfo | awk '{print $3}' | head -n1)
mac_eth0=$(ip link show eth0 | awk '/ether/ {print $2; exit}')
mac_usb0=$(ip link show usb0 2>/dev/null | awk '/ether/ {print $2; exit}')
emmc_cid=$(cat /sys/block/mmcblk0/device/cid 2>/dev/null)
fpga_id=$(sudo head -c 24 /sys/bus/nvmem/devices/1-00501/nvmem 2>/dev/null)
eeprom="$fpga_id"
machine_id=$(cat /etc/machine-id 2>/dev/null)

dt_model=$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null)
dt_compatible=$(tr -d '\0' </sys/firmware/devicetree/base/compatible 2>/dev/null)

# --- GPIO ---
gpio_value=""
for line in {0..13}; do
    value=$(gpioget gpiochip0 $line 2>/dev/null)
    gpio_value+="$line:$value,"
done
gpio_value=${gpio_value%,}

# --- 1. SHA-256 hash statičnih spremenljivk ---
static_data="${cpu_arch}_${cpu_model}_${emmc_cid}_${mac_eth0}_${mac_usb0}_${eeprom}_${machine_id}_${dt_model}_${dt_compatible}_${gpio_value}"
static_hash=$(echo -n "$static_data" | sha256sum | awk '{print $1}')
#echo "SHA-256 statičnih podatkov: $static_hash"
echo $static_hash

# --- 2. HMAC SHA-256 s ključem ---
hmac=$(echo -n "$static_data" | openssl dgst -sha256 -hmac "$SECRET_KEY" | awk '{print $2}')
#echo "HMAC SHA-256 s ključem '$SECRET_KEY': $hmac"

# --- 3. JSON + Base64 ---
json=$(cat <<EOF
{
  "static_hash":"$static_hash",
  "hmac":"$hmac"
}
EOF
)

json_base64=$(echo -n "$json" | base64 -w0)
#echo "JSON + Base64: $json_base64"

