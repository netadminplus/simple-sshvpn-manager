#!/bin/bash

PANEL_VERSION="2.0"
PANEL_NAME="NetAdminPlus SSH Manager"
MAIN_TITLE="$PANEL_NAME v$PANEL_VERSION"
CREATOR_INFO="Created with ❤️ by Ramtin"
YOUTUBE_CHANNEL="https://YouTube.com/NetAdminPlus"
GITHUB_REPO="netadminplus/simple-sshvpn-manager"
INSTALL_DIR="simple-sshvpn-manager"
CONFIG_SUBDIR="config"
LOG_DIRECTORY="/var/log/netadminplus-ssh"

update_system_packages() {
    echo "$MAIN_TITLE"
    echo "=================================================="
    echo "Installing required system packages..."
    echo ""
    
    if [ -x "$(command -v yum)" ]; then
        sudo yum -y update > /dev/null 2>&1
        sudo yum -y install nethogs golang dialog bc coreutils unzip curl jq wget > /dev/null 2>&1
    elif [ -x "$(command -v apt-get)" ]; then
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y update > /dev/null 2>&1
        sudo apt-get -y install nethogs golang dialog bc coreutils unzip curl jq wget > /dev/null 2>&1
        sudo DEBIAN_FRONTEND=interactive
    else
        echo "Error: Unsupported Linux distribution"
        echo "This installer supports CentOS/RHEL and Debian/Ubuntu only"
        exit 1
    fi
    
    echo "System packages installed successfully!"
}

download_and_extract() {
    echo "Downloading NetAdminPlus SSH Manager..."
    
    sudo rm -f netadmin-archive.zip
    wget -O netadmin-archive.zip "https://github.com/$GITHUB_REPO/archive/main.zip" > /dev/null 2>&1
    
    if [ ! -f "netadmin-archive.zip" ]; then
        echo "Error: Failed to download archive"
        exit 1
    fi
    
    unzip -q netadmin-archive.zip
    
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p "$INSTALL_DIR"
    fi
    
    sudo rm -rf "$INSTALL_DIR"/*
    sudo mv simple-sshvpn-manager-main/* "$INSTALL_DIR/"
    sudo rm -rf simple-sshvpn-manager-main
    sudo rm -f netadmin-archive.zip
    
    echo "Files extracted successfully!"
}

setup_directory_structure() {
    cd "$INSTALL_DIR/"
    
    sudo mkdir -p "$CONFIG_SUBDIR"
    sudo mkdir -p "$LOG_DIRECTORY"
    
    if [ -f "traffic-monitor.sh" ]; then
        sudo mv traffic-monitor.sh "$CONFIG_SUBDIR/"
    fi
    if [ -f "LICENSE" ]; then
        sudo mv LICENSE "$CONFIG_SUBDIR/"
    fi
    
    sudo chmod +x ssh-manager.sh
    sudo chmod +x "$CONFIG_SUBDIR/traffic-monitor.sh"
    
    echo "Directory structure configured!"
}

build_traffic_parser() {
    echo "Building traffic analysis components..."
    
    wget -O parser-source.go https://raw.githubusercontent.com/boopathi/nethogs-parser/master/hogs.go > /dev/null 2>&1
    
    if [ -f "parser-source.go" ]; then
        sudo go build -o "$CONFIG_SUBDIR/traffic-parser" parser-source.go
        sudo rm -f parser-source.go
        echo "Traffic parser built successfully!"
    else
        echo "Warning: Could not build traffic parser"
    fi
}

setup_monitoring_cron() {
    local cron_command="*/5 * * * * sh $(pwd)/$CONFIG_SUBDIR/traffic-monitor.sh"
    
    if ! crontab -l 2>/dev/null | grep -Fq "$cron_command"; then
        (crontab -l 2>/dev/null; echo "$cron_command") | crontab
        echo "Traffic monitoring scheduled successfully!"
    fi
    
    sudo sh "$CONFIG_SUBDIR/traffic-monitor.sh"
}

complete_installation() {
    cd ..
    sudo rm -f ssh-installer.sh
    
    echo ""
    echo "=================================================="
    echo "Installation completed successfully!"
    echo ""
    echo "$CREATOR_INFO"
    echo "$YOUTUBE_CHANNEL"
    echo ""
    echo "To start the panel, run:"
    echo "  cd $INSTALL_DIR && sh ssh-manager.sh"
    echo ""
    echo "Note: Traffic monitoring will start automatically"
    echo "      Statistics will be available after ~10 minutes"
    echo "=================================================="
}

remove_existing_installation() {
    local old_cron="*/5 * * * * sh $(pwd)/$INSTALL_DIR/$CONFIG_SUBDIR/traffic-monitor.sh"
    
    if crontab -l 2>/dev/null | grep -Fq "$old_cron"; then
        local current_cron
        current_cron=$(crontab -l 2>/dev/null)
        local updated_cron
        updated_cron=$(echo "$current_cron" | grep -Fv "$old_cron")
        echo "$updated_cron" | crontab
    fi
    
    sudo rm -rf "$INSTALL_DIR"
    echo "Previous installation removed successfully!"
}

remove_with_data() {
    remove_existing_installation
    sudo rm -rf "$LOG_DIRECTORY"
    echo "Installation and all data removed successfully!"
}

perform_fresh_install() {
    update_system_packages
    download_and_extract
    setup_directory_structure
    build_traffic_parser
    setup_monitoring_cron
    complete_installation
}

show_upgrade_menu() {
    local user_choice
    user_choice=$(dialog --clear --backtitle "$MAIN_TITLE" \
        --title "Existing Installation Detected" \
        --menu "\n$CREATOR_INFO\n$YOUTUBE_CHANNEL\n\nChoose an action:" 18 70 5 \
            1 "Upgrade to Latest Version" \
            2 "Remove Installation Only" \
            3 "Remove Installation + Data" \
            4 "Cancel Operation" \
        2>&1 >/dev/tty)

    case "$user_choice" in
        1)
            remove_existing_installation
            perform_fresh_install
            ;;
        2)
            remove_existing_installation
            clear
            echo "$MAIN_TITLE has been removed successfully."
            echo "$CREATOR_INFO"
            ;;
        3)
            local confirmation
            confirmation=$(dialog --clear --backtitle "$MAIN_TITLE" \
                --title "Confirm Complete Removal" \
                --inputbox "Type 'REMOVE-ALL' to confirm complete removal:" 10 60 2>&1 >/dev/tty)

            clear
            if [ "$confirmation" = "REMOVE-ALL" ]; then
                remove_with_data
                echo "$MAIN_TITLE and all data removed successfully."
            else
                echo "Operation cancelled!"
            fi
            echo "$CREATOR_INFO"
            ;;
        4)
            clear
            echo "Operation cancelled!"
            echo "$CREATOR_INFO"
            ;;
    esac
}

main() {
    if [ -f "./$INSTALL_DIR/ssh-manager.sh" ]; then
        show_upgrade_menu
    else
        perform_fresh_install
    fi
}

main "$@"
