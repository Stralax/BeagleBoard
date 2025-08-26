#!/bin/bash

# --- Osnovni podatki naprave ---
cpu_vendor="SiFive"
cpu_arch=$(uname -m)
cpu_model=$(awk -F: '/isa/ {print $2}' /proc/cpuinfo | paste -sd, -)
cpu_hartid=$(grep hart /proc/cpuinfo | awk '{print $3}' | head -n1)
mac=$(ip link show | awk '/ether/ {print $2; exit}')
emmc_cid=$(cat /sys/block/mmcblk0/device/cid 2>/dev/null)
kernel=$(uname -r)
kernel_conf_hash=$(if [ -f /proc/config.gz ]; then zcat /proc/config.gz | sha256sum | awk '{print $1}'; else echo "N/A"; fi)
dt_model=$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null)
dt_compatible=$(tr -d '\0' </sys/firmware/devicetree/base/compatible 2>/dev/null)
modules_count=$(lsmod | wc -l)
boot_time=$(awk '{print $1}' /proc/uptime)
packages_hash=$(if command -v dpkg >/dev/null; then dpkg -l | sha256sum | awk '{print $1}'; elif command -v rpm >/dev/null; then rpm -qa | sha256sum | awk '{print $1}'; else echo "N/A"; fi)

working_state=$(cat DATA/working_state.txt)
current_job=$(cat DATA/current_job.txt)


# FPGA ID
fpga_id=$(sudo head -c 24 /sys/bus/nvmem/devices/1-00501/nvmem 2>/dev/null)
eeprom="$fpga_id"

# --- Dodatni dinamični podatki ---
loadavg=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
user_processes=$(ps -e | wc -l)
avail_ram=$(free -m | awk '/Mem:/ {print $7}')   # v MB

# Disk
disk_free=$(df / | awk 'NR==2 {print $4}')   # v KB
disk_free_mb=$((disk_free / 1024))

if [ -f /sys/block/mmcblk0/stat ]; then
    read r_blocks w_blocks < <(awk '{print $1, $5}' /sys/block/mmcblk0/stat)
    disk_io="${r_blocks}:${w_blocks}"
else
    disk_io="N/A"
fi

# Omrežje
rx_bytes=$(cat /sys/class/net/eth0/statistics/rx_bytes 2>/dev/null)
tx_bytes=$(cat /sys/class/net/eth0/statistics/tx_bytes 2>/dev/null)

# Top 5 procesov
top5_processes=$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n6 | tail -n5 | awk '{print $2":"$3":"$4}' | tr '\n' ',' | sed 's/,$//')

# GPIO
gpio_value=""
for line in {0..13}; do
    value=$(gpioget gpiochip0 $line 2>/dev/null)
    gpio_value+="$line:$value,"
done
gpio_value=${gpio_value%,}

# --- I2C naprave ---
if command -v i2cdetect >/dev/null; then
    i2c_devices=$(i2cdetect -y 1 2>/dev/null \
        | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' \
        | tr -d '\n')  # odstranimo dejanske prelome vrstic
else
    i2c_devices="N/A"
fi

# --- Statični hash naprave ---
device_hash=$(echo -n "${cpu_arch}_${cpu_model}_${emmc_cid}_${mac}_${eeprom}" | sha256sum | awk '{print $1}')

# --- Determinističen niz za HMAC (surovi podatki) ---
hmac_input="${cpu_vendor}_${cpu_arch}_${cpu_model}_${cpu_hartid}_${mac}_${emmc_cid}_${kernel}_${kernel_conf_hash}_${dt_model}_${dt_compatible}_${modules_count}_${boot_time}_${packages_hash}_${eeprom}_${loadavg}_${user_processes}_${avail_ram}_${disk_free_mb}_${disk_io}_${rx_bytes}_${tx_bytes}_${top5_processes}_${gpio_value}_${i2c_devices}_${device_hash}_${working_state}_${current_job}"

# --- HMAC podpis (pravilno: base64 od surovih podatkov) ---
secret_key="Snoopy"
dfp_hmac_encoded=$(echo -n "$hmac_input" \
    | openssl dgst -sha256 -hmac "$secret_key" -binary \
    | base64 -w0)

# --- JSON DFP (samo za transport) ---
dfp_json=$(cat <<EOF
{
  "cpu_vendor":"$cpu_vendor",
  "cpu_arch":"$cpu_arch",
  "cpu_model":"$cpu_model",
  "cpu_hartid":"$cpu_hartid",
  "mac":"$mac",
  "emmc_cid":"$emmc_cid",
  "kernel":"$kernel",
  "kernel_conf_hash":"$kernel_conf_hash",
  "dt_model":"$dt_model",
  "dt_compatible":"$dt_compatible",
  "modules_count":"$modules_count",
  "boot_time":"$boot_time",
  "packages_hash":"$packages_hash",
  "eeprom":"$eeprom",
  "loadavg":"$loadavg",
  "user_processes":"$user_processes",
  "avail_ram":"$avail_ram",
  "disk_free_mb":"$disk_free_mb",
  "disk_io":"$disk_io",
  "rx_bytes":"$rx_bytes",
  "tx_bytes":"$tx_bytes",
  "top5_processes":"$top5_processes",
  "gpio_value":"$gpio_value",
  "i2c_devices":"$i2c_devices",
  "device_hash":"$device_hash",
  "working_state":"$working_state",
  "current_job":"$current_job"
}
EOF
)

# --- Base64 kodiranje JSON ---
dfp_encoded=$(echo -n "$dfp_json" | base64 -w0)

# --- Finalni paket (json + hmac, skupaj base64) ---
final_json=$(cat <<EOF
{
  "data":"$dfp_encoded",
  "hmac":"$dfp_hmac_encoded"
}
EOF
)
final_encoded=$(echo -n "$final_json" | base64 -w0)

# --- Izhod ---
#echo "DFP JSON:"
#echo "$dfp_json"
#echo
#echo "Encoded DFP (base64 JSON):"
#echo "$dfp_encoded"
#echo
#echo "HMAC (SHA-256, key=****, base64):"
#echo "$dfp_hmac_encoded"
#echo
#echo "Finalni paket (JSON+HMAC, base64):"
echo "$final_encoded"

