#!/bin/bash

# Preveri, če je geslo podano
if [ -z "$1" ]; then
  echo "Uporaba: $0 <geslo_za_HMAC>"
  exit 1
fi

SECRET_KEY="$1"

# =========================
# Statični podatki
# =========================
cpu_vendor="SiFive"
cpu_arch=$(uname -m)
cpu_model=$(awk -F: '/isa/ {print $2}' /proc/cpuinfo | paste -sd, -)
cpu_hartid=$(grep hart /proc/cpuinfo | awk '{print $3}' | head -n1)
mac_eth0=$(ip link show eth0 2>/dev/null | awk '/ether/ {print $2}' | head -n1)
mac_usb0=$(ip link show usb0 2>/dev/null | awk '/ether/ {print $2}' | head -n1)
emmc_cid=$(cat /sys/block/mmcblk0/device/cid 2>/dev/null || echo "N/A")
eeprom=$(sudo head -c 24 /sys/bus/nvmem/devices/1-00501/nvmem 2>/dev/null || echo "N/A")
machine_id=$(cat /etc/machine-id 2>/dev/null || echo "N/A")
dt_model=$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null || echo "N/A")
dt_compatible=$(tr -d '\0' </sys/firmware/devicetree/base/compatible 2>/dev/null || echo "N/A")

# GPIO
gpio_value=""
for line in {0..13}; do
    value=$(gpioget gpiochip0 $line 2>/dev/null || echo "N/A")
    gpio_value+="$line:$value,"
done
gpio_value=${gpio_value%,}

# Dodatni podatki za hash
working_state=$(cat DATA/working_state.txt 2>/dev/null || echo "N/A")
current_job=$(cat DATA/current_job.txt 2>/dev/null || echo "N/A")
packages_hash=$(if command -v dpkg >/dev/null; then dpkg -l | sha256sum | awk '{print $1}'; elif command -v rpm >/dev/null; then rpm -qa | sha256sum | awk '{print $1}'; else echo "N/A"; fi)

# =========================
# Dinamični podatki
# =========================
loadavg=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
user_processes=$(ps -e | wc -l)
avail_ram=$(free -m | awk '/Mem:/ {print $7}')   # MB

# Disk
disk_free=$(df / | awk 'NR==2 {print $4}')       # KB
disk_free_mb=$((disk_free / 1024))
if [ -f /sys/block/mmcblk0/stat ]; then
    read r_blocks w_blocks < <(awk '{print $1, $5}' /sys/block/mmcblk0/stat)
    disk_io="${r_blocks}:${w_blocks}"
else
    disk_io="N/A"
fi

# Omrežje
rx_bytes=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null || echo "N/A")
tx_bytes=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null || echo "N/A")

# Top 5 procesov (PID:Comm:%CPU:%MEM)
top5_processes=$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n6 | tail -n5 | awk '{print $2":"$3":"$4}' | tr '\n' ',' | sed 's/,$//')

# I2C naprave
if command -v i2cdetect >/dev/null; then
    i2c_devices=$(i2cdetect -y 1 2>/dev/null \
        | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' \
        | tr -d '\n')  # odstranimo dejanske prelome vrstic
else
    i2c_devices="N/A"
fi

# =========================
# Združimo vse podatke za hash
# =========================
all_data="${cpu_vendor}_${cpu_arch}_${cpu_model}_${cpu_hartid}_${emmc_cid}_${mac_eth0}_${mac_usb0}_${eeprom}_${machine_id}_${dt_model}_${dt_compatible}_${gpio_value}_${working_state}_${current_job}_${packages_hash}_${loadavg}_${user_processes}_${avail_ram}_${disk_free_mb}_${disk_io}_${rx_bytes}_${tx_bytes}_${top5_processes}_${i2c_devices}"

# =========================
# 1. Fuzzy hash z Python TLSH
# =========================
if python3 -c "import tlsh" 2>/dev/null; then
    fuzzy_hash=$(python3 -c "import tlsh; print(tlsh.hash(b'''$all_data'''))")
    #echo "TLSH fuzzy hash vseh podatkov: $fuzzy_hash"
    echo $fuzzy_hash
else
    echo "py-tlsh ni nameščen, uporabljam SHA-256 kot nadomestilo"
    fuzzy_hash=$(echo -n "$all_data" | sha256sum | awk '{print $1}')
    echo "SHA-256 vseh podatkov (nadomestno): $fuzzy_hash"
fi

# =========================
# 2. HMAC SHA-256
# =========================
hmac=$(echo -n "$all_data" | openssl dgst -sha256 -hmac "$SECRET_KEY" | awk '{print $2}')
#echo "HMAC SHA-256 vseh podatkov s ključem '$SECRET_KEY': $hmac"

# =========================
# 3. JSON + Base64
# =========================
json=$(cat <<EOF
{
  "fuzzy_hash":"$fuzzy_hash",
  "hmac":"$hmac"
}
EOF
)

json_base64=$(echo -n "$json" | base64 -w0)
#echo "JSON + Base64: $json_base64"

