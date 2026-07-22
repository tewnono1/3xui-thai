#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"

# ห้ามแก้ไขค่ากำหนดส่วนนี้
b_source="${BASH_SOURCE[0]}"
while [ -h "$b_source" ]; do
    b_dir="$(cd -P "$(dirname "$b_source")" > /dev/null 2>&1 && pwd || pwd -P)"
    b_source="$(readlink "$b_source")"
    [[ $b_source != /* ]] && b_source="$b_dir/$b_source"
done
cur_dir="$(cd -P "$(dirname "$b_source")" > /dev/null 2>&1 && pwd || pwd -P)"
script_name=$(basename "$0")

# ฟังก์ชันตรวจสอบว่ามีคำสั่งนี้อยู่หรือไม่
_command_exists() {
    type "$1" &> /dev/null
}

# ฟังก์ชันแสดงข้อความผิดพลาด บันทึก และออกจากสคริปต์
_fail() {
    local msg=${1}
    echo -e "${red}${msg}${plain}"
    exit 2
}

# บันทึกผลลัพธ์การทำงานเพื่อให้ตัวอัปเดตเว็บของ panel ตรวจสอบสถานะได้
xui_update_run_id="${XUI_UPDATE_RUN_ID:-0}"
[[ "${xui_update_run_id}" =~ ^[0-9]+$ ]] || xui_update_run_id="0"
xui_update_status_file="${XUI_UPDATE_STATUS_FILE:-/etc/x-ui/update-status.json}"

_write_update_status() {
    local state="$1"
    local exit_code="$2"
    local status_dir
    status_dir="$(dirname "${xui_update_status_file}")"
    mkdir -p "${status_dir}" > /dev/null 2>&1
    local tmp_file="${xui_update_status_file}.tmp.$$"
    printf '{"runId":"%s","state":"%s","exitCode":%s,"finishedAt":%s}\n' \
        "${xui_update_run_id}" "${state}" "${exit_code}" "$(date +%s)" > "${tmp_file}" 2> /dev/null
    mv -f "${tmp_file}" "${xui_update_status_file}" > /dev/null 2>&1
}

_report_update_exit() {
    local code=$?
    if [[ "${code}" -eq 0 ]]; then
        _write_update_status "success" "0"
    else
        _write_update_status "failed" "${code}"
    fi
}
trap _report_update_exit EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# ตรวจสอบสิทธิ์ root
[[ $EUID -ne 0 ]] && _fail "ข้อผิดพลาดร้ายแรง: โปรดรันสคริปต์นี้ด้วยสิทธิ์ root"

if _command_exists curl; then
    curl_bin=$(which curl)
else
    _fail "ข้อผิดพลาด: ไม่พบคำสั่ง 'curl'"
fi

# ตรวจสอบ OS และกำหนดค่าตัวแปร release
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    _fail "ไม่สามารถตรวจสอบระบบปฏิบัติการของเครื่องได้ โปรดติดต่อผู้พัฒนา!"
fi
echo "ระบบปฏิบัติการ (OS release) คือ: $release"

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${red}สถาปัตยกรรม CPU ไม่รองรับ!${plain}" && rm -f "${cur_dir}/${script_name}" > /dev/null 2>&1 && exit 2 ;;
    esac
}

echo "สถาปัตยกรรม: $(arch)"

# ตัวช่วยอย่างง่าย
is_ipv4() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0 || return 1
}
is_ipv6() {
    [[ "$1" =~ : ]] && return 0 || return 1
}
is_ip() {
    is_ipv4 "$1" || is_ipv6 "$1"
}
is_domain() {
    [[ "$1" =~ ^([A-Za-z0-9](-*[A-Za-z0-9])*\.)+(xn--[a-z0-9]{2,}|[A-Za-z]{2,})$ ]] && return 0 || return 1
}

acme_listen_flag() {
    if ip -4 addr show scope global 2> /dev/null | grep -q "inet "; then
        echo ""
    else
        echo "--listen-v6"
    fi
}

# ตัวช่วยเรื่องพอร์ต
is_port_in_use() {
    local port="$1"
    if command -v ss > /dev/null 2>&1; then
        ss -ltn 2> /dev/null | awk -v p=":${port}$" '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v netstat > /dev/null 2>&1; then
        netstat -lnt 2> /dev/null | awk -v p=":${port} " '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v lsof > /dev/null 2>&1; then
        lsof -nP -iTCP:${port} -sTCP:LISTEN > /dev/null 2>&1 && return 0
    fi
    return 1
}

gen_random_string() {
    local length="$1"
    openssl rand -base64 $((length * 2)) \
        | tr -dc 'a-zA-Z0-9' \
        | head -c "$length"
}

xui_env_file_path() {
    case "${release}" in
        ubuntu | debian | armbian)
            echo "/etc/default/x-ui"
            ;;
        arch | manjaro | parch | alpine)
            echo "/etc/conf.d/x-ui"
            ;;
        *)
            echo "/etc/sysconfig/x-ui"
            ;;
    esac
}

load_xui_env() {
    local env_file
    env_file="$(xui_env_file_path)"
    if [[ -r "$env_file" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    fi
}

install_base() {
    echo -e "${green}กำลังอัปเดตและติดตั้งแพ็กเกจ dependencies...${plain}"
    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update > /dev/null 2>&1 && apt-get install -y -q cron curl tar tzdata socat openssl > /dev/null 2>&1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf makecache -y > /dev/null 2>&1 && dnf install -y -q cronie curl tar tzdata socat openssl > /dev/null 2>&1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum makecache -y > /dev/null 2>&1 && yum install -y -q cronie curl tar tzdata socat openssl > /dev/null 2>&1
            else
                dnf makecache -y > /dev/null 2>&1 && dnf install -y -q cronie curl tar tzdata socat openssl > /dev/null 2>&1
            fi
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm cronie curl tar tzdata socat openssl > /dev/null 2>&1
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper refresh > /dev/null 2>&1 && zypper -q install -y cron curl tar timezone socat openssl > /dev/null 2>&1
            ;;
        alpine)
            apk update > /dev/null 2>&1 && apk add dcron curl tar tzdata socat openssl > /dev/null 2>&1
            ;;
        *)
            apt-get update > /dev/null 2>&1 && apt install -y -q cron curl tar tzdata socat openssl > /dev/null 2>&1
            ;;
    esac
}

install_acme() {
    echo -e "${green}กำลังติดตั้ง acme.sh สำหรับจัดการใบรับรอง SSL...${plain}"
    cd ~ || return 1
    curl -s https://get.acme.sh | sh > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${red}ติดตั้ง acme.sh ไม่สำเร็จ${plain}"
        return 1
    else
        echo -e "${green}ติดตั้ง acme.sh สำเร็จแล้ว${plain}"
    fi
    return 0
}

setup_ssl_certificate() {
    local domain="$1"
    local server_ip="$2"
    local existing_port="$3"
    local existing_webBasePath="$4"

    echo -e "${green}กำลังตั้งค่าใบรับรอง SSL...${plain}"

    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${yellow}ไม่สามารถติดตั้ง acme.sh ได้ ข้ามการตั้งค่า SSL${plain}"
            return 1
        fi
    fi

    local certPath="/root/cert/${domain}"
    mkdir -p "$certPath"

    echo -e "${green}กำลังออกใบรับรอง SSL สำหรับ ${domain}...${plain}"
    echo -e "${yellow}หมายเหตุ: ต้องเปิดพอร์ต 80 และสามารถเข้าถึงได้จากอินเทอร์เน็ต${plain}"

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1
    ~/.acme.sh/acme.sh --issue -d ${domain} $(acme_listen_flag) --standalone --httpport 80 --force

    if [ $? -ne 0 ]; then
        echo -e "${yellow}ออกใบรับรองสำหรับ ${domain} ไม่สำเร็จ${plain}"
        echo -e "${yellow}โปรดตรวจสอบให้แน่ใจว่าเปิดพอร์ต 80 แล้ว และลองอีกครั้งด้วยคำสั่ง: x-ui${plain}"
        rm -rf ~/.acme.sh/${domain} 2> /dev/null
        rm -rf "$certPath" 2> /dev/null
        return 1
    fi

    ~/.acme.sh/acme.sh --installcert --force -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem \
        --reloadcmd "systemctl restart x-ui" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${yellow}ติดตั้งใบรับรองไม่สำเร็จ${plain}"
        return 1
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1
    chmod 600 $certPath/privkey.pem 2> /dev/null
    chmod 644 $certPath/fullchain.pem 2> /dev/null

    local webCertFile="/root/cert/${domain}/fullchain.pem"
    local webKeyFile="/root/cert/${domain}/privkey.pem"

    if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
        ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile" > /dev/null 2>&1
        echo -e "${green}ติดตั้งและกำหนดค่าใบรับรอง SSL สำเร็จแล้ว!${plain}"
        return 0
    else
        echo -e "${yellow}ไม่พบไฟล์ใบรับรอง${plain}"
        return 1
    fi
}

setup_ip_certificate() {
    local ipv4="$1"
    local ipv6="$2"

    echo -e "${green}กำลังตั้งค่าใบรับรอง SSL สำหรับ IP ของ Let's Encrypt (โปรไฟล์อายุสั้น)...${plain}"
    echo -e "${yellow}หมายเหตุ: ใบรับรอง IP มีอายุ ~6 วัน และจะต่ออายุให้อัตโนมัติ${plain}"
    echo -e "${yellow}พอร์ตเริ่มต้นคือพอร์ต 80 หากคุณเลือกพอร์ตอื่น โปรดแน่ใจว่ามีการ forward พอร์ต 80 ภายนอกมายังพอร์ตนั้น${plain}"

    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}ติดตั้ง acme.sh ไม่สำเร็จ${plain}"
            return 1
        fi
    fi

    if [[ -z "$ipv4" ]]; then
        echo -e "${red}จำเป็นต้องระบุ IPv4${plain}"
        return 1
    fi

    if ! is_ipv4 "$ipv4"; then
        echo -e "${red}IPv4 ไม่ถูกต้อง: $ipv4${plain}"
        return 1
    fi

    local certDir="/root/cert/ip"
    mkdir -p "$certDir"

    local domain_args="-d ${ipv4}"
    if [[ -n "$ipv6" ]] && is_ipv6 "$ipv6"; then
        domain_args="${domain_args} -d ${ipv6}"
        echo -e "${green}รวมถึงที่อยู่ IPv6 ด้วย: ${ipv6}${plain}"
    fi

    local reloadCmd="systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true"

    local WebPort=""
    read -rp "พอร์ตที่ต้องการใช้สำหรับตัวฟัง ACME HTTP-01 (ค่าเริ่มต้น 80): " WebPort
    WebPort="${WebPort:-80}"
    if ! [[ "${WebPort}" =~ ^[0-9]+$ ]] || ((WebPort < 1 || WebPort > 65535)); then
        echo -e "${red}พอร์ตไม่ถูกต้อง กลับไปใช้ค่าเริ่มต้น 80${plain}"
        WebPort=80
    fi
    echo -e "${green}ใช้พอร์ต ${WebPort} สำหรับการตรวจสอบแบบ standalone${plain}"
    if [[ "${WebPort}" -ne 80 ]]; then
        echo -e "${yellow}เตือนความจำ: Let's Encrypt ยังคงเชื่อมต่อที่พอร์ต 80 ให้ทำการ forward พอร์ต 80 ภายนอกมายัง ${WebPort}${plain}"
    fi

    while true; do
        if is_port_in_use "${WebPort}"; then
            echo -e "${yellow}พอร์ต ${WebPort} กำลังถูกใช้งานอยู่${plain}"

            local alt_port=""
            read -rp "ป้อนพอร์ตอื่นสำหรับตัวฟัง standalone ของ acme.sh (ปล่อยว่างเพื่อยกเลิก): " alt_port
            alt_port="${alt_port// /}"
            if [[ -z "${alt_port}" ]]; then
                echo -e "${red}พอร์ต ${WebPort} ถูกใช้งานอยู่ ไม่สามารถดำเนินการต่อได้${plain}"
                return 1
            fi
            if ! [[ "${alt_port}" =~ ^[0-9]+$ ]] || ((alt_port < 1 || alt_port > 65535)); then
                echo -e "${red}พอร์ตไม่ถูกต้อง${plain}"
                return 1
            fi
            WebPort="${alt_port}"
            continue
        else
            echo -e "${green}พอร์ต ${WebPort} ว่างและพร้อมใช้งานสำหรับการตรวจสอบ${plain}"
            break
        fi
    done

    echo -e "${green}กำลังออกใบรับรอง IP สำหรับ ${ipv4}...${plain}"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1

    ~/.acme.sh/acme.sh --issue \
        ${domain_args} \
        --standalone \
        --server letsencrypt \
        --certificate-profile shortlived \
        --days 6 \
        --httpport ${WebPort} \
        --force

    if [ $? -ne 0 ]; then
        echo -e "${red}ออกใบรับรอง IP ไม่สำเร็จ${plain}"
        echo -e "${yellow}โปรดตรวจสอบว่าพอร์ต ${WebPort} สามารถเข้าถึงได้ (หรือ forward มาจากพอร์ต 80 ภายนอก)${plain}"
        rm -rf ~/.acme.sh/${ipv4} 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}ออกใบรับรองสำเร็จ กำลังติดตั้ง...${plain}"

    ~/.acme.sh/acme.sh --installcert --force -d ${ipv4} \
        --key-file "${certDir}/privkey.pem" \
        --fullchain-file "${certDir}/fullchain.pem" \
        --reloadcmd "${reloadCmd}" 2>&1 || true

    if [[ ! -f "${certDir}/fullchain.pem" || ! -f "${certDir}/privkey.pem" ]]; then
        echo -e "${red}ไม่พบไฟล์ใบรับรองหลังการติดตั้ง${plain}"
        rm -rf ~/.acme.sh/${ipv4} 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}ติดตั้งไฟล์ใบรับรองสำเร็จ${plain}"

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1

    chmod 600 ${certDir}/privkey.pem 2> /dev/null
    chmod 644 ${certDir}/fullchain.pem 2> /dev/null

    echo -e "${green}กำลังตั้งค่าเส้นทางใบรับรองสำหรับ Panel...${plain}"
    ${xui_folder}/x-ui cert -webCert "${certDir}/fullchain.pem" -webCertKey "${certDir}/privkey.pem"
    if [ $? -ne 0 ]; then
        echo -e "${yellow}คำเตือน: ไม่สามารถตั้งค่าเส้นทางใบรับรองอัตโนมัติได้${plain}"
        echo -e "${yellow}คุณอาจต้องตั้งค่าด้วยตนเองในการตั้งค่า Panel${plain}"
        echo -e "${yellow}เส้นทาง Cert: ${certDir}/fullchain.pem${plain}"
        echo -e "${yellow}เส้นทาง Key: ${certDir}/privkey.pem${plain}"
    else
        echo -e "${green}ตั้งค่าเส้นทางใบรับรองสำเร็จ!${plain}"
    fi

    echo -e "${green}ติดตั้งและกำหนดค่าใบรับรอง IP สำเร็จแล้ว!${plain}"
    echo -e "${green}ใบรับรองมีอายุ ~6 วัน จะต่ออายุอัตโนมัติผ่าน cron job ของ acme.sh${plain}"
    echo -e "${yellow}Panel จะรีสตาร์ทโดยอัตโนมัติหลังจากการต่ออายุแต่ละครั้ง${plain}"
    return 0
}

ssl_cert_issue() {
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep 'webBasePath:' | awk -F': ' '{print $2}' | tr -d '[:space:]' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep 'port:' | awk -F': ' '{print $2}' | tr -d '[:space:]')

    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        echo "ไม่พบ acme.sh กำลังติดตั้ง..."
        cd ~ || return 1
        curl -s https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            echo -e "${red}ติดตั้ง acme.sh ไม่สำเร็จ${plain}"
            return 1
        else
            echo -e "${green}ติดตั้ง acme.sh สำเร็จแล้ว${plain}"
        fi
    fi

    local domain=""
    while true; do
        read -rp "โปรดป้อนชื่อโดเมนของคุณ: " domain
        domain="${domain// /}"

        if [[ -z "$domain" ]]; then
            echo -e "${red}ชื่อโดเมนต้องไม่ว่างเปล่า โปรดลองอีกครั้ง${plain}"
            continue
        fi

        if ! is_domain "$domain"; then
            echo -e "${red}รูปแบบโดเมนไม่ถูกต้อง: ${domain} โปรดป้อนชื่อโดเมนที่ถูกต้อง${plain}"
            continue
        fi

        break
    done
    echo -e "${green}โดเมนของคุณคือ: ${domain} กำลังตรวจสอบ...${plain}"
    SSL_ISSUED_DOMAIN="${domain}"

    local cert_exists=0
    if ~/.acme.sh/acme.sh --list 2> /dev/null | grep '{print $1}' | grep -Fxq "${domain}"; then
        cert_exists=1
        local certInfo=$(~/.acme.sh/acme.sh --list 2> /dev/null | grep -F "${domain}")
        echo -e "${yellow}พบใบรับรองที่มีอยู่สำหรับ ${domain} จะทำการใช้งานซ้ำ${plain}"
        [[ -n "${certInfo}" ]] && echo "$certInfo"
    else
        echo -e "${green}โดเมนของคุณพร้อมสำหรับการออกใบรับรองแล้ว...${plain}"
    fi

    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    local WebPort=80
    read -rp "โปรดเลือกพอร์ตที่ต้องการใช้ (ค่าเริ่มต้นคือ 80): " WebPort
    if [[ -z ${WebPort} ]]; then
        WebPort=80
    elif [[ ! ${WebPort} =~ ^[1-9][0-9]*$ || ${WebPort} -gt 65535 ]]; then
        echo -e "${yellow}ค่าที่คุณป้อน ${WebPort} ไม่ถูกต้อง จะใช้พอร์ตเริ่มต้น 80${plain}"
        WebPort=80
    fi
    echo -e "${green}จะใช้พอร์ต: ${WebPort} เพื่อออกใบรับรอง โปรดตรวจสอบให้แน่ใจว่าพอร์ตนี้เปิดอยู่${plain}"

    echo -e "${yellow}กำลังหยุด Panel ชั่วคราว...${plain}"
    systemctl stop x-ui 2> /dev/null || rc-service x-ui stop 2> /dev/null

    if [[ ${cert_exists} -eq 0 ]]; then
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force
        ~/.acme.sh/acme.sh --issue -d ${domain} $(acme_listen_flag) --standalone --httpport ${WebPort} --force
        if [ $? -ne 0 ]; then
            echo -e "${red}ออกใบรับรองไม่สำเร็จ โปรดตรวจสอบบันทึก (logs)${plain}"
            rm -rf ~/.acme.sh/${domain}
            systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
            return 1
        else
            echo -e "${green}ออกใบรับรองสำเร็จ กำลังติดตั้งใบรับรอง...${plain}"
        fi
    else
        echo -e "${green}ใช้ใบรับรองที่มีอยู่ กำลังติดตั้งใบรับรอง...${plain}"
    fi

    reloadCmd="systemctl restart x-ui || rc-service x-ui restart"
    echo -e "${green}ค่า --reloadcmd เริ่มต้นสำหรับ ACME คือ: ${yellow}systemctl restart x-ui || rc-service x-ui restart${plain}"
    echo -e "${green}คำสั่งนี้จะทำงานทุกครั้งที่มีการออกและต่ออายุใบรับรอง${plain}"
    read -rp "คุณต้องการแก้ไข --reloadcmd สำหรับ ACME หรือไม่? (y/n): " setReloadcmd
    if [[ "$setReloadcmd" == "y" || "$setReloadcmd" == "Y" ]]; then
        echo -e "\n${green}\t1.${plain} ค่าสำเร็จรูป: systemctl reload nginx ; systemctl restart x-ui"
        echo -e "${green}\t2.${plain} ป้อนคำสั่งของคุณเอง"
        echo -e "${green}\t0.${plain} คงค่า reloadcmd เดิมไว้"
        read -rp "เลือกตัวเลือก: " choice
        case "$choice" in
            1)
                echo -e "${green}Reloadcmd คือ: systemctl reload nginx ; systemctl restart x-ui${plain}"
                reloadCmd="systemctl reload nginx ; systemctl restart x-ui"
                ;;
            2)
                echo -e "${yellow}แนะนำให้ใส่ x-ui restart ไว้ที่ท้ายสุด${plain}"
                read -rp "โปรดป้อน reloadcmd กำเองของคุณ: " reloadCmd
                echo -e "${green}Reloadcmd คือ: ${reloadCmd}${plain}"
                ;;
            *)
                echo -e "${green}คงค่า reloadcmd เดิม${plain}"
                ;;
        esac
    fi

    local installOutput=""
    installOutput=$(~/.acme.sh/acme.sh --installcert --force -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem --reloadcmd "${reloadCmd}" 2>&1)
    local installRc=$?
    echo "${installOutput}"

    local installWroteFiles=0
    if echo "${installOutput}" | grep -q "Installing key to:" && echo "${installOutput}" | grep -q "Installing full chain to:"; then
        installWroteFiles=1
    fi

    if [[ -f "/root/cert/${domain}/privkey.pem" && -f "/root/cert/${domain}/fullchain.pem" && (${installRc} -eq 0 || ${installWroteFiles} -eq 1) ]]; then
        echo -e "${green}ติดตั้งใบรับรองสำเร็จ เปิดใช้งานการต่ออายุอัตโนมัติ...${plain}"
    else
        echo -e "${red}ติดตั้งใบรับรองไม่สำเร็จ กำลังออก...${plain}"
        if [[ ${cert_exists} -eq 0 ]]; then
            rm -rf ~/.acme.sh/${domain}
        fi
        systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
        return 1
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${yellow}การตั้งค่าต่ออายุอัตโนมัติมีปัญหา รายละเอียดใบรับรอง:${plain}"
        ls -lah /root/cert/${domain}/
        chmod 600 $certPath/privkey.pem
        chmod 644 $certPath/fullchain.pem
    else
        echo -e "${green}ต่ออายุอัตโนมัติสำเร็จ รายละเอียดใบรับรอง:${plain}"
        ls -lah /root/cert/${domain}/
        chmod 600 $certPath/privkey.pem
        chmod 644 $certPath/fullchain.pem
    fi

    systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null

    read -rp "คุณต้องการตั้งค่าใบรับรองนี้สำหรับ Panel หรือไม่? (y/n): " setPanel
    if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
        local webCertFile="/root/cert/${domain}/fullchain.pem"
        local webKeyFile="/root/cert/${domain}/privkey.pem"

        if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
            ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
            echo -e "${green}ตั้งค่าเส้นทางใบรับรองสำหรับ Panel เรียบร้อยแล้ว${plain}"
            echo -e "${green}ไฟล์ใบรับรอง: $webCertFile${plain}"
            echo -e "${green}ไฟล์ Private Key: $webKeyFile${plain}"
            echo ""
            echo -e "${green}URL การเข้าถึง: https://${domain}:${existing_port}/${existing_webBasePath}${plain}"
            echo -e "${yellow}Panel จะรีสตาร์ทเพื่อใช้ใบรับรอง SSL...${plain}"
            systemctl restart x-ui 2> /dev/null || rc-service x-ui restart 2> /dev/null
        else
            echo -e "${red}ข้อผิดพลาด: ไม่พบไฟล์ใบรับรองหรือ private key สำหรับโดเมน: $domain${plain}"
        fi
    else
        echo -e "${yellow}ข้ามการตั้งค่าเส้นทางสำหรับ Panel${plain}"
    fi

    return 0
}

prompt_and_setup_ssl() {
    local panel_port="$1"
    local web_base_path="$2"
    local server_ip="$3"

    local ssl_choice=""

    echo -e "${yellow}เลือกวิธีการตั้งค่าใบรับรอง SSL:${plain}"
    echo -e "${green}1.${plain} Let's Encrypt สำหรับโดเมน (อายุ 90 วัน ต่ออายุอัตโนมัติ)"
    echo -e "${green}2.${plain} Let's Encrypt สำหรับที่อยู่ IP (อายุ 6 วัน ต่ออายุอัตโนมัติ)"
    echo -e "${green}3.${plain} ใบรับรอง SSL แบบกำหนดเอง (ระบุเส้นทางไฟล์ที่มีอยู่)"
    echo -e "${green}4.${plain} ข้าม SSL (ขั้นสูง — อยู่เบื้องหลัง reverse proxy / SSH tunnel เท่านั้น)"
    echo -e "${blue}หมายเหตุ:${plain} ตัวเลือก 1 และ 2 ต้องเปิดพอร์ต 80 ตัวเลือก 3 ต้องระบุเส้นทางไฟล์เอง"
    echo -e "${blue}หมายเหตุ:${plain} ตัวเลือก 4 จะให้บริการ Panel ผ่าน HTTP ธรรมดา — ปลอดภัยเมื่ออยู่หลัง nginx/Caddy หรือ SSH tunnel เท่านั้น"
    read -rp "เลือกตัวเลือก (ค่าเริ่มต้น 2 สำหรับ IP): " ssl_choice
    ssl_choice="${ssl_choice// /}"

    if [[ "$ssl_choice" != "1" && "$ssl_choice" != "3" && "$ssl_choice" != "4" ]]; then
        ssl_choice="2"
    fi

    case "$ssl_choice" in
        1)
            echo -e "${green}กำลังใช้ Let's Encrypt สำหรับใบรับรองโดเมน...${plain}"
            if ssl_cert_issue; then
                local cert_domain="${SSL_ISSUED_DOMAIN}"
                if [[ -z "${cert_domain}" ]]; then
                    cert_domain=$(~/.acme.sh/acme.sh --list 2> /dev/null | tail -1 | awk '{print $1}')
                fi

                if [[ -n "${cert_domain}" ]]; then
                    SSL_HOST="${cert_domain}"
                    echo -e "${green}✓ กำหนดค่าใบรับรอง SSL ด้วยโดเมนสำเร็จ: ${cert_domain}${plain}"
                else
                    echo -e "${yellow}การตั้งค่า SSL อาจเสร็จสมบูรณ์ แต่การดึงชื่อโดเมนล้มเหลว${plain}"
                    SSL_HOST="${server_ip}"
                fi
            else
                echo -e "${red}การตั้งค่าใบรับรอง SSL สำหรับโหมดโดเมนล้มเหลว${plain}"
                SSL_HOST="${server_ip}"
            fi
            ;;
        2)
            echo -e "${green}กำลังใช้ Let's Encrypt สำหรับใบรับรอง IP (โปรไฟล์อายุสั้น)...${plain}"

            local ip_confirm=""
            read -rp "${server_ip} คือ IP สาธารณะขาเข้าที่ถูกต้องสำหรับเซิร์ฟเวอร์นี้ใช่หรือไม่? [ค่าเริ่มต้น y]: " ip_confirm
            if [[ -n "$ip_confirm" && "$ip_confirm" != "y" && "$ip_confirm" != "Y" ]]; then
                server_ip=""
                while [[ -z "$server_ip" ]]; do
                    read -rp "โปรดป้อนที่อยู่ IPv4 สาธารณะของเซิร์ฟเวอร์ของคุณ: " server_ip
                    server_ip="${server_ip// /}"
                    if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        echo -e "${red}IPv4 ไม่ถูกต้อง โปรดลองอีกครั้ง${plain}"
                        server_ip=""
                    fi
                done
            fi

            local ipv6_addr=""
            read -rp "คุณมีที่อยู่ IPv6 ที่ต้องการรวมด้วยหรือไม่? (ปล่อยว่างเพื่อข้าม): " ipv6_addr
            ipv6_addr="${ipv6_addr// /}"

            if [[ $release == "alpine" ]]; then
                rc-service x-ui stop > /dev/null 2>&1
            else
                systemctl stop x-ui > /dev/null 2>&1
            fi

            setup_ip_certificate "${server_ip}" "${ipv6_addr}"
            if [ $? -eq 0 ]; then
                SSL_HOST="${server_ip}"
                echo -e "${green}✓ กำหนดค่าใบรับรอง IP ของ Let's Encrypt สำเร็จแล้ว${plain}"
            else
                echo -e "${red}✗ ตั้งค่าใบรับรอง IP ไม่สำเร็จ โปรดตรวจสอบว่าเปิดพอร์ต 80 แล้ว${plain}"
                SSL_HOST="${server_ip}"
            fi

            if [[ $release == "alpine" ]]; then
                rc-service x-ui restart > /dev/null 2>&1
            else
                systemctl restart x-ui > /dev/null 2>&1
            fi

            ;;
        3)
            echo -e "${green}กำลังใช้ใบรับรองที่มีอยู่แบบกำหนดเอง...${plain}"
            local custom_cert=""
            local custom_key=""
            local custom_domain=""

            read -rp "โปรดป้อนชื่อโดเมนที่ออกใบรับรองให้: " custom_domain
            custom_domain="${custom_domain// /}"

            while true; do
                read -rp "ป้อนเส้นทางใบรับรอง (คำสำคัญ: .crt / fullchain): " custom_cert
                custom_cert=$(echo "$custom_cert" | tr -d '"' | tr -d "'")

                if [[ -f "$custom_cert" && -r "$custom_cert" && -s "$custom_cert" ]]; then
                    break
                elif [[ ! -f "$custom_cert" ]]; then
                    echo -e "${red}ข้อผิดพลาด: ไม่พบไฟล์! ลองอีกครั้ง${plain}"
                elif [[ ! -r "$custom_cert" ]]; then
                    echo -e "${red}ข้อผิดพลาด: มีไฟล์อยู่แต่ไม่สามารถอ่านได้ (ตรวจสอบสิทธิ์การเข้าถึง)!${plain}"
                else
                    echo -e "${red}ข้อผิดพลาด: ไฟล์ว่างเปล่า!${plain}"
                fi
            done

            while true; do
                read -rp "ป้อนเส้นทาง private key (คำสำคัญ: .key / privatekey): " custom_key
                custom_key=$(echo "$custom_key" | tr -d '"' | tr -d "'")

                if [[ -f "$custom_key" && -r "$custom_key" && -s "$custom_key" ]]; then
                    break
                elif [[ ! -f "$custom_key" ]]; then
                    echo -e "${red}ข้อผิดพลาด: ไม่พบไฟล์! ลองอีกครั้ง${plain}"
                elif [[ ! -r "$custom_key" ]]; then
                    echo -e "${red}ข้อผิดพลาด: มีไฟล์อยู่แต่ไม่สามารถอ่านได้ (ตรวจสอบสิทธิ์การเข้าถึง)!${plain}"
                else
                    echo -e "${red}ข้อผิดพลาด: ไฟล์ว่างเปล่า!${plain}"
                fi
            done

            ${xui_folder}/x-ui cert -webCert "$custom_cert" -webCertKey "$custom_key" > /dev/null 2>&1

            if [[ -n "$custom_domain" ]]; then
                SSL_HOST="$custom_domain"
            else
                SSL_HOST="${server_ip}"
            fi

            echo -e "${green}✓ นำเส้นทางใบรับรองกำหนดเองไปใช้แล้ว${plain}"
            echo -e "${yellow}หมายเหตุ: คุณต้องรับผิดชอบในการต่ออายุไฟล์เหล่านี้จากภายนอกเอง${plain}"

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            ;;
        4)
            echo ""
            echo -e "${red}⚠ Panel จะถูกติดตั้งโดยไม่มี SSL/TLS${plain}"
            echo -e "${yellow}ข้อมูลเข้าสู่ระบบและคุกกี้จะถูกส่งผ่าน HTTP ธรรมดา${plain}"
            echo -e "${yellow}ปลอดภัยเฉพาะเมื่อ:${plain}"
            echo -e "${yellow}  • มี Reverse proxy (nginx, Caddy, Traefik) ถอดรหัส TLS ให้, หรือ${plain}"
            echo -e "${yellow}  • คุณเข้าถึง Panel ผ่าน SSH tunnel เท่านั้น${plain}"
            echo ""

            SSL_SCHEME="http"
            SSL_HOST="${server_ip}"

            local bind_local=""
            read -rp "ผูก Panel กับ 127.0.0.1 เท่านั้นหรือไม่? (แนะนำ — บังคับให้เข้าผ่าน SSH tunnel / reverse-proxy) [y/N]: " bind_local
            if [[ "$bind_local" == "y" || "$bind_local" == "Y" ]]; then
                ${xui_folder}/x-ui setting -listenIP "127.0.0.1" > /dev/null 2>&1
                SSL_HOST="127.0.0.1"
                echo -e "${green}✓ ผูก Panel กับ 127.0.0.1 เท่านั้น ตอนนี้ไม่สามารถเข้าถึงได้จากอินเทอร์เน็ตสาธารณะ${plain}"
                echo ""
                echo -e "${green}การทำ SSH Port Forwarding — เปิด Panel จากเครื่องของคุณผ่าน:${plain}"
                echo -e "  คำสั่ง SSH มาตรฐาน:"
                echo -e "  ${yellow}ssh -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  หากใช้ SSH key:"
                echo -e "  ${yellow}ssh -i <sshkeypath> -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  จากนั้นเปิดในเบราว์เซอร์ของคุณ:"
                echo -e "  ${yellow}http://localhost:2222/${web_base_path}${plain}"
                echo ""
                echo -e "${yellow}ทางเลือกอื่น: ชี้ reverse proxy (nginx/Caddy) ไปที่ 127.0.0.1:${panel_port} เพื่อจัดการ TLS${plain}"
            else
                echo -e "${yellow}Panel จะฟังพอร์ตบนทุกอินเทอร์เฟซผ่าน HTTP ธรรมดา โปรดแน่ใจว่ามีระบบอื่นจัดการ TLS อยู่ด้านหน้า${plain}"
            fi

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            echo -e "${green}✓ ข้ามการตั้งค่า SSL แล้ว${plain}"
            ;;
        *)
            echo -e "${red}ตัวเลือกไม่ถูกต้อง ข้ามการตั้งค่า SSL${plain}"
            SSL_HOST="${server_ip}"
            ;;
    esac
}

config_after_update() {
    local panel_needs_restart=0

    echo -e "${yellow}การตั้งค่า x-ui:${plain}"
    ${xui_folder}/x-ui setting -show true
    ${xui_folder}/x-ui migrate

    local existing_cert=$(${xui_folder}/x-ui setting -getCert true 2> /dev/null | grep 'cert:' | awk -F': ' '{print $2}' | tr -d '[:space:]')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}' | sed 's#^/##')

    local URL_lists=(
        "https://api4.ipify.org"
        "https://ipv4.icanhazip.com"
        "https://v4.api.ipinfo.io/ip"
        "https://ipv4.myexternalip.com/raw"
        "https://4.ident.me"
        "https://check-host.net/ip"
    )
    local server_ip=""
    for ip_address in "${URL_lists[@]}"; do
        local response=$(curl -s -w "\n%{http_code}" --max-time 3 "${ip_address}" 2> /dev/null)
        local http_code=$(echo "$response" | tail -n1)
        local ip_result=$(echo "$response" | head -n-1 | tr -d '[:space:]"')
        if [[ "${http_code}" == "200" && "${ip_result}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            server_ip="${ip_result}"
            break
        fi
    done

    if [[ -z "$server_ip" ]]; then
        echo -e "${yellow}ไม่สามารถตรวจหา IP ของเซิร์ฟเวอร์จากผู้ให้บริการใดๆ ได้อัตโนมัติ${plain}"
        while [[ -z "$server_ip" ]]; do
            read -rp "โปรดป้อนที่อยู่ IPv4 สาธารณะของเซิร์ฟเวอร์ของคุณ: " server_ip
            server_ip="${server_ip// /}"
            if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${red}IPv4 ไม่ถูกต้อง โปรดลองอีกครั้ง${plain}"
                server_ip=""
            fi
        done
    fi

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        echo -e "${yellow}WebBasePath หายไปหรือสั้นเกินไป กำลังสร้างใหม่...${plain}"
        local config_webBasePath=$(gen_random_string 18)
        ${xui_folder}/x-ui setting -webBasePath "${config_webBasePath}"
        existing_webBasePath="${config_webBasePath}"
        panel_needs_restart=1
        echo -e "${green}WebBasePath ใหม่: ${config_webBasePath}${plain}"
    fi

    if [[ -z "$existing_cert" ]]; then
        echo ""
        echo -e "${red}═══════════════════════════════════════════${plain}"
        echo -e "${red}      ⚠ ไม่พบใบรับรอง SSL ⚠     ${plain}"
        echo -e "${red}═══════════════════════════════════════════${plain}"
        echo -e "${yellow}เพื่อความปลอดภัย ใบรับรอง SSL เป็นสิ่งจำเป็นสำหรับทุก Panel${plain}"
        echo -e "${yellow}ตอนนี้ Let's Encrypt รองรับทั้งโดเมนและที่อยู่ IP แล้ว!${plain}"
        echo ""

        prompt_and_setup_ssl "${existing_port}" "${existing_webBasePath}" "${server_ip}"

        echo ""
        echo -e "${green}═══════════════════════════════════════════${plain}"
        echo -e "${green}     ข้อมูลการเข้าถึง Panel              ${plain}"
        echo -e "${green}═══════════════════════════════════════════${plain}"
        echo -e "${green}URL การเข้าถึง: https://${SSL_HOST}:${existing_port}/${existing_webBasePath}${plain}"
        echo -e "${green}═══════════════════════════════════════════${plain}"
        echo -e "${yellow}⚠ ใบรับรอง SSL: เปิดใช้งานและกำหนดค่าแล้ว${plain}"
    else
        echo -e "${green}กำหนดค่าใบรับรอง SSL เรียบร้อยแล้ว${plain}"
        local cert_domain=$(basename "$(dirname "$existing_cert")")
        echo ""
        echo -e "${green}═══════════════════════════════════════════${plain}"
        echo -e "${green}     ข้อมูลการเข้าถึง Panel              ${plain}"
        echo -e "${green}═══════════════════════════════════════════${plain}"
        echo -e "${green}URL การเข้าถึง: https://${cert_domain}:${existing_port}/${existing_webBasePath}${plain}"
        echo -e "${green}═══════════════════════════════════════════${plain}"
    fi

    if [[ "$panel_needs_restart" -eq 1 ]]; then
        echo -e "${yellow}กำลังรีสตาร์ท Panel เพื่อใช้ web base path ใหม่...${plain}"
        systemctl restart x-ui 2> /dev/null || rc-service x-ui restart 2> /dev/null
    fi
}

setup_fail2ban() {
    if [[ -n "${XUI_ENABLE_FAIL2BAN+x}" && "${XUI_ENABLE_FAIL2BAN}" != "true" ]]; then
        echo -e "${yellow}XUI_ENABLE_FAIL2BAN=${XUI_ENABLE_FAIL2BAN}, ข้ามการตั้งค่า Fail2ban อัตโนมัติ${plain}"
        return 0
    fi

    if [[ ! -x /usr/bin/x-ui ]]; then
        echo -e "${yellow}ไม่พบ x-ui CLI ข้ามการตั้งค่า Fail2ban อัตโนมัติ${plain}"
        return 0
    fi

    echo -e "${green}กำลังตั้งค่า Fail2ban สำหรับฟีเจอร์จำกัด IP (IP Limit)...${plain}"
    if /usr/bin/x-ui setup-fail2ban; then
        echo -e "${green}ตั้งค่า Fail2ban เสร็จสมบูรณ์${plain}"
    else
        echo -e "${yellow}การตั้งค่า Fail2ban ยังไม่เสร็จสิ้น ฟีเจอร์จำกัด IP จะถูกปิดใช้งานจนกว่าคุณจะรัน 'x-ui' และเปิดเมนูจำกัด IP ดำเนินการต่อ...${plain}"
    fi
    return 0
}

_install_xui_service_unit() {
    local source="$1"
    local source_is_url="$2"
    local dest="${xui_service}/x-ui.service"
    local temp_file="${dest}.tmp.$$"

    rm -f "$temp_file"
    if [[ "$source_is_url" == "true" ]]; then
        ${curl_bin} -fLRo "$temp_file" "$source" > /dev/null 2>&1
    else
        cp -f "$source" "$temp_file" > /dev/null 2>&1
    fi
    if [[ $? -ne 0 ]]; then
        rm -f "$temp_file"
        return 1
    fi
    if [[ ! -s "$temp_file" ]]; then
        rm -f "$temp_file"
        return 1
    fi
    mv -f "$temp_file" "$dest"
    if [[ $? -ne 0 ]]; then
        rm -f "$temp_file"
        return 1
    fi
    return 0
}

update_x-ui() {
    cd ${xui_folder%/x-ui}/

    load_xui_env

    if [ -f "${xui_folder}/x-ui" ]; then
        current_xui_version=$(${xui_folder}/x-ui -v)
        echo -e "${green}เวอร์ชัน x-ui ปัจจุบัน: ${current_xui_version}${plain}"
    else
        _fail "ข้อผิดพลาด: เวอร์ชัน x-ui ปัจจุบัน: ไม่ทราบ"
    fi

    echo -e "${green}กำลังดาวน์โหลด x-ui เวอร์ชันใหม่...${plain}"

    if [[ -n "${XUI_UPDATE_TAG}" ]]; then
        tag_version="${XUI_UPDATE_TAG}"
        echo -e "${green}ใช้แท็กอัปเดต: ${tag_version}${plain}"
    else
        tag_version=$(${curl_bin} -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" 2> /dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            _fail "ข้อผิดพลาด: ไม่สามารถดึงข้อมูลเวอร์ชัน x-ui ได้ อาจเนื่องมาจากข้อจำกัดของ GitHub API โปรดลองอีกครั้งภายหลัง"
        fi
    fi
    echo -e "ได้รับเวอร์ชันล่าสุดของ x-ui: ${tag_version}, เริ่มการติดตั้ง..."
    ${curl_bin} -fLRo ${xui_folder}-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz 2> /dev/null
    if [[ $? -ne 0 ]]; then
        _fail "ข้อผิดพลาด: ดาวน์โหลด x-ui ไม่สำเร็จ โปรดตรวจสอบให้แน่ใจว่าเซิร์ฟเวอร์ของคุณสามารถเข้าถึง GitHub ได้"
    fi
    if [[ ! -s ${xui_folder}-linux-$(arch).tar.gz ]]; then
        rm ${xui_folder}-linux-$(arch).tar.gz -f > /dev/null 2>&1
        _fail "ข้อผิดพลาด: ไฟล์บีบอัด x-ui ที่ดาวน์โหลดมาว่างเปล่า โปรดตรวจสอบให้แน่ใจว่าเซิร์ฟเวอร์ของคุณสามารถเข้าถึง GitHub ได้"
    fi

    if [[ -e ${xui_folder}/ ]]; then
        echo -e "${green}กำลังหยุดการทำงาน x-ui...${plain}"
        if [[ $release == "alpine" ]]; then
            if [ -f "/etc/init.d/x-ui" ]; then
                rc-service x-ui stop > /dev/null 2>&1
                rc-update del x-ui > /dev/null 2>&1
                echo -e "${green}กำลังลบหน่วยบริการ (service unit) เวอร์ชันเก่า...${plain}"
                rm -f /etc/init.d/x-ui > /dev/null 2>&1
            else
                rm x-ui-linux-$(arch).tar.gz -f > /dev/null 2>&1
                _fail "ข้อผิดพลาด: ไม่ได้ติดตั้งหน่วยบริการ x-ui"
            fi
        else
            if [ -f "${xui_service}/x-ui.service" ]; then
                systemctl stop x-ui > /dev/null 2>&1
                systemctl disable x-ui > /dev/null 2>&1
                echo -e "${green}กำลังลบ systemd unit เวอร์ชันเก่า...${plain}"
                rm ${xui_service}/x-ui.service -f > /dev/null 2>&1
                systemctl daemon-reload > /dev/null 2>&1
            else
                rm x-ui-linux-$(arch).tar.gz -f > /dev/null 2>&1
                _fail "ข้อผิดพลาด: ไม่ได้ติดตั้ง x-ui systemd unit"
            fi
        fi
        pkill -f 'mtg-linux-[^ ]* run ' > /dev/null 2>&1 || true
        echo -e "${green}กำลังลบ x-ui เวอร์ชันเก่า...${plain}"
        rm ${xui_folder} -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui.service -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui.service.debian -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui.service.arch -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui.service.rhel -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui -f > /dev/null 2>&1
        rm ${xui_folder}/x-ui.sh -f > /dev/null 2>&1
        echo -e "${green}กำลังลบ mtg เวอร์ชันเก่า...${plain}"
        rm ${xui_folder}/bin/mtg-linux-$(arch) -f > /dev/null 2>&1
        echo -e "${green}กำลังลบ xray เวอร์ชันเก่า...${plain}"
        rm ${xui_folder}/bin/xray-linux-$(arch) -f > /dev/null 2>&1
        echo -e "${green}กำลังลบไฟล์ README และ LICENSE เก่า...${plain}"
        rm ${xui_folder}/bin/README.md -f > /dev/null 2>&1
        rm ${xui_folder}/bin/LICENSE -f > /dev/null 2>&1
    else
        rm x-ui-linux-$(arch).tar.gz -f > /dev/null 2>&1
        _fail "ข้อผิดพลาด: ยังไม่ได้ติดตั้ง x-ui"
    fi

    echo -e "${green}กำลังติดตั้ง x-ui เวอร์ชันใหม่...${plain}"
    tar zxvf x-ui-linux-$(arch).tar.gz > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        rm x-ui-linux-$(arch).tar.gz -f > /dev/null 2>&1
        _fail "ข้อผิดพลาด: แยกไฟล์บีบอัด x-ui ไม่สำเร็จ — การติดตั้งก่อนหน้านี้ถูกลบไปแล้ว Panel จะไม่ทำงานจนกว่าจะแก้ไขปัญหานี้ได้ โปรดลองอัปเดตใหม่อีกครั้ง"
    fi
    rm x-ui-linux-$(arch).tar.gz -f > /dev/null 2>&1
    cd x-ui > /dev/null 2>&1
    if [[ $? -ne 0 || ! -s x-ui ]]; then
        _fail "ข้อผิดพลาด: ไฟล์บีบอัด x-ui ที่แยกออกมาไม่มีไบนารี x-ui — การติดตั้งก่อนหน้านี้ถูกลบไปแล้ว Panel จะไม่ทำงานจนกว่าจะแก้ไขปัญหานี้ได้ โปรดลองอัปเดตใหม่อีกครั้ง"
    fi
    chmod +x x-ui > /dev/null 2>&1

    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm32 > /dev/null 2>&1
        chmod +x bin/xray-linux-arm32 > /dev/null 2>&1
        if [[ -f bin/mtg-linux-$(arch) ]]; then
            mv bin/mtg-linux-$(arch) bin/mtg-linux-arm > /dev/null 2>&1
            chmod +x bin/mtg-linux-arm > /dev/null 2>&1
        fi
    fi

    chmod +x x-ui bin/xray-linux-$(arch) > /dev/null 2>&1
    if [[ -f bin/mtg-linux-arm ]]; then
        chmod +x bin/mtg-linux-arm > /dev/null 2>&1
    elif [[ -f bin/mtg-linux-$(arch) ]]; then
        chmod +x bin/mtg-linux-$(arch) > /dev/null 2>&1
    fi

    echo -e "${green}กำลังดาวน์โหลดและติดตั้งสคริปต์ x-ui.sh...${plain}"
    local xui_script_temp="/usr/bin/x-ui-temp.$$"
    rm -f "${xui_script_temp}"
    ${curl_bin} -fLRo "${xui_script_temp}" https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        rm -f "${xui_script_temp}"
        _fail "ข้อผิดพลาด: ดาวน์โหลดสคริปต์ x-ui.sh ไม่สำเร็จ โปรดตรวจสอบว่าเซิร์ฟเวอร์ของคุณเข้าถึง GitHub ได้"
    fi
    if [[ ! -s "${xui_script_temp}" ]]; then
        rm -f "${xui_script_temp}"
        _fail "ข้อผิดพลาด: สคริปต์ x-ui.sh ที่ดาวน์โหลดมาว่างเปล่า โปรดตรวจสอบว่าเซิร์ฟเวอร์ของคุณเข้าถึง GitHub ได้"
    fi
    mv -f "${xui_script_temp}" /usr/bin/x-ui
    if [[ $? -ne 0 ]]; then
        rm -f "${xui_script_temp}"
        _fail "ข้อผิดพลาด: ติดตั้งสคริปต์ x-ui.sh ไม่สำเร็จ"
    fi

    chmod +x ${xui_folder}/x-ui.sh > /dev/null 2>&1
    chmod +x /usr/bin/x-ui > /dev/null 2>&1
    mkdir -p /var/log/x-ui > /dev/null 2>&1

    echo -e "${green}กำลังเปลี่ยนเจ้าของไฟล์ (owner)...${plain}"
    chown -R root:root ${xui_folder} > /dev/null 2>&1

    if [ -f "${xui_folder}/bin/config.json" ]; then
        echo -e "${green}กำลังเปลี่ยนสิทธิ์ไฟล์กำหนดค่า (config)...${plain}"
        chmod 640 ${xui_folder}/bin/config.json > /dev/null 2>&1
    fi

    if [[ $release == "alpine" ]]; then
        echo -e "${green}กำลังดาวน์โหลดและติดตั้ง startup unit x-ui.rc...${plain}"
        xui_rc_temp="/etc/init.d/x-ui.tmp.$$"
        rm -f "${xui_rc_temp}"
        ${curl_bin} -fLRo "${xui_rc_temp}" https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.rc > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            rm -f "${xui_rc_temp}"
            _fail "ข้อผิดพลาด: ดาวน์โหลด startup unit x-ui.rc ไม่สำเร็จ โปรดตรวจสอบว่าเซิร์ฟเวอร์ของคุณเข้าถึง GitHub ได้"
        fi
        if [[ ! -s "${xui_rc_temp}" ]]; then
            rm -f "${xui_rc_temp}"
            _fail "ข้อผิดพลาด: startup unit x-ui.rc ที่ดาวน์โหลดมาว่างเปล่า โปรดตรวจสอบว่าเซิร์ฟเวอร์ของคุณเข้าถึง GitHub ได้"
        fi
        mv -f "${xui_rc_temp}" /etc/init.d/x-ui
        if [[ $? -ne 0 ]]; then
            rm -f "${xui_rc_temp}"
            _fail "ข้อผิดพลาด: ติดตั้ง startup unit x-ui.rc ไม่สำเร็จ"
        fi
        chmod +x /etc/init.d/x-ui > /dev/null 2>&1
        chown root:root /etc/init.d/x-ui > /dev/null 2>&1
        rc-update add x-ui > /dev/null 2>&1
        rc-service x-ui start > /dev/null 2>&1
    else
        if [ -f "x-ui.service" ]; then
            echo -e "${green}กำลังติดตั้ง systemd unit...${plain}"
            if ! _install_xui_service_unit "x-ui.service" "false"; then
                echo -e "${red}คัดลอก x-ui.service ไม่สำเร็จ${plain}"
                exit 1
            fi
        else
            service_installed=false
            case "${release}" in
                ubuntu | debian | armbian)
                    if [ -f "x-ui.service.debian" ]; then
                        echo -e "${green}กำลังติดตั้ง systemd unit แบบ Debian...${plain}"
                        if _install_xui_service_unit "x-ui.service.debian" "false"; then
                            service_installed=true
                        fi
                    fi
                    ;;
                arch | manjaro | parch)
                    if [ -f "x-ui.service.arch" ]; then
                        echo -e "${green}กำลังติดตั้ง systemd unit แบบ Arch...${plain}"
                        if _install_xui_service_unit "x-ui.service.arch" "false"; then
                            service_installed=true
                        fi
                    fi
                    ;;
                *)
                    if [ -f "x-ui.service.rhel" ]; then
                        echo -e "${green}กำลังติดตั้ง systemd unit แบบ RHEL...${plain}"
                        if _install_xui_service_unit "x-ui.service.rhel" "false"; then
                            service_installed=true
                        fi
                    fi
                    ;;
            esac

            if [ "$service_installed" = false ]; then
                echo -e "${yellow}ไม่พบไฟล์ service ใน tar.gz กำลังดาวน์โหลดจาก GitHub...${plain}"
                case "${release}" in
                    ubuntu | debian | armbian)
                        service_unit_url="https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.debian"
                        ;;
                    arch | manjaro | parch)
                        service_unit_url="https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.arch"
                        ;;
                    *)
                        service_unit_url="https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.rhel"
                        ;;
                esac

                if ! _install_xui_service_unit "$service_unit_url" "true"; then
                    echo -e "${red}ติดตั้ง x-ui.service จาก GitHub ไม่สำเร็จ${plain}"
                    exit 1
                fi
            fi
        fi
        chown root:root ${xui_service}/x-ui.service > /dev/null 2>&1
        chmod 644 ${xui_service}/x-ui.service > /dev/null 2>&1
        systemctl daemon-reload > /dev/null 2>&1
        systemctl enable x-ui > /dev/null 2>&1
        systemctl start x-ui > /dev/null 2>&1
    fi

    config_after_update

    setup_fail2ban

    echo -e "${green}อัปเดต x-ui ${tag_version}${plain} เสร็จสิ้น กำลังทำงานอยู่..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}การใช้งานเมนูควบคุม x-ui (คำสั่งย่อย):${plain}                │
│                                                       │
│  ${blue}x-ui${plain}              - สคริปต์จัดการผู้ดูแลระบบ         │
│  ${blue}x-ui start${plain}        - เริ่มการทำงาน                  │
│  ${blue}x-ui stop${plain}         - หยุดการทำงาน                   │
│  ${blue}x-ui restart${plain}      - เริ่มการทำงานใหม่              │
│  ${blue}x-ui status${plain}       - สถานะปัจจุบัน                  │
│  ${blue}x-ui settings${plain}     - การตั้งค่าปัจจุบัน              │
│  ${blue}x-ui enable${plain}       - เปิดใช้งานเริ่มอัตโนมัติเมื่อเปิดเครื่อง │
│  ${blue}x-ui disable${plain}      - ปิดใช้งานเริ่มอัตโนมัติเมื่อเปิดเครื่อง  │
│  ${blue}x-ui log${plain}          - ตรวจสอบบันทึก (Logs)           │
│  ${blue}x-ui banlog${plain}       - ตรวจสอบบันทึกการแบนของ Fail2ban   │
│  ${blue}x-ui update${plain}       - อัปเดต                         │
│  ${blue}x-ui legacy${plain}       - เวอร์ชันดั้งเดิม                 │
│  ${blue}x-ui install${plain}      - ติดตั้ง                         │
│  ${blue}x-ui uninstall${plain}    - ถอนการติดตั้ง                   │
└───────────────────────────────────────────────────────┘"
}

echo -e "${green}กำลังทำงาน...${plain}"
install_base
update_x-ui $1
