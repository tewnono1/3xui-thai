#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set_local
release=""
os_version=""

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}The system version is not detected, please contact the script author!${plain}"
    exit 1
fi

os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F= '/^VERSION_ID=/ {print $2}' /etc/os-release | tr -d '"' | tr -d '"')
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F= '/^DISTRIB_RELEASE=/ {print $2}' /etc/lsb-release | tr -d '"' | tr -d '"')
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher!${plain}"
        exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}"
        exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    os_version_major=$(echo "$os_version" | cut -d. -f1)
    if [[ ${os_version_major} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}"
        exit 1
    fi
fi

confirm() {
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [default $2]: " temp
        ifa=""
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y
    else
        apt update -y
        apt install wget curl tar cron socat -y
    fi
}

# ---------------------------------------------------------
# ส่วนนี้คือจุดที่คุณสามารถปรับเปลี่ยนข้อความภาษาอังกฤษ 
# ในหน้าจอเมนู (Menu) ให้เป็นภาษาไทยตามต้องการได้เลยครับ
# ---------------------------------------------------------

echo -e "${green}กำลังเริ่มคัดลอกและติดตั้ง...${plain}"
install_base
