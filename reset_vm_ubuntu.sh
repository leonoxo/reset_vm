#!/bin/bash

# 函數：提示用戶輸入
prompt_input() {
    read -p "$1: " input  # 提示用戶輸入並讀取輸入值
    echo "$input"  # 返回輸入值
}

# 函數：設置主機名
set_hostname() {
    local new_hostname=$1  # 獲取新主機名
    echo "Setting hostname to $new_hostname"  # 輸出設置主機名的信息
    sudo hostnamectl set-hostname "$new_hostname"  # 使用hostnamectl設置新主機名
    echo "$new_hostname" | sudo tee /etc/hostname  # 將新主機名寫入/etc/hostname文件

    # 刪除/etc/hosts文件中的原有127.0.0.1條目並插入新的條目
    sudo sed -i "/127.0.0.1/c\127.0.0.1 $new_hostname" /etc/hosts
}

# 函數：列出網絡接口
list_interfaces() {
    ip -o link show | awk -F': ' '{print $2}'  # 列出所有網絡接口名稱
}

# 函數：配置網絡
configure_network() {
    local config_file=$1  # 獲取配置文件名稱
    local interface=$2  # 獲取網絡接口名稱
    local ip_type=$3  # 獲取IP類型（靜態或DHCP）
    local new_ip=$4  # 獲取新的IP地址
    local new_subnet=$5  # 獲取新的子網掩碼
    local new_gateway=$6  # 獲取新的網關
    shift 6  # 移動參數位置以獲取DNS伺服器地址
    local new_dns=("$@")  # 獲取DNS伺服器地址

    if [ "$ip_type" = "static" ]; then  # 如果IP類型是靜態
        echo "Setting static IP for interface $interface"  # 輸出設置靜態IP的信息
        sudo bash -c "cat > /etc/netplan/$config_file <<EOL
network:
  version: 2
  ethernets:
    $interface:
      addresses:
        - $new_ip/$new_subnet
      routes:
        - to: default
          via: $new_gateway
      nameservers:
        addresses:
EOL"
        # 逐行添加DNS伺服器地址
        for dns in "${new_dns[@]}"; do
            if [ -n "$dns" ]; then  # 如果DNS地址非空
                sudo bash -c "echo '          - $dns' >> /etc/netplan/$config_file"  # 添加DNS地址到配置文件
            fi
        done
        sudo bash -c "echo '    ' >> /etc/netplan/$config_file"  # 添加結束符號
    else
        echo "Setting DHCP for interface $interface"  # 輸出設置DHCP的信息
        sudo bash -c "cat > /etc/netplan/$config_file <<EOL
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: yes
EOL"
    fi

    sudo netplan apply  # 應用網絡配置
}

# 函數：重新生成SSH密鑰
regenerate_ssh_keys() {
    echo "Regenerating SSH keys"  # 輸出重新生成SSH密鑰的信息
    rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub  # 刪除現有的SSH密鑰
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""  # 生成新的SSH密鑰
    cat ~/.ssh/id_rsa.pub  # 顯示新生成的公鑰
}

# 函數：重設machine-id
reset_machine_id() {
    echo "Resetting machine-id"  # 輸出重設machine-id的信息
    sudo rm /etc/machine-id  # 刪除現有的machine-id
    sudo systemd-machine-id-setup  # 生成新的machine-id
}

# 函數：清理cloud-init狀態
clean_cloud_init() {
    echo "Cleaning cloud-init state"  # 輸出清理cloud-init狀態的信息
    sudo cloud-init clean  # 清理cloud-init狀態
}

# 函數：移除udev規則
remove_udev_rules() {
    echo "Removing udev rules"  # 輸出移除udev規則的信息
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules  # 刪除udev規則文件
}

# 主函數：執行所有任務
main() {
    local new_hostname  # 定義新主機名變量
    local interface  # 定義網絡接口變量
    local ip_type  # 定義IP類型變量
    local new_ip  # 定義新IP地址變量
    local new_subnet  # 定義新子網掩碼變量
    local new_gateway  # 定義新網關變量
    local new_dns  # 定義新DNS變量
    local config_file  # 定義配置文件變量

    # 選擇netplan配置文件
    config_files=(/etc/netplan/*.yaml)  # 獲取所有netplan配置文件
    if [ ${#config_files[@]} -eq 1 ]; then  # 如果只有一個配置文件
        config_file=$(basename "${config_files[0]}")  # 使用該配置文件
    else
        echo "Multiple netplan configuration files found:"  # 輸出多個配置文件的信息
        select file in "${config_files[@]}"; do  # 列出所有配置文件讓用戶選擇
            config_file=$(basename "$file")  # 獲取選擇的配置文件
            break
        done
    fi

    echo "Using configuration file: $config_file"  # 輸出使用的配置文件

    new_hostname=$(prompt_input "Enter new hostname")  # 提示輸入新主機名並讀取輸入值

    # 列出並選擇網絡接口
    interfaces=($(list_interfaces))  # 獲取所有網絡接口
    echo "Available network interfaces:"  # 輸出可用的網絡接口
    select iface in "${interfaces[@]}"; do  # 列出所有網絡接口讓用戶選擇
        interface=$iface  # 獲取選擇的網絡接口
        break
    done

    echo "Select IP type:"  # 輸出選擇IP類型的信息
    select ip_type in "static" "dhcp"; do  # 提供選擇IP類型的選項
        break
    done

    if [ "$ip_type" = "static" ]; then  # 如果選擇靜態IP
        new_ip=$(prompt_input "Enter new IP address")  # 提示輸入新IP地址並讀取輸入值
        new_subnet=$(prompt_input "Enter subnet mask (e.g., 24 for 255.255.255.0)")  # 提示輸入子網掩碼並讀取輸入值
        new_gateway=$(prompt_input "Enter gateway IP address")  # 提示輸入網關地址並讀取輸入值
        
        echo "Enter primary DNS server IP address:"  # 提示輸入主要DNS伺服器地址
        read -p "Primary DNS: " dns1  # 讀取主要DNS伺服器地址
        echo "Enter secondary DNS server IP address (leave blank if none):"  # 提示輸入次要DNS伺服器地址（如果沒有則留空）
        read -p "Secondary DNS: " dns2  # 讀取次要DNS伺服器地址
        
        new_dns=("$dns1" "$dns2")  # 將讀取的DNS地址存入數組
    fi

    set_hostname "$new_hostname"  # 設置主機名
    configure_network "$config_file" "$interface" "$ip_type" "$new_ip" "$new_subnet" "$new_gateway" "${new_dns[@]}"  # 配置網絡
    regenerate_ssh_keys  # 重新生成SSH密鑰
    reset_machine_id  # 重設machine-id
    clean_cloud_init  # 清理cloud-init狀態
    remove_udev_rules  # 移除udev規則

    echo "Rebooting system to apply changes"  # 輸出重啟系統的信息
    sudo reboot  # 重啟系統以應用更改
}

main  # 執行主函數
