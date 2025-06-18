#!/bin/bash

PANEL_VERSION="2.0"
PANEL_NAME="NetAdminPlus SSH Manager"
MAIN_TITLE="$PANEL_NAME v$PANEL_VERSION"
CREATOR_INFO="Created with ❤️ by Ramtin"
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
    echo "║                          $PANEL_NAME - Traffic Statistics                          ║"
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
            --msgbox "\n\Z1No users found matching your criteria.\Zn\n\n$CREATOR_INFO" 10 60
        return
    fi

    local selected_index
    selected_index=$(eval "dialog --colors --backtitle \"\Z1$MAIN_TITLE\Zn\" \
        --title \"\Z3Select User to Manage\Zn\" \
        --menu \"\n\Z2Choose a user:\Zn\" 25 70 15 $menu_options" 2>&1 >/dev/tty)

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
        --menu "\n\Z2Select an action:\Zn" 18 60 6 \
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
                --msgbox "\n\Z2Password updated successfully for user: $target_user\Zn\n\n$CREATOR_INFO" 10 60
            ;;
        3)
            local confirmation
            confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Suspend User Account\Zn" \
                --inputbox "\n\Z1Type '$target_user' to confirm suspension:\Zn" 10 60 2>&1 >/dev/tty)

            if [ "$target_user" = "$confirmation" ]; then
                sudo passwd -e "$target_user"
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2Account Suspended\Zn" \
                    --msgbox "\n\Z2User '$target_user' has been suspended successfully.\Zn\n\n$CREATOR_INFO" 10 60
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Suspension cancelled - confirmation failed.\Zn" 8 50
            fi
            ;;
        4)
            local confirmation
            confirmation=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                --title "\Z1Delete User Account\Zn" \
                --inputbox "\n\Z1Type '$target_user' to confirm deletion:\Zn" 10 60 2>&1 >/dev/tty)

            if [ "$target_user" = "$confirmation" ]; then
                sudo userdel -r "$target_user"
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2User Deleted\Zn" \
                    --msgbox "\n\Z2User '$target_user' has been deleted successfully.\Zn\n\n$CREATOR_INFO" 10 60
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Deletion cancelled - confirmation failed.\Zn" 8 50
            fi
            ;;
    esac
}

create_new_user() {
    local new_username
    new_username=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Create New User\Zn" \
        --inputbox "\n\Z2Enter username for new account:\Zn" 10 50 2>&1 >/dev/tty)

    if [ -n "$new_username" ]; then
        local distro=$(detect_linux_distribution)
        if [ "$distro" = "rhel" ]; then
            sudo adduser --shell /usr/sbin/nologin "$new_username"
        else
            sudo adduser --shell /usr/sbin/nologin --no-create-home --disabled-password --gecos "" "$new_username"
        fi
        
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z2User Created\Zn" \
            --msgbox "\n\Z2User '$new_username' created successfully.\Zn\n\Z3Now setting password...\Zn\n\n$CREATOR_INFO" 10 60
        
        clear
        echo "Setting password for new user: $new_username"
        echo "--------------------------------------------"
        sudo passwd "$new_username"
        
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z2Setup Complete\Zn" \
            --msgbox "\n\Z2User '$new_username' is ready to use!\Zn\n\n$CREATOR_INFO" 10 60
    else
        dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z1Operation Cancelled\Zn" \
            --msgbox "\n\Z1User creation cancelled.\Zn" 8 40
    fi
}

handle_statistics_menu() {
    local stats_choice
    stats_choice=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Traffic Statistics\Zn" \
        --menu "\n\Z2Select statistics option:\Zn" 15 60 4 \
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
                --inputbox "\n\Z1Type 'CLEAR' to confirm deletion of all statistics:\Zn" 10 60 2>&1 >/dev/tty)
            
            if [ "$clear_confirmation" = "CLEAR" ]; then
                sudo rm -rf /var/log/netadminplus-ssh/*
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z2Statistics Cleared\Zn" \
                    --msgbox "\n\Z2All traffic statistics have been cleared successfully.\Zn\n\n$CREATOR_INFO" 10 60
            else
                dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
                    --title "\Z1Operation Cancelled\Zn" \
                    --msgbox "\n\Z1Statistics clearing cancelled.\Zn" 8 50
            fi
            ;;
    esac
}

search_users() {
    local search_term
    search_term=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3Search Users\Zn" \
        --inputbox "\n\Z2Enter username or partial name to search:\Zn" 10 50 2>&1 >/dev/tty)
    
    if [ -n "$search_term" ]; then
        handle_user_management "$search_term"
    fi
}

show_about_info() {
    dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
        --title "\Z3About NetAdminPlus SSH Manager\Zn" \
        --msgbox "\n\Z2$PANEL_NAME v$PANEL_VERSION\Zn\n\n\Z3A powerful SSH user management tool\Zn\n\Z3Features:\Zn\n• User traffic monitoring\n• Account management\n• Statistics tracking\n• Secure operations\n\n\Z6$CREATOR_INFO\Zn\n\Z4$YOUTUBE_CHANNEL\Zn\n\n\Z5Licensed under GNU AGPL v3\Zn" 20 70
}

main_menu_loop() {
    while true; do
        local menu_choice
        menu_choice=$(dialog --colors --backtitle "\Z1$MAIN_TITLE\Zn" \
            --title "\Z3NetAdminPlus SSH Management Panel\Zn" \
            --no-cancel \
            --menu "\n\Z2$CREATOR_INFO\Zn\n\Z4$YOUTUBE_CHANNEL\Zn\n\n\Z6Select an option:\Zn" 20 70 8 \
                1 "📊 View Traffic Statistics" \
                2 "👥 Manage User Accounts" \
                3 "➕ Create New User" \
                4 "🔍 Search Users" \
                5 "📈 Statistics Options" \
                6 "ℹ️  About" \
                7 "🚪 Exit Panel" \
            2>&1 >/dev/tty)

        case "$menu_choice" in
            1)
                generate_user_statistics
                ;;
            2)
                handle_user_management
                ;;
            3)
                create_new_user
                ;;
            4)
                search_users
                ;;
            5)
                handle_statistics_menu
                ;;
            6)
                show_about_info
                ;;
            7)
                clear
                echo ""
                echo "╔════════════════════════════════════════════════════════════════════════════════╗"
                echo "║                    Thank you for using NetAdminPlus SSH Manager!              ║"
                echo "║                                                                                ║"
                echo "║                         Created with ❤️ by Ramtin                             ║"
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
        --msgbox "\n\Z1Traffic parser not found!\Zn\n\Z3Please run the installer first.\Zn\n\n$CREATOR_INFO" 10 60
    exit 1
fi

main_menu_loop