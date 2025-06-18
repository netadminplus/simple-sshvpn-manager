#!/bin/bash

PANEL_VERSION="1.0"
PANEL_NAME="NetAdminPlus SSH VPN Manager"
MAIN_TITLE="$PANEL_NAME v$PANEL_VERSION"
CREATOR_INFO="Created with ❤️  by Ramtin"
YOUTUBE_CHANNEL="https://YouTube.com/NetAdminPlus"
CONFIG_DIR="./config"

detect_linux_distribution() {
    if [ -x "$(command -v yum)" ]; then
        echo "rhel"
    elif [ -x "$(command -v apt-get)" ]; then
        echo "debian"
    else
        echo "unsupported"
    fi
}

get_system_users() {
    awk -F: '$3 >= 1000 && $1 != "nobody" { print $1 }' /etc/passwd
}

check_user_suspended() {
    local target_user="$1"
    local status_check
    status_check=$(sudo chage -l "$target_user" 2>/dev/null | grep "Password expires")
    if [ -z "$(echo "$status_check" | grep "never")" ]; then
        return 0
    else
        return 1
    fi
}

get_current_bbr_status() {
    local bbr_status
    bbr_status=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [ "$bbr_status" = "bbr" ]; then
        echo "Enabled"
    else
        echo "Disabled"
    fi
}

check_bbr_support() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1-2)
    local major=$(echo $kernel_version | cut -d. -f1)
    local minor=$(echo $kernel_version | cut -d. -f2)
    
    if [ "$major" -gt 4 ] || ([ "$major" -eq 4 ] && [ "$minor" -ge 9 ]); then
        return 0
    else
        return 1
    fi
}

install_bbr() {
    local current_status=$(get_current_bbr_status)
    
    if [ "$current_status" = "Enabled" ]; then
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z2BBR Already Enabled\Zn" \
            --msgbox "\n\Z2TCP BBR is already enabled on this system.\Zn\n\Z3Current status: BBR Active\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
        return
    fi
    
    if ! check_bbr_support; then
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z1Kernel Not Supported\Zn" \
            --msgbox "\n\Z1Your kernel version does not support BBR.\Zn\n\Z3BBR requires Linux kernel 4.9 or higher.\Zn\n\Z3Current kernel: $(uname -r)\Zn\n\Z3Please upgrade your kernel first.\Zn" 16 75
        return
    fi
    
    local confirmation
    confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Install TCP BBR\Zn" \
        --inputbox "\n\Z2TCP BBR improves network performance significantly\Zn\n\Z3Benefits:\Zn\Z3• Higher bandwidth utilization\Zn\Z3• Lower latency\Zn\Z3• Better congestion control\Zn\Z3• Up to 8x speed improvement reported\Zn\n\Z1Type 'INSTALL' to enable BBR:\Zn" 18 80 2>&1 >/dev/tty)
    
    if [ "$confirmation" = "INSTALL" ]; then
        local config_added=false
        
        if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
            echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
            config_added=true
        fi
        
        if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
            echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
            config_added=true
        fi
        
        if [ "$config_added" = true ]; then
            sudo sysctl -p > /dev/null 2>&1
            
            local new_status=$(get_current_bbr_status)
            if [ "$new_status" = "Enabled" ]; then
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2BBR Installed Successfully\Zn" \
                    --msgbox "\n\Z2TCP BBR has been enabled successfully!\Zn\n\Z3Status: BBR Active\Zn\n\Z3Your network performance should improve significantly.\Zn\n\Z3No reboot required - BBR is active immediately.\Zn\n\n\Z3$CREATOR_INFO\Zn" 16 80
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1BBR Installation Issue\Zn" \
                    --msgbox "\n\Z1BBR configuration added but not immediately active.\Zn\n\Z3This may be normal on some systems.\Zn\Z3Try rebooting the server to activate BBR.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
            fi
        else
            dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z3BBR Already Configured\Zn" \
                --msgbox "\n\Z3BBR configuration already exists in sysctl.conf\Zn\n\Z3Applying configuration...\Zn" 12 70
            sudo sysctl -p > /dev/null 2>&1
        fi
    else
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z1Installation Cancelled\Zn" \
            --msgbox "\n\Z1BBR installation cancelled.\Zn" 10 55
    fi
}
    local current_port
    current_port=$(sudo grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ -z "$current_port" ]; then
        echo "22"
    else
        echo "$current_port"
    fi
}

change_ssh_port() {
    local current_port=$(get_current_ssh_port)
    local new_port
    
    new_port=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Change SSH Port\Zn" \
        --inputbox "\n\Z2Current SSH Port: $current_port\Zn\n\Z2Enter new SSH port (1024-65535):\Zn\n\Z4Recommended range: 1024-49151\Zn\n\Z4Avoid: 80, 443, 21, 25, 53, 110, 143, 993, 995\Zn" 17 75 2>&1 >/dev/tty)
    
    if [ -n "$new_port" ]; then
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
            local confirmation
            confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Confirm Port Change\Zn" \
                --inputbox "\n\Z1Type 'CHANGE' to confirm changing SSH port from $current_port to $new_port:\Zn\n\Z3Warning: Make sure you can access the new port!\Zn" 14 80 2>&1 >/dev/tty)
            
            if [ "$confirmation" = "CHANGE" ]; then
                sudo sed -i "s/^#*Port .*/Port $new_port/" /etc/ssh/sshd_config
                if ! grep -q "^Port $new_port" /etc/ssh/sshd_config; then
                    echo "Port $new_port" | sudo tee -a /etc/ssh/sshd_config > /dev/null
                fi
                
                local distro=$(detect_linux_distribution)
                if [ "$distro" = "rhel" ]; then
                    sudo systemctl restart sshd
                else
                    sudo systemctl restart ssh
                fi
                
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2Port Changed Successfully\Zn" \
                    --msgbox "\n\Z2SSH port changed from $current_port to $new_port\Zn\n\Z3SSH service has been restarted\Zn\n\Z1Important: Use port $new_port for future connections!\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 80
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1SSH port change cancelled\Zn" 12 55
            fi
        else
            dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Invalid Port\Zn" \
                --msgbox "\n\Z1Invalid port number!\Zn\n\Z3Port must be between 1024-65535\Zn" 12 65
        fi
    fi
}

generate_user_statistics() {
    "$CONFIG_DIR/traffic-parser" -type=csv /var/log/netadminplus-ssh/* > traffic-data.csv
    local counter=1
    local target_users
    
    if [ -n "$1" ]; then
        target_users="$1"
    else
        target_users=$(get_system_users)
    fi

    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          $PANEL_NAME - Traffic Statistics                       ║"
    echo "╠═══════╦═══════════════════════════════════╦══════════════╦══════════════════════╣"
    echo "║   #   ║             Username              ║  Upload(MB)  ║    Download(MB)      ║"
    echo "╠═══════╬═══════════════════════════════════╬══════════════╬══════════════════════╣"
    
    for current_user in $target_users; do
        upload_total=0
        download_total=0
        rm -f user-temp.csv
        cat traffic-data.csv | grep ",$current_user," > user-temp.csv
        
        while IFS=, read -r timestamp upload download username filepath machine; do
            if [ -n "$upload" ]; then
                upload_total=$(echo "$upload_total + ($upload / 1024)" | bc)
            fi
            if [ -n "$download" ]; then
                download_total=$(echo "$download_total + ($download / 1024)" | bc)
            fi
        done < user-temp.csv

        local display_name
        if check_user_suspended "$current_user"; then
            display_name="$current_user (suspended)"
        else
            display_name="$current_user"
        fi

        upload_formatted=$(echo $upload_total | numfmt --grouping)
        download_formatted=$(echo $download_total | numfmt --grouping)

        printf "║ %5d ║  %-32s ║  %10s  ║  %18s  ║\n" $counter "$display_name" "$upload_formatted" "$download_formatted"
        counter=$((counter + 1))
    done
    
    rm -f user-temp.csv traffic-data.csv
    echo "╚═══════╩═══════════════════════════════════╩══════════════╩══════════════════════╝"
    echo ""
    echo "$CREATOR_INFO"
    echo "$YOUTUBE_CHANNEL"
    echo ""
    echo "Press Enter to return to main menu..."
    read
}

handle_user_management() {
    local search_filter="$1"
    local available_users=$(get_system_users)
    
    if [ -n "$search_filter" ]; then
        local filtered_list=""
        for user in $available_users; do
            if echo "$user" | grep -q "$search_filter"; then
                filtered_list="$filtered_list $user"
            fi
        done
        available_users="$filtered_list"
    fi

    local menu_index=1
    local menu_options=""
    local user_array=""

    for user in $available_users; do
        local user_display
        if check_user_suspended "$user"; then
            user_display="$user (suspended)"
        else
            user_display="$user"
        fi
        menu_options="$menu_options $menu_index \"$user_display\""
        user_array="$user_array$user "
        menu_index=$((menu_index + 1))
    done

    if [ -z "$menu_options" ]; then
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z3User Management\Zn" \
            --msgbox "\n\Z1No users found matching your criteria.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
        return
    fi

    local selected_index
    selected_index=$(eval "dialog --colors --backtitle \"\Z1$MAIN_TITLE\Zn\" \
        --title \"\Z3Select User to Manage\Zn\" \
        --menu \"\n\Z2Choose a user:\Zn\" 35 90 20 $menu_options" 2>&1 >/dev/tty)

    if [ -n "$selected_index" ]; then
        local selected_user
        selected_user="$(echo "$user_array" | cut -d " " -f "$selected_index")"
        show_user_actions "$selected_user"
    fi
}

show_user_actions() {
    local target_user="$1"
    
    local action_choice
    action_choice=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Managing User: $target_user\Zn" \
        --menu "\n\Z2Select an action:\Zn" 24 75 8 \
            1 "View Statistics" \
            2 "Change Password" \
            3 "Suspend Account" \
            4 "Delete User" \
            5 "Back to Menu" \
        2>&1 >/dev/tty)

    case "$action_choice" in
        1)
            generate_user_statistics "$target_user"
            ;;
        2)
            clear
            echo "Changing password for user: $target_user"
            echo "----------------------------------------"
            sudo passwd "$target_user"
            dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z2Success\Zn" \
                --msgbox "\n\Z2Password updated successfully for user: $target_user\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
            ;;
        3)
            local confirmation
            confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Suspend User Account\Zn" \
                --inputbox "\n\Z1Type '$target_user' to confirm suspension:\Zn" 14 75 2>&1 >/dev/tty)

            if [ "$target_user" = "$confirmation" ]; then
                sudo passwd -e "$target_user"
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2Account Suspended\Zn" \
                    --msgbox "\n\Z2User '$target_user' has been suspended successfully.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Suspension cancelled - confirmation failed.\Zn" 12 65
            fi
            ;;
        4)
            local confirmation
            confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Delete User Account\Zn" \
                --inputbox "\n\Z1Type '$target_user' to confirm deletion:\Zn" 14 75 2>&1 >/dev/tty)

            if [ "$target_user" = "$confirmation" ]; then
                sudo userdel -r "$target_user"
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2User Deleted\Zn" \
                    --msgbox "\n\Z2User '$target_user' has been deleted successfully.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Deletion cancelled - confirmation failed.\Zn" 12 65
            fi
            ;;
    esac
}

create_new_user() {
    local new_username
    new_username=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Create New User\Zn" \
        --inputbox "\n\Z2Enter username for new account:\Zn" 14 65 2>&1 >/dev/tty)

    if [ -n "$new_username" ]; then
        local distro=$(detect_linux_distribution)
        if [ "$distro" = "rhel" ]; then
            sudo adduser --shell /usr/sbin/nologin "$new_username"
        else
            sudo adduser --shell /usr/sbin/nologin --no-create-home --disabled-password --gecos "" "$new_username"
        fi
        
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z2User Created\Zn" \
            --msgbox "\n\Z2User '$new_username' created successfully.\Zn\n\Z3Now setting password...\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
        
        clear
        echo "Setting password for new user: $new_username"
        echo "--------------------------------------------"
        sudo passwd "$new_username"
        
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z2Setup Complete\Zn" \
            --msgbox "\n\Z2User '$new_username' is ready to use!\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
    else
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z1Operation Cancelled\Zn" \
            --msgbox "\n\Z1User creation cancelled.\Zn" 12 55
    fi
}

handle_statistics_menu() {
    local stats_choice
    stats_choice=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Traffic Statistics\Zn" \
        --menu "\n\Z2Select statistics option:\Zn" 20 75 6 \
            1 "View All Users Statistics" \
            2 "Clear All Statistics" \
            3 "Back to Main Menu" \
        2>&1 >/dev/tty)

    case "$stats_choice" in
        1)
            generate_user_statistics
            ;;
        2)
            local clear_confirmation
            clear_confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Clear Statistics\Zn" \
                --inputbox "\n\Z1Type 'CLEAR' to confirm deletion of all statistics:\Zn" 14 75 2>&1 >/dev/tty)
            
            if [ "$clear_confirmation" = "CLEAR" ]; then
                sudo rm -rf /var/log/netadminplus-ssh/*
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2Statistics Cleared\Zn" \
                    --msgbox "\n\Z2All traffic statistics have been cleared successfully.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 80
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Statistics clearing cancelled.\Zn" 12 65
            fi
            ;;
    esac
}

search_users() {
    local search_term
    search_term=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Search Users\Zn" \
        --inputbox "\n\Z2Enter username or partial name to search:\Zn" 14 65 2>&1 >/dev/tty)
    
    if [ -n "$search_term" ]; then
        handle_user_management "$search_term"
    fi
}

show_about_info() {
    local current_port=$(get_current_ssh_port)
    local bbr_status=$(get_current_bbr_status)
    dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3About NetAdminPlus SSH VPN Manager\Zn" \
        --msgbox "\n\Z2$PANEL_NAME v$PANEL_VERSION\Zn\n\n\Z3A Simple SSH VPN User Manager\Zn\n\Z3Features:\Zn\n• User traffic monitoring\n• Account management\n• Statistics tracking\n• SSH port configuration\n• TCP BBR optimization\n• Secure operations\n\n\Z1Current SSH Port: $current_port\Zn\n\Z1BBR Status: $bbr_status\Zn\n\n\Z3$CREATOR_INFO\Zn\n\Z4$YOUTUBE_CHANNEL\Zn\n\n\Z5Licensed under GNU AGPL v3\Zn" 28 85
}

main_menu_loop() {
    while true; do
        local current_port=$(get_current_ssh_port)
        local bbr_status=$(get_current_bbr_status)
        local menu_choice
        menu_choice=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z3NetAdminPlus SSH VPN Manager\Zn" \
            --no-cancel \
            --menu "\n\Z3$CREATOR_INFO\Zn\n\Z4$YOUTUBE_CHANNEL\Zn\n\Z1Current SSH Port: $current_port\Zn\n\Z1BBR Status: $bbr_status\Zn\n\n\Z7Select an option:\Zn" 32 85 10 \
                1 "➕ Create New User" \
                2 "👥 Manage User Accounts" \
                3 "🔍 Search Users" \
                4 "📊 View Traffic Statistics" \
                5 "📈 Statistics Options" \
                6 "🔧 Change SSH Port" \
                7 "🚀 Install BBR" \
                8 "ℹ️  About" \
                9 "🚪 Exit Panel" \
            2>&1 >/dev/tty)

        case "$menu_choice" in
            1)
                create_new_user
                ;;
            2)
                handle_user_management
                ;;
            3)
                search_users
                ;;
            4)
                generate_user_statistics
                ;;
            5)
                handle_statistics_menu
                ;;
            6)
                change_ssh_port
                ;;
            7)
                install_bbr
                ;;
            8)
                show_about_info
                ;;
            9)
                clear
                echo ""
                echo "╔════════════════════════════════════════════════════════════════════════════════╗"
                echo "║                         Created with ❤️  by Ramtin                            ║"
                echo "║                       https://YouTube.com/NetAdminPlus                        ║"
                echo "╚════════════════════════════════════════════════════════════════════════════════╝"
                echo ""
                exit 0
                ;;
        esac
    done
}

if [ ! -f "$CONFIG_DIR/traffic-parser" ]; then
    dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z1Missing Components\Zn" \
        --msgbox "\n\Z1Traffic parser not found!\Zn\n\Z3Please run the installer first.\Zn\n\n\Z3$CREATOR_INFO\Zn" 14 75
    exit 1
fi

main_menu_loop
