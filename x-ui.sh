#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

xui_folder="/usr/local/x-ui"

press_enter() {
    echo
    read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
    show_menu
}

run_menu_action() {
    local choice="$1"
    case "$choice" in
        1)
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
            ;;
        2)
            ${xui_folder}/x-ui update
            ;;
        3)
            ${xui_folder}/x-ui update-dev
            ;;
        4)
            echo "อัปเดตเมนูเรียบร้อย"
            ;;
        5)
            ${xui_folder}/x-ui legacy
            ;;
        6)
            ${xui_folder}/x-ui uninstall
            ;;
        7)
            echo -e "--------------------------------------------------------"
            echo -e "${green}       ★ เปลี่ยนชื่อผู้ใช้และรหัสผ่าน ★                   ${plain}"
            echo -e "--------------------------------------------------------"
            read -p "กรุณากรอกชื่อผู้ใช้ใหม่: " u
            read -p "กรุณากรอกรหัสผ่านใหม่: " p
            if [[ -n "$u" ]] && [[ -n "$p" ]]; then
                ${xui_folder}/x-ui setting -username "$u" -password "$p"
                echo -e "${green}เปลี่ยนชื่อผู้ใช้และรหัสผ่านเรียบร้อยแล้ว!${plain}"
            else
                echo -e "${red}ข้อมูลไม่ครบถ้วน${plain}"
            fi
            ;;
        8)
            read -p "กรุณากรอก Web Base Path ใหม่: " wbp
            ${xui_folder}/x-ui setting -webBasePath "$wbp"
            echo -e "${green}รีเซ็ต Web Base Path สำเร็จ!${plain}"
            ;;
        9)
            read -p "คุณต้องการรีเซ็ตการตั้งค่าทั้งหมดใช่หรือไม่? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && ${xui_folder}/x-ui reset
            ;;
        10)
            read -p "กรุณากรอกหมายเลขพอร์ตใหม่: " port
            [[ -n "$port" ]] && ${xui_folder}/x-ui setting -port "$port"
            ;;
        11)
            ${xui_folder}/x-ui setting -show
            ;;
        12)
            systemctl start x-ui
            echo -e "${green}เริ่มการทำงาน x-ui แล้ว${plain}"
            ;;
        13)
            systemctl stop x-ui
            echo -e "${yellow}หยุดการทำงาน x-ui แล้ว${plain}"
            ;;
        14)
            systemctl restart x-ui
            echo -e "${green}รีสตาร์ท x-ui เรียบร้อย${plain}"
            ;;
        15)
            ${xui_folder}/x-ui restart-xray
            echo -e "${green}รีสตาร์ท Xray เรียบร้อย${plain}"
            ;;
        16)
            systemctl status x-ui
            ;;
        17)
            ${xui_folder}/x-ui log
            ;;
        18)
            systemctl enable x-ui
            echo -e "${green}เปิดใช้งานรันอัตโนมัติแล้ว${plain}"
            ;;
        19)
            systemctl disable x-ui
            echo -e "${yellow}ปิดใช้งานรันอัตโนมัติแล้ว${plain}"
            ;;
        20)
            ${xui_folder}/x-ui cert 2>/dev/null || echo "จัดการผ่านระบบหลัก"
            ;;
        21|22|23|24|25|26|27|28)
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh)
            ;;
    esac
}

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
        0)
            exit 0
            ;;
        1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28)
            run_menu_action "$choice"
            press_enter
            ;;
        *)
            echo -e "${red}กรุณาเลือกตัวเลขให้ถูกต้อง [0-28]${plain}"
            sleep 2
            show_menu
            ;;
    esac
}

show_menu
