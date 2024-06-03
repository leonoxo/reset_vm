#!/bin/bash

# Function to prompt user for input
prompt_input() {
    read -p "$1: " input
    echo "$input"
}

# Function to set hostname
set_hostname() {
    local new_hostname=$1
    echo "Setting hostname to $new_hostname"
    sudo hostnamectl set-hostname "$new_hostname"
    echo "$new_hostname" | sudo tee /etc/hostname
    sudo sed -i "s/127.0.0.1 .*/127.0.0.1 $new_hostname/" /etc/hosts
}

# Function to list network interfaces
list_interfaces() {
    ip -o link show | awk -F': ' '{print $2}'
}

# Function to configure network
configure_network() {
    local config_file=$1
    local interface=$2
    local ip_type=$3
    local new_ip=$4
    local new_subnet=$5
    local new_gateway=$6
    shift 6
    local new_dns=("$@")

    if [ "$ip_type" = "static" ]; then
        echo "Setting static IP for interface $interface"
        sudo bash -c "cat > /etc/netplan/$config_file <<EOL
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: no
      addresses:
        - $new_ip/$new_subnet
      routes:
        - to: default
          via: $new_gateway
      nameservers:
        addresses:
          - ${new_dns[@]}
EOL"
    else
        echo "Setting DHCP for interface $interface"
        sudo bash -c "cat > /etc/netplan/$config_file <<EOL
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: yes
EOL"
    fi

    sudo netplan apply
}

# Function to regenerate SSH keys
regenerate_ssh_keys() {
    echo "Regenerating SSH keys"
    rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    cat ~/.ssh/id_rsa.pub
}

# Function to reset machine-id
reset_machine_id() {
    echo "Resetting machine-id"
    sudo rm /etc/machine-id
    sudo systemd-machine-id-setup
}

# Function to clean cloud-init state
clean_cloud_init() {
    echo "Cleaning cloud-init state"
    sudo cloud-init clean
}

# Function to remove udev rules
remove_udev_rules() {
    echo "Removing udev rules"
    sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
}

# Main function to execute all tasks
main() {
    local new_hostname
    local interface
    local ip_type
    local new_ip
    local new_subnet
    local new_gateway
    local new_dns
    local config_file

    # Select netplan configuration file
    config_files=(/etc/netplan/*.yaml)
    if [ ${#config_files[@]} -eq 1 ]; then
        config_file=$(basename "${config_files[0]}")
    else
        echo "Multiple netplan configuration files found:"
        select file in "${config_files[@]}"; do
            config_file=$(basename "$file")
            break
        done
    fi

    echo "Using configuration file: $config_file"

    new_hostname=$(prompt_input "Enter new hostname")

    # List and select network interface
    interfaces=($(list_interfaces))
    echo "Available network interfaces:"
    select iface in "${interfaces[@]}"; do
        interface=$iface
        break
    done

    echo "Select IP type:"
    select ip_type in "static" "dhcp"; do
        break
    done

    if [ "$ip_type" = "static" ]; then
        new_ip=$(prompt_input "Enter new IP address")
        new_subnet=$(prompt_input "Enter subnet mask (e.g., 24 for 255.255.255.0)")
        new_gateway=$(prompt_input "Enter gateway IP address")
        
        echo "Enter DNS server IP addresses (comma separated):"
        read -p "Enter DNS server IP addresses: " dns_input
        IFS=',' read -r -a new_dns <<< "$dns_input"
    fi

    set_hostname "$new_hostname"
    configure_network "$config_file" "$interface" "$ip_type" "$new_ip" "$new_subnet" "$new_gateway" "${new_dns[@]}"
    regenerate_ssh_keys
    reset_machine_id
    clean_cloud_init
    remove_udev_rules

    echo "Rebooting system to apply changes"
    sudo reboot
}

main
