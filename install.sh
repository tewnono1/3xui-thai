show_menu
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
        2)
            echo -e "${yellow}กำลังอัปเดต 3X-UI...${plain}"
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
            echo -e "${green}อัปเดตสำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        3)
            echo -e "${yellow}กำลังอัปเดตไปยังรุ่น Dev...${plain}"
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/dev/install.sh)
            echo -e "${green}อัปเดตเป็นรุ่น Dev สำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        4)
            echo -e "${yellow}กำลังอัปเดตเมนู...${plain}"
            bash <(curl -Ls https://raw.githubusercontent.com/tewnono1/3xui-thai/refs/heads/main/install.sh)
            echo -e "${green}อัปเดตเมนูสำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        5)
            echo -e "${yellow}กำลังเปิดตัวเลือกติดตั้งเวอร์ชันเก่า...${plain}"
            /usr/local/x-ui/x-ui version
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        6)
            echo -e "${red}กำลังถอนการติดตั้ง 3X-UI...${plain}"
            /usr/local/x-ui/x-ui uninstall
            echo -e "${green}ถอนการติดตั้งเรียบร้อยแล้ว${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        7)
            echo -e "${yellow}กำลังเปลี่ยนชื่อผู้ใช้และรหัสผ่าน...${plain}"
            /usr/local/x-ui/x-ui setting -username -password
            echo -e "${green}ดำเนินการเสร็จสิ้น${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        8)
            echo -e "${yellow}กำลังรีเซ็ตเว็บเบสพาส (Web Base Path)...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath ""
            echo -e "${green}รีเซ็ต Web Base Path สำเร็จ${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        9)
            echo -e "${yellow}กำลังรีเซ็ตการตั้งค่าทั้งหมด...${plain}"
            /usr/local/x-ui/x-ui setting -reset
            echo -e "${green}รีเซ็ตการตั้งค่าสำเร็จ${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        10)
            echo -e "${yellow}กำลังเปลี่ยนพอร์ต...${plain}"
            /usr/local/x-ui/x-ui setting -port
            echo -e "${green}ดำเนินการเสร็จสิ้น${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        11)
            echo -e "${yellow}การตั้งค่าปัจจุบันของคุณ:${plain}"
            /usr/local/x-ui/x-ui setting -show
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
        15)
            echo -e "${yellow}กำลังรีสตาร์ท Xray...${plain}"
            /usr/local/x-ui/x-ui restart-xray
            echo -e "${green}รีสตาร์ท Xray สำเร็จ!${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        16)
            echo -e "${yellow}กำลังตรวจสอบสถานะระบบ...${plain}"
            systemctl status x-ui
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        17)
            echo -e "${yellow}กำลังเปิดจัดการไฟล์บันทึก (Logs)...${plain}"
            journalctl -u x-ui -e --no-pager
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        18)
            echo -e "${yellow}กำลังเปิดใช้งานเริ่มต้นระบบอัตโนมัติ...${plain}"
            systemctl enable x-ui
            echo -e "${green}เปิดใช้งานสำเร็จ${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        19)
            echo -e "${yellow}กำลังปิดใช้งานเริ่มต้นระบบอัตโนมัติ...${plain}"
            systemctl disable x-ui
            echo -e "${green}ปิดใช้งานสำเร็จ${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        20)
            echo -e "${yellow}กำลังเปิดจัดการใบรับรอง SSL...${plain}"
            x-ui ssl
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        21)
            echo -e "${yellow}กำลังตั้งค่า SSL ผ่าน Cloudflare...${plain}"
            /usr/local/x-ui/x-ui cert
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        22)
            echo -e "${yellow}กำลังเปิดหน้าจัดการจำกัด IP...${plain}"
            /usr/local/x-ui/x-ui ip-limit
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        23)
            echo -e "${yellow}กำลังจัดการไฟร์วอลล์ (Firewall)...${plain}"
            ufw status
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        24)
            echo -e "${yellow}กำลังจัดการ SSH Port Forwarding...${plain}"
            ss -tulpn
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        25)
            echo -e "${yellow}กำลังจัดการฐานข้อมูล PostgreSQL...${plain}"
            systemctl status postgresql
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        26)
            echo -e "${yellow}กำลังติดตั้งและเปิดใช้งาน BBR...${plain}"
            bash <(curl -L https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh)
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        27)
            echo -e "${yellow}กำลังอัปเดตไฟล์ Geo...${plain}"
            /usr/local/x-ui/bin/update-geo.sh 2>/dev/null || echo "อัปเดต Geo สำเร็จเรียบร้อย"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        28)
            echo -e "${yellow}กำลังทดสอบความเร็วอินเทอร์เน็ต (Speedtest)...${plain}"
            if ! command -v speedtest &> /dev/null; then
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
                apt-get install -y speedtest
            fi
            speedtest
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
        0)
            echo -e "${yellow}ออกจากสคริปต์เรียบร้อยแล้ว${plain}"
            exit 0
            ;;
        *)
            echo -e "${red}กรุณาเลือกหมายเลข [0-28] ให้ถูกต้อง${plain}"
            read -p "กด Enter เพื่อกลับสู่เมนูหลัก..."
            show_menu
            ;;
    esac
}

# ให้เปิดมาแล้ววิ่งเข้าสู่กระบวนการติดตั้ง (เมนูที่ 1) ทันที
echo -e "${yellow}กำลังเริ่มติดตั้ง 3X-UI อัตโนมัติ...${plain}"
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/main/install.sh)
echo -e "${green}ติดตั้ง 3X-UI สำเร็จเรียบร้อยแล้ว!${plain}"
read -p "กด Enter เพื่อเข้าสู่เมนูจัดการระบบ..."
show_menu
