#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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
        1)
            echo -e "${yellow}กำลังเริ่มติดตั้ง 3X-UI...${plain}"
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
            echo -e "${green}ติดตั้ง 3X-UI สำเร็จเรียบร้อยแล้ว!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        7)
            echo -e "${yellow}กำลังเปิดหน้าต่างเปลี่ยนชื่อผู้ใช้และรหัสผ่าน...${plain}"
            /usr/local/x-ui/x-ui setting -username -password
            echo -e "${green}ดำเนินการเสร็จสิ้น${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        12)
            echo -e "${yellow}กำลังเริ่มการทำงาน 3X-UI...${plain}"
            systemctl start x-ui
            echo -e "${green}เปิดการทำงาน 3X-UI สำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        13)
            echo -e "${yellow}กำลังหยุดการทำงาน 3X-UI...${plain}"
            systemctl stop x-ui
            echo -e "${green}หยุดการทำงาน 3X-UI สำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        14)
            echo -e "${yellow}กำลังรีสตาร์ทระบบ 3X-UI...${plain}"
            systemctl restart x-ui
            echo -e "${green}รีสตาร์ทระบบ 3X-UI สำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        16)
            echo -e "${yellow}กำลังตรวจสอบสถานะระบบ...${plain}"
            systemctl status x-ui
            echo -e "${green}ตรวจสอบสถานะเสร็จสิ้น${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        0)
            echo -e "${yellow}ออกจากสคริปต์เรียบร้อยแล้ว${plain}"
            exit 0
            ;;
        *)
            echo -e "${red}ฟังก์ชันนี้กำลังอยู่ในระหว่างการพัฒนา...${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
    esac
}

show_menu
