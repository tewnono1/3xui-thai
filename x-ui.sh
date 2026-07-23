#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

xui_folder="/usr/local/x-ui"

# ฟังก์ชันกดเพื่อกลับเมนู
press_enter() {
    echo
    read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
    show_menu
}

# 1. ติดตั้ง 3X-UI
menu_install() {
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
    press_enter
}

# 2. อัปเดต 3X-UI
menu_update() {
    ${xui_folder}/x-ui update 2>/dev/null || bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
    press_enter
}

# 7. เปลี่ยนชื่อผู้ใช้และรหัสผ่าน
menu_set_auth() {
    echo -e "--------------------------------------------------------"
    echo -e "${green}       ★ เปลี่ยนชื่อผู้ใช้และรหัสผ่าน ★                   ${plain}"
    echo -e "--------------------------------------------------------"
    local u="" p=""
    read -p "กรุณากรอกชื่อผู้ใช้ใหม่: " u
    read -p "กรุณากรอกรหัสผ่านใหม่: " p
    if [[ -n "$u" ]] && [[ -n "$p" ]]; then
        ${xui_folder}/x-ui setting -username "$u" -password "$p"
        echo -e "${green}เปลี่ยนข้อมูลสำเร็จ!${plain}"
    else
        echo -e "${red}ข้อมูลไม่ครบถ้วน${plain}"
    fi
    press_enter
}

# 8. รีเซ็ตเว็บเบสพาส
menu_set_wbp() {
    local wbp=""
    read -p "กรุณากรอก Web Base Path ใหม่ (เช่น panel/): " wbp
    ${xui_folder}/x-ui setting -webBasePath "$wbp"
    echo -e "${green}รีเซ็ต Web Base Path สำเร็จ!${plain}"
    press_enter
}

# 9. รีเซ็ตการตั้งค่าทั้งหมด
menu_reset_all() {
    read -p "คุณต้องการรีเซ็ตการตั้งค่าทั้งหมดใช่หรือไม่? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        ${xui_folder}/x-ui reset
        echo -e "${green}รีเซ็ตการตั้งค่าเรียบร้อยแล้ว${plain}"
    fi
    press_enter
}

# 10. เปลี่ยนพอร์ต
menu_set_port() {
    local port=""
    read -p "กรุณากรอกหมายเลขพอร์ตใหม่: " port
    if [[ -n "$port" ]]; then
        ${xui_folder}/x-ui setting -port "$port"
        echo -e "${green}เปลี่ยนพอร์ตสำเร็จ!${plain}"
    fi
    press_enter
}

# 11. ดูการตั้งค่าปัจจุบัน
menu_show_config() {
    echo -e "--------------------------------------------------------"
    echo -e "${green}       ★ การตั้งค่าปัจจุบัน ★                            ${plain}"
    echo -e "--------------------------------------------------------"
    ${xui_folder}/x-ui setting -show
    press_enter
}

# 12-16 & 18-19. จัดการ Service
menu_service() {
    local action="$1"
    case "$action" in
        start) systemctl start x-ui ;;
        stop) systemctl stop x-ui ;;
        restart) systemctl restart x-ui ;;
        restart-xray) ${xui_folder}/x-ui restart-xray ;;
        status) systemctl status x-ui ;;
        enable) systemctl enable x-ui ;;
        disable) systemctl disable x-ui ;;
    esac
    press_enter
}

# 17. จัดการ Logs
menu_logs() {
    ${xui_folder}/x-ui logs
    press_enter
}

# 20-25. ฟังก์ชันเสริมและระบบอื่นๆ (เรียกสคริปต์ต้นฉบับมาช่วยประมวลผลต่อ)
menu_advanced() {
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh)
    press_enter
}

# ฟังก์ชันแสดงเมนูหลัก
show_menu() {
    clear
    echo -e "--------------------------------------------------------"
    echo -e "${green}       ★ 3X-UI PANEL MANAGEMENT (THAI) ★                ${plain}"
    echo -e "--------------------------------------------------------"
    echo -e " 0. ออกจากสคริปต์"
    echo -e "--------------------------------------------------------"
    echo -e " 1. ติดตั้ง 3X-UI"
    echo -e " 2. อัปเดต 3X-UI"
    echo -e " 3. อัปเดตไปยังรุ่น Dev (Latest commit)"
    echo -e " 4. อัปเดตเมนู"
    echo -e " 5. ติดตั้งเวอร์ชันเก่า (Legacy Version)"
    echo -e " 6. ถอนการติดตั้ง (Uninstall)"
    echo -e "--------------------------------------------------------"
    echo -e " 7. เปลี่ยนชื่อผู้ใช้และรหัสผ่าน"
    echo -e " 8. รีเซ็ตเว็บเบสพาส (Web Base Path)"
    echo -e " 9. รีเซ็ตการตั้งค่าทั้งหมด"
    echo -e " 10. เปลี่ยนพอร์ต (Change Port)"
    echo -e " 11. ดูการตั้งค่าปัจจุบัน"
    echo -e "--------------------------------------------------------"
    echo -e " 12. เริ่มการทำงาน (Start)"
    echo -e " 13. หยุดการทำงาน (Stop)"
    echo -e " 14. รีสตาร์ทระบบ (Restart)"
    echo -e " 15. รีสตาร์ท Xray (Restart Xray)"
    echo -e " 16. ตรวจสอบสถานะ (Check Status)"
    echo -e " 17. จัดการไฟล์บันทึก (Logs Management)"
    echo -e "--------------------------------------------------------"
    echo -e " 18. เปิดใช้งานเริ่มต้นระบบอัตโนมัติ"
    echo -e " 19. ปิดใช้งานเริ่มต้นระบบอัตโนมัติ"
    echo -e "--------------------------------------------------------"
    echo -e " 20. จัดการใบรับรอง SSL"
    echo -e " 21. ใบรับรอง SSL จาก Cloudflare"
    echo -e " 22. จัดการจำกัด IP (IP Limit Management)"
    echo -e " 23. จัดการไฟร์วอลล์ (Firewall Management)"
    echo -e " 24. จัดการ SSH Port Forwarding"
    echo -e " 25. จัดการฐานข้อมูล PostgreSQL"
    echo -e "--------------------------------------------------------"
    echo -e " 26. เปิดใช้งาน BBR"
    echo -e " 27. อัปเดตไฟล์ Geo"
    echo -e " 28. ทดสอบความเร็ว (Speedtest by Ookla)"
    echo -e "--------------------------------------------------------"
    echo
    read -p "กรุณาเลือกเมนูที่ต้องการ [0-28]: " choice

    case $choice in
        1) menu_install ;;
        2) menu_update ;;
        3|4|5|6) menu_advanced ;;
        7) menu_set_auth ;;
        8) menu_set_wbp ;;
        9) menu_reset_all ;;
        10) menu_set_port ;;
        11) menu_show_config ;;
        12) menu_service start ;;
        13) menu_service stop ;;
        14) menu_service restart ;;
        15) menu_service restart-xray ;;
        16) menu_service status ;;
        17) menu_logs ;;
        18) menu_service enable ;;
        19) menu_service disable ;;
        20|21|22|23|24|25|26|27|28) menu_advanced ;;
        0) exit 0 ;;
        *)
            echo -e "${red}กรุณาเลือกตัวเลขให้ถูกต้อง [0-28]${plain}"
            sleep 2
            show_menu
            ;;
    esac
}

show_menu
