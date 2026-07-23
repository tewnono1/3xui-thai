#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# ฟังก์ชันจัดการเปลี่ยนชื่อผู้ใช้และรหัสผ่านโดยตรง
menu_set_auth() {
    clear
    echo -e "--------------------------------------------------------"
    echo -e "${green}       ★ เปลี่ยนชื่อผู้ใช้และรหัสผ่าน ★                   ${plain}"
    echo -e "--------------------------------------------------------"
    
    local config_username=""
    local config_password=""
    
    read -p "กรุณากรอกชื่อผู้ใช้ใหม่: " config_username
    read -p "กรุณากรอกรหัสผ่านใหม่: " config_password
    
    if [[ -n "$config_username" ]] && [[ -n "$config_password" ]]; then
        # ใช้คำสั่งภายในของ x-ui เพื่อบันทึกค่าลงฐานข้อมูลโดยตรง
        /usr/local/x-ui/x-ui setting -username "$config_username" -password "$config_password"
        echo -e "${green}เปลี่ยนชื่อผู้ใช้และรหัสผ่านเรียบร้อยแล้ว!${plain}"
    else
        echo -e "${red}ชื่อผู้ใช้หรือรหัสผ่านไม่สามารถเว้นว่างได้${plain}"
    fi
    
    echo
    read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
    show_menu
}

# ฟังก์ชันแสดงเมนูจัดการ 3X-UI ภาษาไทย
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
        7)
            menu_set_auth
            ;;
        1|2|3|4|5|6|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28)
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/x-ui.sh) "$choice"
            ;;
        *)
            echo -e "${red}กรุณาเลือกตัวเลขให้ถูกต้อง [0-28]${plain}"
            sleep 2
            show_menu
            ;;
    esac
}

show_menu
