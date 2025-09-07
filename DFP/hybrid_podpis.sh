#!/bin/bash

START_TIME=$(date +%s%3N)  # za�~Metni �~Mas v milisekundah



# Preveri, če je geslo za HMAC podano
if [ -z "$1" ]; then
  echo "Uporaba: $0 <geslo_za_HMAC>"
  exit 1
fi

SECRET_KEY="$1"

# --- Pridobivanje podatkov naprave (kot v podpis.sh) ---
cpu_vendor="SiFive"
cpu_arch=$(uname -m)
cpu_model=$(awk -F: '/isa/ {print $2}' /proc/cpuinfo | paste -sd, -)
cpu_hartid=$(grep hart /proc/cpuinfo | awk '{print $3}' | head -n1)
mac_eth0=$(ip link show eth0 2>/dev/null | awk '/ether/ {print $2; exit}')
mac_usb0=$(ip link show usb0 2>/dev/null | awk '/ether/ {print $2; exit}')

emmc_cid=$(cat /sys/block/mmcblk0/device/cid 2>/dev/null || echo "N/A")
kernel=$(uname -r)
kernel_conf_hash=$(if [ -f /proc/config.gz ]; then zcat /proc/config.gz | sha256sum | awk '{print $1}'; else echo "N/A"; fi)
dt_model=$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null || echo "N/A")
dt_compatible=$(tr -d '\0' </sys/firmware/devicetree/base/compatible 2>/dev/null || echo "N/A")
modules_count=$(lsmod | wc -l)
boot_time=$(awk '{print $1}' /proc/uptime)
packages_hash=$(if command -v dpkg >/dev/null; then dpkg -l | sha256sum | awk '{print $1}'; elif command -v rpm >/dev/null; then rpm -qa | sha256sum | awk '{print $1}'; else echo "N/A"; fi)

# FPGA ID / EEPROM
eeprom=$(sudo head -c 24 /sys/bus/nvmem/devices/1-00501/nvmem 2>/dev/null)

# Working state in current job (če obstajata datoteki)
working_state=$(cat DATA/working_state.txt 2>/dev/null || echo "0")
current_job=$(cat DATA/current_job.txt 2>/dev/null || echo "None")

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
top5_processes=$(ps -eo comm,%cpu,%mem --sort=-%cpu | head -n6 | tail -n5 | awk '{print $1":"$2":"$3}' | tr '\n' ',' | sed 's/,$//')

# GPIO (če je gpioget na voljo)
# GPIO
gpio_value=""
for line in {0..13}; do
    value=$(gpioget gpiochip0 $line 2>/dev/null)
    gpio_value+="$line:$value,"
done
gpio_value=${gpio_value%,}

# I2C naprave
if command -v i2cdetect >/dev/null; then
    i2c_devices=$(i2cdetect -y 1 2>/dev/null \
        | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' \
        | tr -d '\n')  # odstranimo dejanske prelome vrstic
else
    i2c_devices="N/A"
fi

# Machine ID (če obstaja)
if [ -f /etc/machine-id ]; then
    machine_id=$(cat /etc/machine-id)
else
    echo "Fali maschine ID"
fi

# --- SHA-256 za statične podatke ---
static_data="${cpu_vendor}_${cpu_arch}_${cpu_model}_${cpu_hartid}_${mac_eth0}_${mac_usb0}_${emmc_cid}_${eeprom}_${machine_id}_${kernel}_${kernel_conf_hash}_${dt_model}_${dt_compatible}_${gpio_value}_${packages_hash}"
static_sha256=$(echo -n "$static_data" | sha256sum | awk '{print $1}')
#echo "SHA-256 statičnih podatkov: $static_sha256"

# --- TLSH za dinamične podatke ---
dynamic_data="${modules_count}_${boot_time}_${loadavg}_${user_processes}_${avail_ram}_${disk_free_mb}_${disk_io}_${rx_bytes}_${tx_bytes}_${top5_processes}_${i2c_devices}_${working_state}_${current_job}"

# Uporaba Python tlsh namesto system ukaza
if python3 -c "import tlsh" 2>/dev/null; then
    fuzzy_hash=$(python3 -c "import tlsh; print(tlsh.hash(b'''$dynamic_data'''))")
    #echo "TLSH fuzzy hash dinamičnih podatkov: $fuzzy_hash"
else
    echo "py-tlsh ni nameščen, uporabljam SHA-256 kot nadomestilo"
    fuzzy_hash=$(echo -n "$dynamic_data" | sha256sum | awk '{print $1}')
    echo "SHA-256 dinamičnih podatkov (nadomestno): $fuzzy_hash"
fi

# --- JSON z vsemi podatki ---
json_data=$(cat <<EOF
{
  "static_sha256": "$static_sha256",
  "fuzzy_hash": "$fuzzy_hash"
}
EOF
)

# --- HMAC za JSON ---
hmac=$(echo -n "$json_data" | openssl dgst -sha256 -hmac "$SECRET_KEY" | awk '{print $2}')
#echo "HMAC JSON podatkov: $hmac"

# --- JSON z HMAC podatki ---
json_data=$(cat <<EOF
{
  "json": "$json_data",
  "hmac": "$hmac"
}
EOF
)


# --- Base64 kodiranje JSON ---
json_base64=$(echo -n "$json_data" | base64 -w0)
#echo "Base64 kodiran JSON: $json_base64"
echo $json_base64





END_TIME=$(date +%s%3N)  # kon�~Mni �~Mas v milisekundah
ELAPSED=$((END_TIME - START_TIME))

echo "�~Las izvajanja: ${ELAPSED} ms"
echo "Register response: $REGISTER_RESPONSE"





