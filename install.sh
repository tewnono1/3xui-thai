กฎ#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"

# ตรวจสอบสิทธิ์ root
[[ $EUID -ne 0 ]] && echo -e "${red}ข้อผิดพลาดร้ายแรง: ${plain} กรุณารันสคริปต์นี้ด้วยสิทธิ์ root \n " && exit 1

# ตรวจสอบ OS และกำหนดตัวแปร release
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "ไม่สามารถตรวจสอบระบบปฏิบัติการ OS ได้ กรุณาติดต่อผู้พัฒนา!" >&2
    exit 1
fi
echo "ระบบปฏิบัติการ (OS) คือ: $release"

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${green}สถาปัตยกรรม CPU ไม่รองรับ! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "สถาปัตยกรรม: $(arch)"

# โหมด Non-interactive: ทำงานอัตโนมัติผ่าน XUI_NONINTERACTIVE=1 หรือเมื่อไม่มี TTY
if [[ "${XUI_NONINTERACTIVE:-0}" == "1" ]] || [[ ! -t 0 ]]; then
    NONINTERACTIVE=1
else
    NONINTERACTIVE=0
fi
export NONINTERACTIVE

# ฟังก์ชันช่วยเหลืออย่างง่าย
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

install_base() {
    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf makecache -y && dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum makecache -y && yum install -y cronie curl tar tzdata socat ca-certificates openssl
            else
                dnf makecache -y && dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl
            fi
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm cronie curl tar tzdata socat ca-certificates openssl
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper refresh && zypper -q install -y cron curl tar timezone socat ca-certificates openssl
            ;;
        alpine)
            apk update && apk add dcron curl tar tzdata socat ca-certificates openssl
            ;;
        *)
            apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl
            ;;
    esac
}

gen_random_string() {
    local length="$1"
    openssl rand -base64 $((length * 2)) \
        | tr -dc 'a-zA-Z0-9' \
        | head -c "$length"
}

prompt_or_default() {
    local __var="$1" __prompt="$2" __default="$3" __env="${4:-$1}"
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        printf -v "$__var" '%s' "${!__env:-$__default}"
    else
        # shellcheck disable=SC2229
        read -rp "$__prompt" "$__var"
    fi
}

write_install_result() {
    local u="$1" p="$2" port="$3" wbp="$4" scheme="$5" host="$6" token="$7" dbtype="$8"
    local result_file="/etc/x-ui/install-result.env"
    local url_host="${host:-SERVER_IP_UNKNOWN}"
    install -d -m 755 /etc/x-ui 2> /dev/null
    local prev_umask
    prev_umask=$(umask)
    umask 077
    if ! {
        printf 'XUI_USERNAME=%q\n' "$u"
        printf 'XUI_PASSWORD=%q\n' "$p"
        printf 'XUI_PANEL_PORT=%q\n' "$port"
        printf 'XUI_WEB_BASE_PATH=%q\n' "$wbp"
        printf 'XUI_ACCESS_URL=%q\n' "${scheme}://${url_host}:${port}/${wbp}"
        printf 'XUI_API_TOKEN=%q\n' "$token"
        printf 'XUI_DB_TYPE=%q\n' "$dbtype"
    } > "$result_file"; then
        umask "$prev_umask"
        echo -e "${yellow}คำเตือน: ไม่สามารถเขียนไฟล์ ${result_file} ได้${plain}" >&2
        return 1
    fi
    umask "$prev_umask"
    chmod 600 "$result_file" 2> /dev/null
    chown root:root "$result_file" 2> /dev/null || true
    echo -e "${green}บันทึกผลลัพธ์การติดตั้งลงใน ${result_file} เรียบร้อยแล้ว (สิทธิ์ 600)${plain}"
}

pg_ensure_hba_password_auth() {
    local pg_db="$1"
    local hba_file
    hba_file=$(sudo -u postgres psql -tAc 'SHOW hba_file' 2> /dev/null | tr -d '[:space:]')
    [[ -n "${hba_file}" && -f "${hba_file}" ]] || return 0
    grep -Eq "^host[[:space:]]+${pg_db}[[:space:]]" "${hba_file}" && return 0
    local tmp
    tmp=$(mktemp) || return 1
    {
        echo "# เพิ่มโดย 3x-ui: อนุญาตให้ล็อกอินด้วยรหัสผ่านสำหรับฐานข้อมูลพาเนล"
        echo "host    ${pg_db}    all    127.0.0.1/32    md5"
        echo "host    ${pg_db}    all    ::1/128         md5"
        cat "${hba_file}"
    } > "${tmp}" || {
        rm -f "${tmp}"
        return 1
    }
    cat "${tmp}" > "${hba_file}" || {
        rm -f "${tmp}"
        return 1
    }
    rm -f "${tmp}"
    sudo -u postgres psql -tAc 'SELECT pg_reload_conf()' > /dev/null 2>&1 || true
}

install_postgres_local() {
    local pg_user pg_pass
    pg_pass=$(gen_random_string 24)
    local pg_db="xui"
    local pg_host="127.0.0.1"
    local pg_port="5432"

    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update >&2 && apt-get install -y -q postgresql >&2 || return 1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum install -y postgresql-server postgresql-contrib >&2 || return 1
            else
                dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            fi
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm postgresql >&2 || return 1
            if [[ ! -f /var/lib/postgres/data/PG_VERSION ]]; then
                sudo -u postgres initdb -D /var/lib/postgres/data >&2 || return 1
            fi
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper -q install -y postgresql-server postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
                install -d -o postgres -g postgres -m 700 /var/lib/pgsql/data >&2 || return 1
                su - postgres -c "initdb -D /var/lib/pgsql/data" >&2 || return 1
            fi
            ;;
        alpine)
            apk add --no-cache postgresql postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/postgresql/data/PG_VERSION ]]; then
                /etc/init.d/postgresql setup >&2 || return 1
            fi
            rc-update add postgresql default >&2 2> /dev/null || true
            rc-service postgresql start >&2 || return 1
            ;;
        *)
            echo -e "${red}ไม่รองรับลีนุกซ์ดิสโทรนี้สำหรับการติดตั้ง PostgreSQL อัตโนมัติ: ${release}${plain}" >&2
            return 1
            ;;
    esac

    if [[ "${release}" != "alpine" ]]; then
        systemctl enable --now postgresql >&2 || return 1
    fi

    local i
    for i in 1 2 3 4 5; do
        sudo -u postgres psql -tAc 'SELECT 1' > /dev/null 2>&1 && break
        sleep 1
    done

    local existing_owner=""
    existing_owner=$(sudo -u postgres psql -tAc \
        "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='${pg_db}'" 2> /dev/null \
        | tr -d '[:space:]')
    if [[ -n "${existing_owner}" && "${existing_owner}" != "postgres" ]]; then
        pg_user="${existing_owner}"
    else
        pg_user=$(gen_random_string 8)
    fi

    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${pg_user}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE USER \"${pg_user}\" WITH PASSWORD '${pg_pass}';" >&2 || return 1

    sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${pg_db}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE DATABASE \"${pg_db}\" OWNER \"${pg_user}\";" >&2 || return 1

    sudo -u postgres psql -c "ALTER USER \"${pg_user}\" WITH PASSWORD '${pg_pass}';" >&2 || return 1

    pg_ensure_hba_password_auth "${pg_db}" \
        || echo -e "${yellow}คำเตือน: ไม่สามารถอัปเดตไฟล์ pg_hba.conf ได้ PostgreSQL อาจปฏิเสธการเชื่อมต่อ TCP ของพาเนล${plain}" >&2

    local pg_pass_enc
    pg_pass_enc=$(printf '%s' "${pg_pass}" | sed -e 's/%/%25/g' -e 's/:/%3A/g' -e 's/@/%40/g' -e 's|/|%2F|g' -e 's/?/%3F/g' -e 's/#/%23/g')

    if [[ -n "${PG_CRED_FILE:-}" ]]; then
        local prev_umask
        prev_umask=$(umask)
        umask 077
        if ! cat > "${PG_CRED_FILE}" << EOF; then
PG_USER=${pg_user}
PG_PASS=${pg_pass}
PG_HOST=${pg_host}
PG_PORT=${pg_port}
PG_DB=${pg_db}
EOF
            umask "${prev_umask}"
            echo -e "${red}ไม่สามารถเขียนข้อมูลรับรอง PostgreSQL ลงใน ${PG_CRED_FILE} ได้${plain}" >&2
            return 1
        fi
        umask "${prev_umask}"
    fi

    echo "postgres://${pg_user}:${pg_pass_enc}@${pg_host}:${pg_port}/${pg_db}?sslmode=disable"
    return 0
}

ensure_pg_client() {
    if command -v pg_dump > /dev/null 2>&1 && command -v pg_restore > /dev/null 2>&1; then
        return 0
    fi
    echo -e "${yellow}กำลังติดตั้งเครื่องมือไคลเอนต์ PostgreSQL (pg_dump/pg_restore) สำหรับการสำรองข้อมูลในพาเนล...${plain}" >&2
    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update >&2 && apt-get install -y -q postgresql-client >&2 || return 1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf install -y -q postgresql >&2 || return 1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum install -y postgresql >&2 || return 1
            else
                dnf install -y -q postgresql >&2 || return 1
            fi
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm postgresql >&2 || return 1
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper -q install -y postgresql >&2 || return 1
            ;;
        alpine)
            apk add --no-cache postgresql-client >&2 || return 1
            ;;
        *)
            return 1
            ;;
    esac
    command -v pg_dump > /dev/null 2>&1 && command -v pg_restore > /dev/null 2>&1
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
            echo -e "${yellow}ติดตั้ง acme.sh ไม่สำเร็จ ข้ามการตั้งค่า SSL${plain}"
            return 1
        fi
    fi

    local certPath="/root/cert/${domain}"
    mkdir -p "$certPath"

    echo -e "${green}กำลังออกใบรับรอง SSL สำหรับโดเมน ${domain}...${plain}"
    echo -e "${yellow}หมายเหตุ: พอร์ต 80 จะต้องเปิดและสามารถเข้าถึงได้จากอินเทอร์เน็ต${plain}"

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1
    ~/.acme.sh/acme.sh --issue -d ${domain} $(acme_listen_flag) --standalone --httpport 80 --force

    if [ $? -ne 0 ]; then
        echo -e "${yellow}ออกใบรับรองสำหรับ ${domain} ไม่สำเร็จ${plain}"
        echo -e "${yellow}โปรดตรวจสอบให้แน่ใจว่าพอร์ต 80 เปิดอยู่ แล้วลองใหม่อีกครั้งด้วยคำสั่ง: x-ui${plain}"
        rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc 2> /dev/null
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
    echo -e "${yellow}หมายเหตุ: ใบรับรอง IP มีอายุใช้งานประมาณ 6 วัน และจะต่ออายุให้อัตโนมัติ${plain}"

    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}ติดตั้ง acme.sh ไม่สำเร็จ${plain}"
            return 1
        fi
    fi

    if [[ -z "$ipv4" ]] || ! is_ipv4 "$ipv4"; then
        echo -e "${red}ที่อยู่ IPv4 ไม่ถูกต้องหรือหายไป: $ipv4${plain}"
        return 1
    fi

    local certDir="/root/cert/ip"
    mkdir -p "$certDir"

    local domain_args="-d ${ipv4}"
    if [[ -n "$ipv6" ]] && is_ipv6 "$ipv6"; then
        domain_args="${domain_args} -d ${ipv6}"
        echo -e "${green}รวมที่อยู่ IPv6 ด้วย: ${ipv6}${plain}"
    fi

    local reloadCmd="systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true"

    local WebPort=""
    prompt_or_default WebPort "พอร์ตที่ต้องการใช้สำหรับตัวรับฟัง ACME HTTP-01 (ค่าเริ่มต้น 80): " "80" XUI_ACME_HTTP_PORT
    WebPort="${WebPort:-80}"

    while true; do
        if is_port_in_use "${WebPort}"; then
            echo -e "${yellow}พอร์ต ${WebPort} กำลังถูกใช้งานอยู่${plain}"
            if [[ "$NONINTERACTIVE" == "1" ]]; then
                return 1
            fi
            local alt_port=""
            read -rp "ป้อนพอร์ตอื่นสำหรับ acme.sh (เว้นว่างไว้เพื่อยกเลิก): " alt_port
            alt_port="${alt_port// /}"
            [[ -z "${alt_port}" ]] && return 1
            WebPort="${alt_port}"
        else
            break
        fi
    done

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1
    [[ -n "${XUI_ACME_EMAIL:-}" ]] && ~/.acme.sh/acme.sh --register-account -m "${XUI_ACME_EMAIL}" > /dev/null 2>&1

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
        return 1
    fi

    ~/.acme.sh/acme.sh --installcert --force -d ${ipv4} \
        --key-file "${certDir}/privkey.pem" \
        --fullchain-file "${certDir}/fullchain.pem" \
        --reloadcmd "${reloadCmd}" 2>&1 || true

    if [[ ! -f "${certDir}/fullchain.pem" || ! -f "${certDir}/privkey.pem" ]]; then
        echo -e "${red}ไม่พบไฟล์ใบรับรองหลังจากการติดตั้ง${plain}"
        return 1
    fi

    chmod 600 ${certDir}/privkey.pem 2> /dev/null
    chmod 644 ${certDir}/fullchain.pem 2> /dev/null
    ${xui_folder}/x-ui cert -webCert "${certDir}/fullchain.pem" -webCertKey "${certDir}/privkey.pem"

    echo -e "${green}ติดตั้งและกำหนดค่าใบรับรอง IP สำเร็จแล้ว!${plain}"
    return 0
}

ssl_cert_issue() {
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep 'webBasePath:' | awk -F': ' '{print $2}' | tr -d '[:space:]' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep 'port:' | awk -F': ' '{print $2}' | tr -d '[:space:]')

    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        cd ~ || return 1
        curl -s https://get.acme.sh | sh
    fi

    local domain=""
    if [[ "$NONINTERACTIVE" == "1" ]]; then
        domain="${XUI_DOMAIN// /}"
    else
        while true; do
            read -rp "กรุณากรอกชื่อโดเมนของคุณ: " domain
            domain="${domain// /}"
            [[ -n "$domain" ]] && is_domain "$domain" && break
            echo -e "${red}รูปแบบโดเมนไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง${plain}"
        done
    fi
    SSL_ISSUED_DOMAIN="${domain}"

    local cert_exists=0
    if ~/.acme.sh/acme.sh --list 2> /dev/null | awk '{print $1}' | grep -Fxq "${domain}"; then
        if [[ -s ~/.acme.sh/${domain}_ecc/fullchain.cer && -s ~/.acme.sh/${domain}_ecc/${domain}.key ]] || \
           [[ -s ~/.acme.sh/${domain}/fullchain.cer && -s ~/.acme.sh/${domain}/${domain}.key ]]; then
            cert_exists=1
        else
            rm -rf ~/.acme.sh/${domain} ~/.acme.sh/${domain}_ecc
        fi
    fi

    certPath="/root/cert/${domain}"
    mkdir -p "$certPath"

    local WebPort=80
    prompt_or_default WebPort "กรุณาเลือกพอร์ตที่ต้องการใช้ (ค่าเริ่มต้นคือ 80): " "80" XUI_ACME_HTTP_PORT

    systemctl stop x-ui 2> /dev/null || rc-service x-ui stop 2> /dev/null

    if [[ ${cert_exists} -eq 0 ]]; then
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force
        ~/.acme.sh/acme.sh --issue -d ${domain} $(acme_listen_flag) --standalone --httpport ${WebPort} --force
        if [ $? -ne 0 ]; then
            systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
            return 1
        fi
    fi

    local reloadCmd="systemctl restart x-ui || rc-service x-ui restart"
    ~/.acme.sh/acme.sh --installcert --force -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem --reloadcmd "${reloadCmd}" > /dev/null 2>&1

    systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
    return 0
}

prompt_and_setup_ssl() {
    local panel_port="$1"
    local web_base_path="$2"
    local server_ip="$3"
    local ssl_choice=""
    SSL_SCHEME="https"

    echo -e "${yellow}เลือกวิธีตั้งค่าใบรับรอง SSL:${plain}"
    echo -e "${green}1.${plain} Let's Encrypt สำหรับโดเมน"
    echo -e "${green}2.${plain} Let's Encrypt สำหรับที่อยู่ IP"
    echo -e "${green}3.${plain} ใบรับรอง SSL แบบกำหนดเอง (Custom)"
    echo -e "${green}4.${plain} ข้าม SSL (ใช้ HTTP เท่านั้น)"

    if [[ "$NONINTERACTIVE" == "1" ]]; then
        case "${XUI_SSL_MODE:-none}" in
            domain) ssl_choice="1" ;;
            ip) ssl_choice="2" ;;
            *) ssl_choice="4" ;;
        esac
    else
        read -rp "เลือกตัวเลือก (ค่าเริ่มต้น 2 สำหรับ IP): " ssl_choice
        ssl_choice="${ssl_choice// /}"
        [[ "$ssl_choice" != "1" && "$ssl_choice" != "3" && "$ssl_choice" != "4" ]] && ssl_choice="2"
    fi

    case "$ssl_choice" in
        1)
            ssl_cert_issue && SSL_HOST="${SSL_ISSUED_DOMAIN:-$server_ip}" || SSL_HOST="${server_ip}"
            ;;
        2)
            setup_ip_certificate "${server_ip}" "" && SSL_HOST="${server_ip}" || SSL_HOST="${server_ip}"
            ;;
        3)
            local custom_cert="" custom_key="" custom_domain=""
            read -rp "กรุณากรอกชื่อโดเมนที่ออกใบรับรองให้: " custom_domain
            read -rp "ระบุ path ของไฟล์ใบรับรอง (Certificate): " custom_cert
            read -rp "ระบุ path ของไฟล์ Private Key: " custom_key
            ${xui_folder}/x-ui cert -webCert "$custom_cert" -webCertKey "$custom_key" > /dev/null 2>&1
            SSL_HOST="${custom_domain:-$server_ip}"
            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            ;;
        4)
            SSL_SCHEME="http"
            SSL_HOST="${server_ip}"
            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            ;;
    esac
}

config_after_install() {
    local existing_hasDefaultCredential=$(${xui_folder}/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local existing_cert=$(${xui_folder}/x-ui setting -getCert true | grep 'cert:' | awk -F': ' '{print $2}' | tr -d '[:space:]')
    
    local server_ip="127.0.0.1"
    for ip_address in "https://api4.ipify.org" "https://ipv4.icanhazip.com"; do
        local response=$(curl -s -w "\n%{http_code}" --max-time 3 "${ip_address}" 2> /dev/null)
        if [[ "$(echo "$response" | tail -n1)" == "200" ]]; then
            server_ip=$(echo "$response" | head -n-1 | tr -d '[:space:]"')
            break
        fi
    done

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        local config_webBasePath="${XUI_WEB_BASE_PATH:-$(gen_random_string 18)}"
        local config_username="${XUI_USERNAME:-$(gen_random_string 10)}"
        local config_password="${XUI_PASSWORD:-$(gen_random_string 10)}"
        local config_port=$(shuf -i 1024-62000 -n 1)

        ${xui_folder}/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
        prompt_and_setup_ssl "${config_port}" "${config_webBasePath}" "${server_ip}"
        
        local config_apiToken=$(${xui_folder}/x-ui setting -getApiToken true | grep -Eo 'apiToken: .+' | awk '{print $2}')
        write_install_result "${config_username}" "${config_password}" "${config_port}" "${config_webBasePath}" "${SSL_SCHEME}" "${SSL_HOST}" "${config_apiToken}" "sqlite"
    fi

    ${xui_folder}/x-ui migrate
}

setup_fail2ban() {
    [[ -x /usr/bin/x-ui ]] && /usr/bin/x-ui setup-fail2ban > /dev/null 2>&1 || true
}

_install_xui_service_unit() {
    local source="$1"
    local source_is_url="$2"
    local dest="${xui_service}/x-ui.service"
    local temp_file="${dest}.tmp.$$"

    rm -f "$temp_file"
    if [[ "$source_is_url" == "true" ]]; then
        curl -fLRo "$temp_file" "$source" > /dev/null 2>&1
    else
        cp -f "$source" "$temp_file" > /dev/null 2>&1
    fi
    [[ $? -ne 0 || ! -s "$temp_file" ]] && { rm -f "$temp_file"; return 1; }
    mv -f "$temp_file" "$dest"
}

install_x-ui() {
    cd ${xui_folder%/x-ui}/

    tag_version=$(curl -Ls --retry 5 --connect-timeout 15 "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$tag_version" ]] && tag_version="v2.3.5"

    curl -fLR --retry 5 -o ${xui_folder}-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
    
    [[ -e ${xui_folder}/ ]] && rm ${xui_folder}/ -rf
    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f

    cd x-ui
    chmod +x x-ui x-ui.sh

    # ดึงไฟล์เมนูภาษาไทยจาก GitHub ของคุณเอง
    curl -fLRo /usr/bin/x-ui https://raw.githubusercontent.com/tewnono1/3xui-thai/refs/heads/main/x-ui.sh
    chmod +x /usr/bin/x-ui
    mkdir -p /var/log/x-ui
    
    config_after_install

    service_unit_url="https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.debian"
    _install_xui_service_unit "$service_unit_url" "true"
    
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    setup_fail2ban
    echo -e "${green}ติดตั้ง x-ui เสร็จสิ้นเรียบร้อยแล้ว!${plain}"
}

echo -e "${green}กำลังดำเนินการ...${plain}"
install_base
install_x-ui $1
