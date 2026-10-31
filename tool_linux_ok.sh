#!/bin/bash

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script này với quyền sudo (VD: sudo ./setup_system.sh)"
  exit
fi

# ==============================================================================
# LỚP BẢO MẬT: KIỂM TRA MẬT KHẨU TRUY CẬP TOOL (HỖ TRỢ NHIỀU USER)
# ==============================================================================
DANH_SACH_MAT_KHAU=(
  "hoang123"
  "huy123"
  "0011"
  "0022"
  "0033"
)

echo ""
read -s -p " Vui lòng nhập mật khẩu IT để mở Tool: " input_pass
echo ""

dang_nhap_thanh_cong=false

for mk in "${DANH_SACH_MAT_KHAU[@]}"; do
  if [ "$input_pass" == "$mk" ]; then
    dang_nhap_thanh_cong=true
    break
  fi
done

clear

if [ "$dang_nhap_thanh_cong" = false ]; then
  echo " [LỖI] Sai mật khẩu! Bạn không có quyền sử dụng Tool này."
  echo " "
  echo " VUI LÒNG LIÊN HỆ MR. HUY IT ĐỂ ĐƯỢC QUYỀN TRUY CẬP."
  echo " "
  echo " Truy cập bị từ chối."
  exit 1
fi

echo "==============================================================="
echo " [OK] ĐĂNG NHẬP THÀNH CÔNG - TOOL LINUX FULL                  "
echo "==============================================================="
echo " Đang mở danh sách chức năng..."
sleep 1
clear

# ==============================================================================
# ĐỊNH NGHĨA CÁC HÀM XỬ LÝ (CHỨC NĂNG)
# ==============================================================================

cai_phan_mem() {
    echo "========================================="
    echo " ĐANG CÀI ĐẶT PHẦN MỀM CƠ BẢN            "
    echo "========================================="
    apt update -y
    apt install wget curl cifs-utils snapd -y

    echo "--> [1/5] Đang cài đặt Google Chrome..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    apt install /tmp/chrome.deb -y
    rm /tmp/chrome.deb

    echo "--> [2/5] Đang cài đặt Zalo..."
    snap install zalo

    echo "--> [3/5] Đang cài đặt bộ gõ tiếng Việt Unikey..."
    apt update -y
    apt install ibus-unikey im-config -y
    
    im-config -n ibus

    sed -i '/GTK_IM_MODULE=ibus/d' /etc/profile
    sed -i '/QT_IM_MODULE=ibus/d' /etc/profile
    sed -i '/XMODIFIERS=@im=ibus/d' /etc/profile
    echo "export GTK_IM_MODULE=ibus" >> /etc/profile
    echo "export QT_IM_MODULE=ibus" >> /etc/profile
    echo "export XMODIFIERS=@im=ibus" >> /etc/profile

    if [ -n "$SUDO_USER" ]; then
        sudo -u $SUDO_USER ibus-daemon -rdx 2>/dev/null
        echo "  [OK] Đã cài xong Unikey. Vui lòng vào Settings -> Keyboard để thêm 'Vietnamese (Unikey)'!"
    fi

    echo "--> [4/5] Đang cài đặt RustDesk (Điều khiển từ xa)..."
    wget https://github.com/rustdesk/rustdesk/releases/download/1.2.3-2/rustdesk-1.2.3-2-x86_64.deb -O /tmp/rustdesk.deb
    apt install /tmp/rustdesk.deb -f -y
    rm /tmp/rustdesk.deb
    
    echo "--> [5/5] Đang cài đặt bộ Font gốc Microsoft (Times New Roman, Arial, Calibri...)..."
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
    apt install ttf-mscorefonts-installer -y
    fc-cache -f -v

    echo "--> Hoàn tất cài đặt phần mềm!"
}

cai_may_in_canon_3300() {
    clear
    echo "=========================================================="
    echo "  KẾT NỐI MÁY IN CANON 3300 (GIAO THỨC SMB TRỰC TIẾP)     "
    echo "=========================================================="
    
    systemctl stop canon-smb-bridge 2>/dev/null
    systemctl disable canon-smb-bridge 2>/dev/null
    rm -f /etc/systemd/system/canon-smb-bridge.service
    rm -f /usr/local/bin/canon-bridge.sh
    rm -f /var/run/canon_smb_pipe
    systemctl daemon-reload
    pkill ccpd 2>/dev/null
    
    apt update -y > /dev/null 2>&1
    apt install -y wget cups smbclient python3 > /dev/null 2>&1
    systemctl enable cups 2>/dev/null
    systemctl start cups 2>/dev/null

    echo " NHẬP THÔNG TIN MÁY WINDOWS ĐANG CẮM MÁY IN (IP: 172.168.4.112):"
    read -p " 1. Nhập Tên Share máy in (VD: tc-hc): " share_name
    read -p " 2. Nhập Username của máy Windows đó: " win_user
    read -s -p " 3. Nhập Mật khẩu (Bỏ trống nếu không có): " win_pass
    echo ""
    
    if [ -z "$share_name" ] || [ -z "$win_user" ]; then
        echo " ❌ [LỖI] Tên Share và Username không được để trống!"
        return
    fi

    echo "--> Đang tải trực tiếp Driver Canon chính hãng..."
    cd /tmp
    rm -f common.deb capt.deb
    wget -q https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-common_3.21-1_amd64.deb -O common.deb
    wget -q https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-capt_2.71-1_amd64.deb -O capt.deb
    
    if [ ! -s common.deb ] || [ ! -s capt.deb ]; then
        echo " ❌ [LỖI] Không tải được Driver! Kiểm tra lại mạng."
        return
    fi

    dpkg -i common.deb > /dev/null 2>&1
    dpkg -i capt.deb > /dev/null 2>&1
    apt-get install -f -y > /dev/null 2>&1

    systemctl restart cups
    sleep 2

    PRINTER_NAME="Canon_3300_LAN"
    encoded_user=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$win_user'''))")
    if [ -n "$win_pass" ]; then
        encoded_pass=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$win_pass'''))")
        PRINTER_URI="smb://$encoded_user:$encoded_pass@172.168.4.112/$share_name"
    else
        PRINTER_URI="smb://$encoded_user@172.168.4.112/$share_name"
    fi

    lpadmin -x "$PRINTER_NAME" 2>/dev/null
    lpadmin -p "$PRINTER_NAME" -v "$PRINTER_URI" -m CNCUPSLBP3300CAPTK.ppd -E
    lpoptions -d "$PRINTER_NAME" > /dev/null 2>&1
    cupsenable "$PRINTER_NAME" 2>/dev/null
    cupsaccept "$PRINTER_NAME" 2>/dev/null

    echo "  [OK] ĐÃ CÀI ĐẶT XONG MÁY IN CANON 3300 (DIRECT SMB)!"
}

cai_may_in() {
    echo "========================================="
    echo " ĐANG DỌN DẸP VÀ CÀI ĐẶT 3 MÁY IN HP     "
    echo "========================================="
    
    apt install cups printer-driver-hpijs printer-driver-postscript-hp -y
    
    echo "--> Đang khóa dịch vụ tự tìm kiếm máy in (cups-browsed)..."
    systemctl stop cups-browsed 2>/dev/null
    systemctl disable cups-browsed 2>/dev/null
    systemctl mask cups-browsed 2>/dev/null 
    
    systemctl enable --now cups
    
    echo "--> Đang xóa các máy in cũ/tự nhận diện..."
    for p in $(lpstat -p 2>/dev/null | grep "printer" | awk '{print $2}'); do
        lpadmin -x "$p" 2>/dev/null
        echo "  + Đã xóa: $p"
    done
    
    echo "--> Đang cài: May_Pho_To (172.168.0.92)..."
    lpadmin -p "May_Pho_To" -E -v "socket://172.168.0.92:9100" -m "drv:///sample.drv/generpcl.ppd" -D "HP LaserJet Pro MFP 4103fdn" -L "Phong Photo"
    
    echo "--> Đang cài: Le_Tan (172.168.4.217) - Chỉ in 1 mặt..."
    lpadmin -p "Le_Tan" -E -v "socket://172.168.4.217:9100" -m "drv:///sample.drv/generpcl.ppd" -D "HP LaserJet M402dn" -L "Le Tan" -o sides=one-sided -o Duplex=None
    
    echo "--> Đang cài: Ke_Toan (172.168.0.32) - Chỉ in 1 mặt..."
    lpadmin -p "Ke_Toan" -E -v "socket://172.168.0.32:9100" -m "drv:///sample.drv/generpcl.ppd" -D "HP LaserJet M402dn" -L "Ke Toan" -o sides=one-sided -o Duplex=None
    
    systemctl restart cups
    lpadmin -d "Le_Tan"
    
    echo "--> Đã cấu hình xong 3 máy in chuẩn và dọn dẹp hệ thống sạch sẽ!"
}

# ==============================================================================
# HÀM SỐ 16: CÀI ĐẶT BỘ FONT FULL TIẾNG VIỆT (TỪ SERVER NỘI BỘ OSTOCK)
# ==============================================================================
cai_full_font_tieng_viet() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT BỘ FONT FULL TIẾNG VIỆT (TỪ SERVER OSTOCK)     "
    echo "=========================================================="
    
    echo "--> [1/4] Đang cài đặt công cụ giải nén..."
    apt update -y > /dev/null 2>&1
    apt install unzip fontconfig -y > /dev/null 2>&1
    
    echo "--> [2/4] Tải bộ Font Quốc tế chuẩn Unicode (Google Noto, Roboto)..."
    apt install fonts-noto fonts-roboto -y > /dev/null 2>&1
    
    echo "--> [3/4] Tìm kiếm bộ Font doanh nghiệp từ máy chủ 172.168.0.5..."
    FONT_DIR="/usr/share/fonts/truetype/Ostock_VN_Fonts"
    mkdir -p "$FONT_DIR"
    cd /tmp
    rm -f vn_fonts.zip

    # Khai báo đường dẫn trỏ tới file Font trên ổ mạng công ty
    FILE_FONT_TREN_SERVER="/mnt/Thu_Muc_Chung/vn_fonts.zip"

    if [ -f "$FILE_FONT_TREN_SERVER" ]; then
        echo "  + Đã tìm thấy file vn_fonts.zip trên máy chủ Ostock!"
        echo "  + Đang copy về máy và giải nén (Tốc độ mạng LAN)..."
        cp "$FILE_FONT_TREN_SERVER" /tmp/vn_fonts.zip
        
        # Test file zip xem có bị hỏng trong quá trình copy không
        if unzip -t vn_fonts.zip >/dev/null 2>&1; then
            unzip -q vn_fonts.zip -d /tmp/vn_fonts
            
            echo "  + Đang nhặt và nạp Font vào hệ thống..."
            # Tách riêng 2 lệnh quét để đảm bảo vớt sạch sẽ 100% cả đuôi hoa và đuôi thường
            find /tmp/vn_fonts -type f -iname "*.ttf" -exec cp {} "$FONT_DIR/" \;
            find /tmp/vn_fonts -type f -iname "*.otf" -exec cp {} "$FONT_DIR/" \;
            
            # 🔥 ĐÃ FIX LỖI QUYỀN TRUY CẬP: Cấp quyền riêng biệt cho Thư mục và File
            chmod 755 "$FONT_DIR"
            find "$FONT_DIR" -type f -exec chmod 644 {} \;
            
            rm -rf /tmp/vn_fonts vn_fonts.zip
        else
            echo " ❌ [LỖI] File vn_fonts.zip trên Server bị lỗi nén! Vui lòng tạo lại file Zip."
            rm -f vn_fonts.zip
        fi
    else
        echo " ❌ [LỖI] KHÔNG TÌM THẤY FILE FONT TRÊN SERVER NỘI BỘ!"
        echo "----------------------------------------------------------"
        echo " 💡 CÁCH XỬ LÝ DÀNH CHO IT OSTOCK:"
        echo " 1. Đảm bảo máy tính này ĐÃ ĐƯỢC KẾT NỐI Ổ CHUNG (Dùng Menu số 4)."
        echo " 2. Hãy chuẩn bị 1 file tên là: vn_fonts.zip (Chứa các font VNI, UTM...)"
        echo " 3. Copy file vn_fonts.zip đó vào thư mục Thu_Muc_Chung (172.168.0.5)."
        echo " 4. Chạy lại Menu 16 này, Tool sẽ tự động lấy Font về cài siêu tốc!"
        echo "----------------------------------------------------------"
    fi

    echo "--> [4/4] Đang làm mới lại bộ nhớ đệm (Cache) Font của Ubuntu..."
    fc-cache -f -v > /dev/null 2>&1

    echo "=========================================================="
    echo "  [OK] ĐÃ XỬ LÝ XONG TIẾN TRÌNH CÀI FONT!"
    echo "  Khắc phục triệt để lỗi ô vuông, thiếu chữ trong LibreOffice."
    echo "  Lưu ý: Nếu đang mở Office hoặc Zalo, hãy tắt đi và mở lại."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

thiet_lap_o_chung() {
    LOCAL_SHARE_PATH=$1
    LOCAL_MOUNT_POINT=$2

    mkdir -p "$LOCAL_MOUNT_POINT"
    
    sed -i "\|${LOCAL_MOUNT_POINT}|d" /etc/fstab
    
    echo "$LOCAL_SHARE_PATH $LOCAL_MOUNT_POINT cifs credentials=/root/.smbcredentials,vers=2.0,uid=$SUDO_USER,gid=$SUDO_USER,file_mode=0777,dir_mode=0777,nobrl,x-gvfs-show,nofail,_netdev,x-systemd.automount 0 0" >> /etc/fstab
    
    echo "  + Đã cấu hình ổ: $LOCAL_MOUNT_POINT"
}

# ==============================================================================
# HÀM MỚI: THÊM Ổ MẠNG THỦ CÔNG (Ổ CÁ NHÂN / TỰ GÕ TÊN)
# ==============================================================================
them_o_chung_thu_cong() {
    clear
    echo "=========================================================="
    echo "   THÊM Ổ MẠNG CÁ NHÂN / THƯ MỤC TỰ NHẬP TÊN              "
    echo "=========================================================="
    
    if [ -f "/root/.smbcredentials" ]; then
        echo "--> Máy này ĐÃ CÓ sẵn tài khoản kết nối mạng."
        read -p "Bạn có muốn dùng lại tài khoản này không? (y/n, mặc định y): " use_old_pass
        if [ "$use_old_pass" = "n" ] || [ "$use_old_pass" = "N" ]; then
            read -p "--> Nhập tài khoản mạng MỚI (Username): " smb_user
            read -s -p "--> Nhập mật khẩu mạng MỚI: " smb_pass
            echo ""
            echo "username=$smb_user" > /root/.smbcredentials
            echo "password=$smb_pass" >> /root/.smbcredentials
            chmod 600 /root/.smbcredentials
        fi
    else
        read -p "--> Nhập tài khoản mạng (Username): " smb_user
        read -s -p "--> Nhập mật khẩu mạng: " smb_pass
        echo ""
        echo "username=$smb_user" > /root/.smbcredentials
        echo "password=$smb_pass" >> /root/.smbcredentials
        chmod 600 /root/.smbcredentials
    fi

    echo "----------------------------------------------------------"
    echo " VD: Thư mục cá nhân trên server là 'Nguyen.Van.A' hoặc 'Du An 2024'"
    read -p "--> Nhập TÊN THƯ MỤC TRÊN SERVER: " share_name
    
    if [ -z "$share_name" ]; then
        echo " ❌ Tên thư mục không được để trống!"
        read -p "Bấm phím Enter để quay lại..."
        return
    fi

    echo "----------------------------------------------------------"
    echo " VD: Muốn hiện trên máy tính là 'O_Ca_Nhan' -> Bạn gõ: O_Ca_Nhan"
    read -p "--> Nhập TÊN Ổ HIỂN THỊ (Viết liền, không dấu Tiếng Việt): " mount_name

    if [ -z "$mount_name" ]; then
        echo " ❌ Tên hiển thị không được để trống!"
        read -p "Bấm phím Enter để quay lại..."
        return
    fi

    share_name_fstab=$(echo "$share_name" | sed 's/ /\\040/g')
    
    FULL_SHARE_PATH="//172.168.0.5/$share_name_fstab"
    FULL_MOUNT_PATH="/mnt/$mount_name"

    echo "----------------------------------------------------------"
    echo "--> Đang tiến hành kết nối..."
    
    thiet_lap_o_chung "$FULL_SHARE_PATH" "$FULL_MOUNT_PATH"
    
    mount -a
    
    echo "=========================================================="
    echo "  [OK] ĐÃ MOUNT THÀNH CÔNG!"
    echo "  Ổ đĩa của bạn đã xuất hiện tại: $FULL_MOUNT_PATH"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cau_hinh_o_mang() {
    echo "========================================="
    echo " CẤU HÌNH Ổ ĐĨA CHUNG THEO PHÒNG BAN     "
    echo "========================================="
    apt install cifs-utils libnotify-bin -y 2>/dev/null
    echo "Vui lòng chọn phòng ban của máy này:"
    echo "  1. Giám Đốc"
    echo "  2. TC HC"
    echo "  3. IT"
    echo "  4. Lễ Tân"
    echo "  5. Bảo Trì"
    echo "  6. Kế Toán"
    echo "  7. Kinh Doanh"
    echo "  8. F&B"
    echo "  9. House Keeping"
    echo "  10. Chỉ Thư Mục Chung"
    echo "  0. Exit"
    read -p "Nhập lựa chọn của bạn (0-10): " dept_choice

    if [ "$dept_choice" != "0" ]; then
        read -p "--> Nhập tài khoản mạng (Username): " smb_user
        read -s -p "--> Nhập mật khẩu mạng: " smb_pass
        echo ""

        echo "username=$smb_user" > /root/.smbcredentials
        echo "password=$smb_pass" >> /root/.smbcredentials
        chmod 600 /root/.smbcredentials

        echo "--> Đang gắn các ổ đĩa vào fstab..."
        
        case $dept_choice in
            1) # Giám Đốc
                thiet_lap_o_chung "//172.168.0.5/Lanh.Dao" "/mnt/Lanh_Dao"
                thiet_lap_o_chung "//172.168.0.5/Lanh\040Dao_NEW" "/mnt/Lanh_Dao_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            2) # TC HC
                thiet_lap_o_chung "//172.168.0.5/TC.HC" "/mnt/TC_HC"
                thiet_lap_o_chung "//172.168.0.5/TC\040HC_NEW" "/mnt/TC_HC_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            3) # IT
                thiet_lap_o_chung "//172.168.0.5/IT" "/mnt/IT"
                thiet_lap_o_chung "//172.168.0.5/TC\040HC_NEW" "/mnt/TC_HC_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"   
                ;;
            4) # Lễ Tân
                thiet_lap_o_chung "//172.168.0.5/Le.Tan" "/mnt/Le_Tan"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                thiet_lap_o_chung "//172.168.0.5/Le\040Tan_NEW" "/mnt/Le_Tan_New"
                ;;
            5) # Bảo Trì
                thiet_lap_o_chung "//172.168.0.5/Bao.Tri" "/mnt/Bao_Tri"
                thiet_lap_o_chung "//172.168.0.5/Bao\040Tri_NEW" "/mnt/Bao_Tri_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            6) # Kế Toán
                thiet_lap_o_chung "//172.168.0.5/Ke\040Toan_NEW" "/mnt/Ke_Toan_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            7) # Kinh doanh
                thiet_lap_o_chung "//172.168.0.5/Kinh.Doanh" "/mnt/Kinh_Doanh"
                thiet_lap_o_chung "//172.168.0.5/Kinh\040Doanh_NEW" "/mnt/Kinh_Doanh_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            8) # F & B
                thiet_lap_o_chung "//172.168.0.5/F&B" "/mnt/F_and_B"
                thiet_lap_o_chung "//172.168.0.5/F&B_NEW" "/mnt/F_and_B_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"
                ;;
            9) # House Keeping
                thiet_lap_o_chung "//172.168.0.5/House.Keeping" "/mnt/House_Keeping"
                thiet_lap_o_chung "//172.168.0.5/House.Keeping_NEW" "/mnt/House_Keeping_New"
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"   
                ;;
            10) # Chỉ Thư Mục Chung
                thiet_lap_o_chung "//172.168.0.5/Thu\040Muc\040Chung" "/mnt/Thu_Muc_Chung"   
                ;;   
            0) # Thoát
                ;;   
            *)
                echo "Lựa chọn không hợp lệ."
                return
                ;;
        esac

        mount -a
        echo "--> Đã mount thành công các thư mục vào /mnt/"

        # =========================================================================
        # TÍNH NĂNG MỚI: TẠO SHORTCUT CẤP CỨU NGOÀI DESKTOP CHO USER
        # =========================================================================
        echo "--> Đang tạo Icon sửa lỗi ngoài màn hình cho User..."

        if [ -d "/home/$SUDO_USER/Desktop" ]; then
            DESKTOP_DIR="/home/$SUDO_USER/Desktop"
        else
            DESKTOP_DIR="/home/$SUDO_USER/Màn hình nền"
        fi

cat << 'EOF' > /usr/local/bin/fix_o_mang.sh
#!/bin/bash
umount -l /mnt/* 2>/dev/null
mount -a
EOF
        chmod +x /usr/local/bin/fix_o_mang.sh

        echo "ALL ALL=(root) NOPASSWD: /usr/local/bin/fix_o_mang.sh" > /etc/sudoers.d/fix_o_mang
        chmod 0440 /etc/sudoers.d/fix_o_mang

cat << EOF > "$DESKTOP_DIR/FIX_O_MANG.desktop"
[Desktop Entry]
Name=FIX Ổ MẠNG (nhấn 2 lần)
Comment=Click đúp để kết nối lại ổ đĩa công ty
Exec=bash -c "sudo /usr/local/bin/fix_o_mang.sh && notify-send 'IT CHÚC BẠN MỘT NGÀY LÀM VIỆC VUI VẺ' 'Đã kết nối lại toàn bộ Ổ đĩa mạng!' -i network-server"
Icon=network-server
Terminal=false
Type=Application
EOF

cat << EOF > "$DESKTOP_DIR/FIX_GO_CHU.desktop"
[Desktop Entry]
Name=FIX LỖI GÕ CHỮ
Comment=Click đúp để khởi động lại bộ gõ tiếng Việt
Exec=bash -c "ibus restart && notify-send 'IT CHÚC BẠN MỘT NGÀY LÀM VIỆC VUI VẺ' 'Đã nạp lại bộ gõ Tiếng Việt!' -i input-keyboard"
Icon=input-keyboard
Terminal=false
Type=Application
EOF

        chmod +x "$DESKTOP_DIR/FIX_O_MANG.desktop"
        chmod +x "$DESKTOP_DIR/FIX_GO_CHU.desktop"
        chown $SUDO_USER:$SUDO_USER "$DESKTOP_DIR/FIX_O_MANG.desktop" "$DESKTOP_DIR/FIX_GO_CHU.desktop"
        gio set "$DESKTOP_DIR/FIX_O_MANG.desktop" metadata::trusted true 2>/dev/null
        gio set "$DESKTOP_DIR/FIX_GO_CHU.desktop" metadata::trusted true 2>/dev/null

        echo "--> [HOÀN TẤT] Đã tạo xong 2 nút bấm FIX lỗi ngoài màn hình!"
    fi
}

cai_dat_unikey() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT BỘ GÕ TIẾNG VIỆT UNIKEY (TỰ ĐỘNG HOÀN TOÀN)   "
    echo "=========================================================="
    
    echo "--> [1/5] Đang dọn dẹp bộ gõ mặc định (IBus)..."
    apt remove --purge ibus ibus-unikey -y 2>/dev/null
    apt autoremove -y > /dev/null 2>&1
    
    echo "--> [2/5] Đang tải hệ thống Fcitx..."
    apt update -y > /dev/null 2>&1
    apt install fcitx fcitx-unikey fcitx-frontend-all fcitx-module-dbus fcitx-config-gtk im-config -y
    
    echo "--> [3/5] Đang đặt Fcitx làm bộ gõ mặc định..."
    im-config -n fcitx
    
    sed -i '/GTK_IM_MODULE/d' /etc/environment
    sed -i '/QT_IM_MODULE/d' /etc/environment
    sed -i '/XMODIFIERS/d' /etc/environment
    echo "GTK_IM_MODULE=fcitx" >> /etc/environment
    echo "QT_IM_MODULE=fcitx" >> /etc/environment
    echo "XMODIFIERS=@im=fcitx" >> /etc/environment

    echo "--> [4/5] Tự động nạp Unikey vào cấu hình hệ thống..."
    mkdir -p /home/$SUDO_USER/.config/fcitx
    
cat <<EOF > /home/$SUDO_USER/.config/fcitx/profile
[Profile]
EnabledIMList=fcitx-keyboard-us:True,unikey:True
EOF

    echo "--> [5/5] Cấu hình biểu tượng chạy tự động..."
    mkdir -p /home/$SUDO_USER/.config/autostart
cat <<EOF > /home/$SUDO_USER/.config/autostart/fcitx-autostart.desktop
[Desktop Entry]
Name=Fcitx
Exec=fcitx-autostart
Type=Application
EOF
    
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/fcitx
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/autostart

    echo "=========================================================="
    echo "  [OK] ĐÃ TRIỂN KHAI UNIKEY HOÀN TOÀN TỰ ĐỘNG!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_camera() {
    clear
    echo "=========================================================="
    echo "  TẠO SHORTCUT XEM 4 CAMERA TỰ ĐỘNG CHIA KHUNG (GRID)"
    echo "=========================================================="
    
    if [ -d "/home/$SUDO_USER/Desktop" ]; then
        DESKTOP_DIR="/home/$SUDO_USER/Desktop"
    else
        DESKTOP_DIR="/home/$SUDO_USER/Màn hình nền"
    fi

    echo "--> Đang cài đặt trình xem VLC và công cụ chia khung wmctrl..."
    apt install vlc wmctrl x11-xserver-utils -y 2>/dev/null

    echo "--> Đang tạo lối tắt tự chia khung Camera..."
cat <<'EOF' > "$DESKTOP_DIR/Mo_4_Camera.sh"
#!/bin/bash
SCREEN_RES=$(xrandr | grep '\*' | awk '{print $1}' | head -n 1)
WIDTH=$(echo $SCREEN_RES | cut -d 'x' -f 1)
HEIGHT=$(echo $SCREEN_RES | cut -d 'x' -f 2)
HALF_W=$((WIDTH / 2))
HALF_H=$((HEIGHT / 2))

vlc "rtsp://admin:Ocd%40123789@171.244.81.129:554/Streaming/Channels/102" --meta-title="Cam1" --qt-minimal-view --network-caching=300 --no-one-instance &>/dev/null &
vlc "rtsp://admin:Ocd%40123789@171.244.81.129:554/Streaming/Channels/202" --meta-title="Cam2" --qt-minimal-view --network-caching=300 --no-one-instance &>/dev/null &
vlc "rtsp://admin:Ocd%40123789@171.244.81.129:554/Streaming/Channels/302" --meta-title="Cam3" --qt-minimal-view --network-caching=300 --no-one-instance &>/dev/null &
vlc "rtsp://admin:Ocd%40123789@171.244.81.129:554/Streaming/Channels/402" --meta-title="Cam4" --qt-minimal-view --network-caching=300 --no-one-instance &>/dev/null &

sleep 5

wmctrl -r "Cam1" -e 0,0,0,$HALF_W,$HALF_H
wmctrl -r "Cam2" -e 0,$HALF_W,0,$HALF_W,$HALF_H
wmctrl -r "Cam3" -e 0,0,$HALF_H,$HALF_W,$HALF_H
wmctrl -r "Cam4" -e 0,$HALF_W,$HALF_H,$HALF_W,$HALF_H
EOF

    echo "--> Đang cấp quyền thực thi..."
    chmod +x "$DESKTOP_DIR/Mo_4_Camera.sh"
    chown $SUDO_USER:$SUDO_USER "$DESKTOP_DIR/Mo_4_Camera.sh"

    echo "=========================================================="
    echo "  [OK] Đã tạo thành công lối tắt ngoài Desktop!"
    echo "=========================================================="
}

cai_lai_liberoffice() {
    clear
    echo "=========================================================="
    echo "    GỠ BỎ HOÀN TOÀN VÀ CÀI ĐẶT LẠI LIBREOFFICE SẠCH      "
    echo "=========================================================="
    
    echo "--> [1/3] Đang tiến hành gỡ bỏ tận gốc LibreOffice cũ..."
    apt remove --purge libreoffice* -y
    apt autoremove -y
    apt clean
    
    echo "--> [2/3] Đang xóa thư mục cấu hình ẩn bị lỗi..."
    rm -rf /home/$SUDO_USER/.config/libreoffice
    
    echo "--> [3/3] Đang cài đặt lại phiên bản LibreOffice sạch..."
    apt update -y
    apt install libreoffice libreoffice-gnome -y

    echo "=========================================================="
    echo "  [OK] Đã hoàn tất cài đặt lại LibreOffice hoàn toàn sạch sẽ!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

# ==============================================================================
# HÀM SỐ 5 ĐÃ ĐƯỢC FIX LỖI: SỬ DỤNG RMDIR ĐỂ ĐẢM BẢO AN TOÀN TUYỆT ĐỐI
# ==============================================================================
go_bo_o_mang() {
    clear
    echo "========================================="
    echo " ĐANG NGẮT KẾT NỐI VÀ DỌN DẸP Ổ MẠNG     "
    echo "========================================="
    
    echo "--> [1/4] Đang ép ngắt kết nối an toàn (Lazy Unmount)..."
    umount -l /mnt/* 2>/dev/null
    sleep 1

    echo "--> [2/4] Đang xóa các dòng cấu hình trong file fstab..."
    sed -i "\|//172.168.0.5|d" /etc/fstab
    sed -i "\|/mnt/|d" /etc/fstab

    echo "--> [3/4] Đang dọn dẹp thư mục bến đỗ cục bộ trên máy..."
    # Chỉ xóa thư mục rỗng, tuyệt đối an toàn cho dữ liệu Server
    rmdir /mnt/* 2>/dev/null

    echo "--> [4/4] Xóa file lưu tài khoản mạng nội bộ trên máy..."
    rm -f /root/.smbcredentials

    systemctl daemon-reload

    echo "=========================================================="
    echo "  [OK] ĐÃ GỠ SẠCH CẤU HÌNH Ổ MẠNG TRÊN MÁY NÀY!"
    echo "  🔒 Dữ liệu gốc trên Server Ostock an toàn vẹn toàn 100%."
    echo "=========================================================="
    echo ""
}

cai_tool_boc_chu_ocr() {
    clear
    echo "=========================================================="
    echo "    CÀI ĐẶT CÔNG CỤ BÓC CHỮ MÀN HÌNH CHUẨN (NORMCAP)      "
    echo "=========================================================="
    
    echo "--> [1/5] Đang cài đặt lõi nhận diện Tesseract OCR..."
    apt update -y
    apt install tesseract-ocr tesseract-ocr-vie software-properties-common -y

    echo "--> [2/5] Đang cài đặt Flatpak..."
    add-apt-repository ppa:flatpak/stable -y
    apt update -y
    apt install flatpak -y

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak remote-modify flathub --url=https://dl.flathub.org/repo/

    echo "--> [3/5] Đang tải và cài đặt NormCap..."
    flatpak install flathub com.github.dynobo.normcap -y

    echo "--> [4/5] Đang cấp quyền truy cập hệ thống..."
    flatpak override --filesystem=host com.github.dynobo.normcap 2>/dev/null

    echo "--> [5/5] Đang tạo lối tắt..."
    if [ -d "/home/$SUDO_USER/Desktop" ]; then
        DESKTOP_DIR="/home/$SUDO_USER/Desktop"
    else
        DESKTOP_DIR="/home/$SUDO_USER/Màn hình nền"
    fi

cat <<EOF > "$DESKTOP_DIR/Quet_Chu_OCR.desktop"
[Desktop Entry]
Version=1.0
Name=Quét Chữ (OCR)
Comment=Bóc chữ từ hình ảnh màn hình
Exec=flatpak run com.github.dynobo.normcap
Icon=accessories-text-editor
Terminal=false
Type=Application
EOF

    chmod +x "$DESKTOP_DIR/Quet_Chu_OCR.desktop"
    chown $SUDO_USER:$SUDO_USER "$DESKTOP_DIR/Quet_Chu_OCR.desktop"
    gio set "$DESKTOP_DIR/Quet_Chu_OCR.desktop" metadata::trusted true 2>/dev/null

    echo "=========================================================="
    echo "  [OK] Đã cài đặt xong công cụ bóc chữ NormCap!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

fix_loi_go_chu() {
    clear
    echo "=========================================================="
    echo "    FIX LỖI GÕ ẨN CHỮ TRONG OFFICE (ĐỔI IBUS SANG FCITX)  "
    echo "=========================================================="
    
    echo "--> [1/4] Đang gỡ bỏ hệ thống IBus cũ..."
    apt remove --purge ibus ibus-unikey -y 2>/dev/null
    apt autoremove -y
    
    echo "--> [2/4] Đang cài đặt Fcitx siêu mượt..."
    apt update -y
    apt install fcitx fcitx-unikey im-config -y
    
    echo "--> [3/4] Đang nạp cấu hình môi trường chuẩn..."
    im-config -n fcitx

    sed -i '/GTK_IM_MODULE/d' /etc/profile
    sed -i '/QT_IM_MODULE/d' /etc/profile
    sed -i '/XMODIFIERS/d' /etc/profile
    echo "export GTK_IM_MODULE=fcitx" >> /etc/profile
    echo "export QT_IM_MODULE=fcitx" >> /etc/profile
    echo "export XMODIFIERS=@im=fcitx" >> /etc/profile

    echo "--> [4/4] Đang cấu hình tự động chạy ngầm..."
    mkdir -p /home/$SUDO_USER/.config/autostart
cat <<EOF > /home/$SUDO_USER/.config/autostart/fcitx-autostart.desktop
[Desktop Entry]
Name=Fcitx
Exec=fcitx-autostart
Type=Application
EOF
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/autostart

    echo "=========================================================="
    echo "  [OK] Đã fix xong lỗi gõ chữ! VUI LÒNG KHỞI ĐỘNG LẠI MÁY."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

tat_ngu_dong_va_khoa() {
    clear
    echo "=========================================================="
    echo "    TẮT CHẾ ĐỘ NGỦ ĐÔNG VÀ BỎ KHÓA MÀN HÌNH UBUNTU        "
    echo "=========================================================="
    
    if [ -n "$SUDO_USER" ]; then
        echo "--> Đang thiết lập cho tài khoản: $SUDO_USER..."
        
        sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
        sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null
        sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null
        systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null

        echo "  [OK] Đã cấu hình máy luôn thức và không hỏi mật khẩu!"
    else
        echo "  [LỖI] Không xác định được user hệ thống."
    fi

    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_dat_flameshot() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT FLAMESHOT - CÔNG CỤ CHỤP MÀN HÌNH BẢN QUYỀN    "
    echo "=========================================================="
    
    echo "--> [1/3] Đang tải và cài đặt hệ thống Flameshot..."
    apt update -y > /dev/null 2>&1
    apt install flameshot -y
    
    echo "--> [2/3] Đang cấu hình ứng dụng chạy ngầm..."
    mkdir -p /home/$SUDO_USER/.config/autostart
cat <<EOF > /home/$SUDO_USER/.config/autostart/Flameshot.desktop
[Desktop Entry]
Name=Flameshot
Exec=flameshot
Type=Application
EOF
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/autostart

    echo "--> [3/3] Đang gán phím Print Screen..."
    sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys screenshot '[]' 2>/dev/null
    sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_flameshot/']" 2>/dev/null
    sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_flameshot/ name 'Flameshot' 2>/dev/null
    sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_flameshot/ command 'flameshot gui' 2>/dev/null
    sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_flameshot/ binding 'Print' 2>/dev/null

    echo "=========================================================="
    echo "  [OK] Đã triển khai xong công cụ Flameshot!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_rustdesk_may_cu() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT & FIX LỖI RUSTDESK (MÁY CŨ / LỖI ĐEN MÀN HÌNH) "
    echo "=========================================================="
    
    echo "--> [1/4] Đang cài đặt các thư viện lõi đồ họa cho máy cũ..."
    apt update -y > /dev/null 2>&1
    apt install -y wget curl libx11-xcb1 libxcb-randr0 libxcb-xfixes0 > /dev/null 2>&1

    echo "--> [2/4] Đang tải và cài đặt lõi RustDesk..."
    cd /tmp
    rm -f rustdesk.deb
    wget -q https://github.com/rustdesk/rustdesk/releases/download/1.2.3-2/rustdesk-1.2.3-2-x86_64.deb -O rustdesk.deb
    
    if [ ! -s rustdesk.deb ]; then
        echo " ❌ [LỖI] Không tải được RustDesk! Hãy kiểm tra kết nối mạng."
        read -p "Bấm phím Enter để quay lại Menu chính..."
        return
    fi

    dpkg -i rustdesk.deb > /dev/null 2>&1
    apt-get install -f -y > /dev/null 2>&1

    echo "--> [3/4] BÍ THUẬT: Tắt Wayland, ép dùng X11 để chống đen màn hình..."
    if [ -f "/etc/gdm3/custom.conf" ]; then
        sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /etc/gdm3/custom.conf
    fi

    echo "--> [4/4] Đang khởi động lại dịch vụ RustDesk ngầm..."
    systemctl enable rustdesk > /dev/null 2>&1
    systemctl restart rustdesk > /dev/null 2>&1

    echo "=========================================================="
    echo "  [OK] ĐÃ CÀI ĐẶT VÀ FIX LỖI RUSTDESK THÀNH CÔNG!"
    echo "  ⚠️ LƯU Ý QUAN TRỌNG:"
    echo "  Để áp dụng cấu hình chống đen màn hình (X11), bạn BẮT BUỘC"
    echo "  phải KHỞI ĐỘNG LẠI MÁY (Restart) sau khi cài xong nhé!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

fix_loi_rustdesk() {
    clear
    echo "=========================================================="
    echo "   SỬA LỖI RUSTDESK CRASH (BẬT LÊN TỰ TẮT)                "
    echo "=========================================================="
    
    echo "--> [1/4] Đang ép đóng tiến trình và dọn dẹp sạch bản lỗi..."
    pkill rustdesk 2>/dev/null
    apt remove --purge rustdesk -y > /dev/null 2>&1
    apt autoremove -y > /dev/null 2>&1

    echo "--> [2/4] Đang tiêu diệt thư mục cấu hình rác gây lỗi..."
    rm -rf /home/$SUDO_USER/.config/rustdesk
    rm -rf /home/$SUDO_USER/.local/share/rustdesk
    rm -rf /root/.config/rustdesk 2>/dev/null

    echo "--> [3/4] Đang tải bản chuẩn nguyên gốc từ kho lưu trữ..."
    cd /tmp
    rm -f rustdesk.deb
    wget -qO rustdesk.deb https://github.com/rustdesk/rustdesk/releases/download/1.2.3-2/rustdesk-1.2.3-2-x86_64.deb

    echo "--> [4/4] Đang cài đặt và khởi động lại dịch vụ..."
    apt install ./rustdesk.deb -y > /dev/null 2>&1
    
    systemctl enable rustdesk > /dev/null 2>&1
    systemctl restart rustdesk > /dev/null 2>&1

    echo "=========================================================="
    echo "  [OK] ĐÃ FIX XONG LỖI RUSTDESK TỰ TẮT!"
    echo "  Bây giờ hãy mở lại ứng dụng, ID và Pass sẽ hiện ra mượt mà."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_may_in_hp_1102_usb() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT & SHARE MÁY IN HP 1102 (MÁY CHỦ USB)           "
    echo "=========================================================="
    echo " ⚠️ YÊU CẦU TRƯỚC KHI CÀI ĐẶT:"
    echo " 1. Hãy chắc chắn máy in ĐÃ ĐƯỢC BẬT NGUỒN."
    echo " 2. Đã cắm cáp USB từ máy in vào máy tính này."
    echo "=========================================================="
    read -p " Bấm phím Enter khi bạn đã chuẩn bị xong 2 bước trên..."

    echo "--> [1/4] Đang tải gói điều khiển máy in HP (HPLIP)..."
    apt update -y > /dev/null 2>&1
    apt install -y cups hplip > /dev/null 2>&1
    
    systemctl enable cups 2>/dev/null
    systemctl start cups 2>/dev/null

    echo "--> [2/4] Đang tải và ép nạp Plugin độc quyền của HP 1102..."
    hp-plugin -i -a

    echo "--> [3/4] Đang quét và cấu hình máy in qua cổng USB..."
    hp-setup -i -a -b usb

    echo "--> [4/4] ĐANG BẬT TÍNH NĂNG CHIA SẺ MÁY IN QUA MẠNG LAN..."
    cupsctl --share-printers --remote-admin --remote-any
    systemctl restart cups

    MAY_CHU_IP=$(hostname -I | awk '{print $1}')

    echo "=========================================================="
    echo "  [OK] ĐÃ CÀI ĐẶT VÀ SHARE MÁY IN HP 1102 THÀNH CÔNG!"
    echo "  - Máy này hiện tại đã trở thành MÁY CHỦ IN ẤN."
    echo "  - 📍 ĐỊA CHỈ IP CỦA MÁY NÀY LÀ: $MAY_CHU_IP"
    echo "  -> Hãy qua các máy khách, chạy Menu số 19 và nhập IP này nhé!"
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_dat_bamboo() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT BỘ GÕ TIẾNG VIỆT BAMBOO (BẢN CHUẨN ỔN ĐỊNH)    "
    echo "=========================================================="
    
    echo "--> [1/5] Đang dọn dẹp sạch sẽ tàn dư của Unikey và Fcitx..."
    apt remove --purge fcitx* ibus-unikey -y 2>/dev/null
    apt autoremove -y > /dev/null 2>&1
    
    echo "--> [2/5] Đang thêm kho PPA chính thức của Bamboo..."
    add-apt-repository ppa:bamboo-engine/ibus-bamboo -y > /dev/null 2>&1
    apt update -y > /dev/null 2>&1
    
    echo "--> [3/5] Đang cài đặt IBus và lõi Bamboo..."
    apt install ibus ibus-bamboo --install-recommends -y
    
    echo "--> [4/5] Đang thiết lập môi trường IBus làm mặc định..."
    im-config -n ibus
    
    sed -i '/GTK_IM_MODULE/d' /etc/environment
    sed -i '/QT_IM_MODULE/d' /etc/environment
    sed -i '/XMODIFIERS/d' /etc/environment
    echo "GTK_IM_MODULE=ibus" >> /etc/environment
    echo "QT_IM_MODULE=ibus" >> /etc/environment
    echo "XMODIFIERS=@im=ibus" >> /etc/environment

    echo "--> [5/5] Đang ép hệ thống tự nhận Bamboo (Tự động 100%)..."
    if [ -n "$SUDO_USER" ]; then
        sudo -u $SUDO_USER dbus-launch gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'bamboo')]" 2>/dev/null
        sudo -u $SUDO_USER ibus restart 2>/dev/null
    fi

    echo "=========================================================="
    echo "  [OK] ĐÃ TRIỂN KHAI XONG BỘ GÕ BAMBOO!"
    echo "  VUI LÒNG LOG OUT (ĐĂNG XUẤT) VÀ VÀO LẠI ĐỂ ÁP DỤNG."
    echo ""
    echo "  - Góc phải trên cùng sẽ hiện chữ 'en' hoặc 'vi'."
    echo "  - Bấm 'Windows + Space' để chuyển đổi tiếng Anh/Việt."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

ep_mo_rustdesk() {
    clear
    echo "=========================================================="
    echo "   LẤY ID & ĐẶT PASS RUSTDESK (CHẾ ĐỘ DÒNG LỆNH TỐI CAO)  "
    echo "=========================================================="
    echo "--> Card đồ họa máy này quá cũ, đang bỏ qua giao diện..."
    echo "--> Đang đánh thức dịch vụ lõi ngầm của RustDesk..."

    systemctl enable rustdesk > /dev/null 2>&1
    systemctl restart rustdesk > /dev/null 2>&1
    sleep 3 

    RUSTDESK_ID=$(rustdesk --get-id 2>/dev/null)

    if [ -z "$RUSTDESK_ID" ]; then
        RUSTDESK_ID=$(cat /home/$SUDO_USER/.config/rustdesk/RustDesk*.toml 2>/dev/null | grep "id =" | cut -d"'" -f2 | head -n 1)
    fi

    echo "=========================================================="
    if [ -n "$RUSTDESK_ID" ]; then
        echo " 🎯 RUSTDESK ID CỦA MÁY NÀY LÀ: $RUSTDESK_ID"
    else
        echo " ⚠️ Máy đang khởi tạo ID lần đầu. Hãy đợi 10 giây và chạy lại số 21!"
        echo "=========================================================="
        read -p "Bấm phím Enter để quay lại..."
        return
    fi
    echo "=========================================================="

    read -p "--> Nhập MẬT KHẨU CỐ ĐỊNH bạn muốn cài (VD: Ostock@123): " r_pass

    if [ -n "$r_pass" ]; then
        rustdesk --password "$r_pass" > /dev/null 2>&1
        echo "  [OK] Đã nạp mật khẩu thành công vào hệ thống!"
    else
        echo "  [CẢNH BÁO] Bạn đã bỏ trống, bỏ qua bước cài mật khẩu."
    fi

    echo "=========================================================="
    echo "  HOÀN TẤT! Bạn có thể về máy tính IT và Remote vào ID trên."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}

cai_may_in_hp_1102_qua_mang() {
    clear
    echo "=========================================================="
    echo "   CÀI ĐẶT MÁY IN HP 1102 QUA MẠNG (MÁY KHÁCH)             "
    echo "=========================================================="
    
    read -p "--> Nhập ĐỊA CHỈ IP của Máy Chủ (Ví dụ: 172.168.0.20): " server_ip
    if [ -z "$server_ip" ]; then
        echo " ❌ IP không được để trống!"
        read -p "Bấm phím Enter để quay lại..."
        return
    fi

    echo "--> [1/3] Đang cài đặt thư viện in ấn lõi cho Máy khách..."
    apt update -y > /dev/null 2>&1
    apt install -y cups hplip libnotify-bin > /dev/null 2>&1
    systemctl start cups 2>/dev/null

    echo "--> [2/3] Đang nạp Plugin đồ họa HP cho máy khách..."
    hp-plugin -i -a

    echo "--> [3/3] Đang tiến hành kết nối tới Máy chủ máy in qua giao thức IPP..."
    PRINTER_NAME="HP_1102_Network"
    
    lpadmin -x "$PRINTER_NAME" 2>/dev/null
    lpadmin -p "$PRINTER_NAME" -E -v "ipp://$server_ip:631/printers/HP-LaserJet-Professional-P1102" -m raw
    lpadmin -d "$PRINTER_NAME" 2>/dev/null

    echo "=========================================================="
    echo "  [OK] ĐÃ KẾT NỐI MÁY IN MẠNG THÀNH CÔNG!"
    echo "  Tên máy in xuất hiện trên máy khách: $PRINTER_NAME"
    echo "  Bây giờ nhân viên có thể bấm Ctrl + P để in qua mạng."
    echo "=========================================================="
    echo ""
    read -p "Bấm phím Enter để quay lại Menu chính..."
}


# ==============================================================================
# CẤU HÌNH Ổ MẠNG MỚI - NHẬP IP / USERNAME / PASSWORD SMB
# ==============================================================================
cau_hinh_o_mang_moi() {
    clear
    echo "=========================================================="
    echo "       CẤU HÌNH Ổ MẠNG MỚI - TRUE NAS / SMB              "
    echo "=========================================================="

    apt install -y cifs-utils smbclient >/dev/null 2>&1
    if ! command -v mount.cifs >/dev/null 2>&1 || ! command -v smbclient >/dev/null 2>&1; then
        echo "[LỖI] Thiếu cifs-utils hoặc smbclient. Không thể tiếp tục."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi

    read -r -p "--> Nhập IP máy chủ SMB (VD: 172.168.0.6): " server_ip
    if [[ -z "$server_ip" ]]; then
        echo "[LỖI] IP máy chủ không được để trống."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi

    read -r -p "--> Nhập Username SMB: " smb_user
    if [[ -z "$smb_user" ]]; then
        echo "[LỖI] Username không được để trống."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi
    read -r -s -p "--> Nhập Password SMB: " smb_pass; echo
    read -r -s -p "--> Nhập Password Linux (sudo): " linux_pass; echo

    if ! printf '%s\n' "$linux_pass" | sudo -S -v 2>/dev/null; then
        unset linux_pass smb_pass
        echo "[LỖI] Sai mật khẩu Linux hoặc tài khoản không có quyền sudo."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi
    unset linux_pass

    # Credentials riêng của máy chủ mới; không đè credentials máy chủ cũ.
    cred_file="/root/.smbcredentials_newserver"
    umask 077
    printf 'username=%s\npassword=%s\n' "$smb_user" "$smb_pass" > "$cred_file"
    chmod 600 "$cred_file"
    unset smb_pass

    echo "--> Đang xác thực tài khoản SMB..."
    if ! smbclient -L "//$server_ip" -A "$cred_file" -m SMB2 >/dev/null 2>&1; then
        echo "[LỖI] Không đăng nhập được SMB. Kiểm tra IP, username/password và mạng."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi
    echo "[OK] Xác thực SMB thành công."

    shares=("THU_MUC_CHUNG" "THU_MUC_CA_NHAN" "THU_MUC_RIENG_PHONG")
    for share in "${shares[@]}"; do
        if smbclient "//$server_ip/$share" -A "$cred_file" -m SMB2 -c 'ls' >/dev/null 2>&1; then
            echo "[OK] Truy cập được: $share"
        else
            echo "[LỖI] Không truy cập được Share: $share"
            echo "Kiểm tra tên Share và quyền ACL trên TrueNAS."
            read -p "Nhấn Enter để quay lại Menu chính..."
            return
        fi
    done

    # Bắt chước chính xác cơ chế của thiet_lap_o_chung() đang chạy tốt:
    # SMB vers=2.0, uid/gid theo user desktop, mode 0777, nobrl, gvfs, nofail, _netdev, automount.
    desktop_user="${SUDO_USER:-}"
    if [[ -z "$desktop_user" ]] || ! id "$desktop_user" >/dev/null 2>&1; then
        desktop_user="$(logname 2>/dev/null)"
    fi
    if [[ -z "$desktop_user" ]] || ! id "$desktop_user" >/dev/null 2>&1; then
        echo "[LỖI] Không xác định được tài khoản Linux đang dùng."
        read -p "Nhấn Enter để quay lại Menu chính..."
        return
    fi
    desktop_uid=$(id -u "$desktop_user")
    desktop_gid=$(id -g "$desktop_user")

    echo "--> Đang tạo điểm mount và thử kết nối theo cấu hình ổ mạng cũ..."
    mount_ok=0
    failed_shares=()

    for share in "${shares[@]}"; do
        mount_dir="/mnt/$share"
        mkdir -p "$mount_dir"

        # Dọn mount cũ ở đúng điểm mount này, không đụng các share máy chủ cũ khác.
        if mountpoint -q "$mount_dir"; then
            umount "$mount_dir" 2>/dev/null || true
        fi

        # Mount thử trực tiếp với cùng tùy chọn của hàm thiet_lap_o_chung gốc.
        if mount -t cifs "//$server_ip/$share" "$mount_dir" \
            -o "credentials=$cred_file,vers=2.0,uid=$desktop_user,gid=$desktop_user,file_mode=0777,dir_mode=0777,nobrl,x-gvfs-show,nofail,_netdev"; then
            if findmnt -rn -t cifs --target "$mount_dir" >/dev/null 2>&1; then
                echo "[OK] Đã map: $mount_dir"
                mount_ok=$((mount_ok + 1))
            else
                echo "[LỖI] Lệnh mount trả về nhưng chưa xác nhận CIFS: $mount_dir"
                failed_shares+=("$share")
            fi
        else
            echo "[LỖI] Mount thất bại: $mount_dir"
            echo "      Kiểm tra lỗi hệ thống bằng: sudo journalctl -k -n 30 --no-pager"
            failed_shares+=("$share")
        fi
    done

    # Chỉ lưu fstab cho các share mount thử thành công.
    if [[ "$mount_ok" -gt 0 ]]; then
        for share in "${shares[@]}"; do
            mount_dir="/mnt/$share"
            if findmnt -rn -t cifs --target "$mount_dir" >/dev/null 2>&1; then
                # Xóa dòng fstab cũ tại đúng mount point, rồi thêm dòng theo kiểu hàm gốc.
                sed -i "\\|[[:space:]]$mount_dir[[:space:]]|d" /etc/fstab
                printf '//%s/%s %s cifs credentials=%s,vers=2.0,uid=%s,gid=%s,file_mode=0777,dir_mode=0777,nobrl,x-gvfs-show,nofail,_netdev,x-systemd.automount 0 0\n' \
                    "$server_ip" "$share" "$mount_dir" "$cred_file" "$desktop_user" "$desktop_user" >> /etc/fstab
            fi
        done
        systemctl daemon-reload 2>/dev/null || true
    fi

    echo "=========================================================="
    if [[ "$mount_ok" -eq 3 ]]; then
        echo "🎉 ĐÃ MAP THÀNH CÔNG CẢ 3 Ổ MẠNG!"
        echo "1. /mnt/THU_MUC_CHUNG"
        echo "2. /mnt/THU_MUC_CA_NHAN"
        echo "3. /mnt/THU_MUC_RIENG_PHONG"
        echo "Đã lưu cấu hình tự động kết nối khi khởi động."
    else
        echo "Đã mount thành công $mount_ok/3 thư mục."
        if [[ ${#failed_shares[@]} -gt 0 ]]; then
            echo "Share chưa mount: ${failed_shares[*]}"
        fi
        echo "Các Share thất bại không được thêm mới vào fstab."
    fi
    echo "=========================================================="
    read -p "Nhấn Enter để quay lại Menu chính..."
}

# ==============================================================================
# MENU CHÍNH (MAIN MENU)
# ==============================================================================

while true; do
    clear
    echo ""
    echo "==============================================================="
    echo "      TOOL AUTO SETUP MÁY TRẠM UBUNTU - MADE BY HUY IT V2.3    "
    echo "==============================================================="
    echo " 1. Cài đặt toàn bộ (Phần mềm + Máy in + Ổ mạng)"
    echo " 2. Chỉ cài phần mềm (Chrome, Zalo, Bamboo, RustDesk)"
    echo " 3. Chỉ cài máy in (HP LaserJet M402)"
    echo " 4. Chỉ cấu hình ổ mạng (Menu phòng ban)"
    echo " 5. Ngắt kết nối và gỡ bỏ toàn bộ ổ mạng (An toàn 100%)"
    echo " 6. Cài đặt VLC tạo lối tắt Xem Camera"
    echo " 7. Cài đặt và Fix lỗi RustDesk (Cho máy cũ không có Card rời)"
    echo " 8. Gỡ sạch vĩnh viễn và Cài đặt lại LibreOffice (Sửa lỗi Office)"
    echo " 9. Cài đặt NormCap (quét text trên ảnh và lưu vào bộ nhớ đệm)"
    echo " 10. Fix lỗi gõ ẩn chữ, mất chữ trong Office (Đổi IBus sang Fcitx)"
    echo " 11. Tắt chế độ ngủ đông và bỏ mật khẩu khóa màn hình"
    echo " 12. Cài máy in 3300 TC-HC"
    echo " 13. Cài Unikey"
    echo " 14. Cài đặt Flameshot (Chụp màn hình chuẩn doanh nghiệp)"
    echo " 15. Cài đặt bamboo (gõ tiếng việt)"
    echo " 16. Cài đặt Full Font Tiếng Việt"
    echo " 17. Fix lỗi RustDesk Crash (Bật lên tự tắt)"
    echo " 18. Cài đặt & SHARE máy in HP 1102 (Cắm cáp USB trực tiếp)"
    echo " 19. Cài đặt máy in HP 1102 (Qua MẠNG - Share từ máy chủ)"
    echo " 20. Ép lệnh MỞ GIAO DIỆN RUSTDESK (Để lấy ID và đặt Pass)"
    echo " 21. Thêm Ổ MẠNG THỦ CÔNG (Tự nhập tên thư mục riêng/cá nhân)"
    echo " 22. Cấu hình ổ mạng mới (Nhập IP, Username, Password SMB)"
    echo " 0. Thoát chương trình"
    echo "=========================================================="
    read -p " Nhập số để chọn chức năng (0-22): " main_choice

    case $main_choice in
        1)
            cai_phan_mem
            cai_may_in
            cau_hinh_o_mang
            echo "========================================="
            echo "   ĐÃ HOÀN TẤT TẤT CẢ! HÃY RESTART MÁY.  "
            echo "========================================="
            break
            ;;
        2)
            cai_phan_mem
            read -p "Nhấn Enter để quay lại Menu chính..."
            ;;
        3)
            cai_may_in
            read -p "Nhấn Enter để quay lại Menu chính..."
            ;;
        4)
            cau_hinh_o_mang
            read -p "Nhấn Enter để quay lại Menu chính..."
            ;;
        5)
            go_bo_o_mang
            read -p "Nhấn Enter để quay lại Menu chính..."
            ;;
        6)  cai_camera
            read -p "Nhấn Enter để quay lại Menu chính..."
            ;;
        7)  cai_rustdesk_may_cu 
            ;;
        8)  cai_lai_liberoffice
            ;;
        9)  cai_tool_boc_chu_ocr
            ;;
        10) fix_loi_go_chu
            ;;
        11) tat_ngu_dong_va_khoa
            ;;
        12) cai_may_in_canon_3300
            ;;
        13) cai_dat_unikey
            ;;
        14) cai_dat_flameshot
            ;;
        15) cai_dat_bamboo
            ;;
        16) cai_full_font_tieng_viet 
            ;;
        17) fix_loi_rustdesk ;;
        18) cai_may_in_hp_1102_usb ;;
        19) cai_may_in_hp_1102_qua_mang ;;
        20) ep_mo_rustdesk ;;
        21) them_o_chung_thu_cong ;;
        22) cau_hinh_o_mang_moi ;;
        0)
            echo "Đã thoát Tool. Chúc bạn IT một ngày làm việc hiệu quả!"
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ, vui lòng nhập lại!"
            sleep 1
            ;;
    esac
done
