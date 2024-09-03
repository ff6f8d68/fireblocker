#!/bin/bash

# Fireblocker Script

# Detect OS
OS="$(uname -s)"

# Function to set up firewall rules
setup_firewall() {
    echo "Setting up firewall..."

    # Flush existing rules
    iptables -F
    iptables -X

    # Allow loopback interface (localhost)
    iptables -A INPUT -i lo -j ACCEPT

    # Allow established and related incoming connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow SSH connections on port 22
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # Block all other incoming connections by default
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    # Log dropped packets
    iptables -A INPUT -j LOG --log-prefix "Dropped: " --log-level 4

    echo "Firewall rules set up."
}

# Function to check software certificates (cross-platform)
check_certificates() {
    echo "Checking software certificates..."

    case "$OS" in
        Linux*)
            for file in /usr/bin/*; do
                if ! openssl dgst -sha256 "$file" | grep -q "CN=Microsoft" && ! openssl dgst -sha256 "$file" | grep -q "CN=Apple"; then
                    echo "Unsigned or suspicious software found: $file"
                    echo "$file" >> /var/log/fireblocker/unsigned_software.log
                fi
            done
            ;;
        Darwin*)
            for app in /Applications/*.app; do
                if ! codesign -dv --verbose=4 "$app" 2>&1 | grep -q "Authority=Apple"; then
                    echo "Unsigned or suspicious software found: $app"
                    echo "$app" >> /var/log/fireblocker/unsigned_software.log
                fi
            done
            ;;
        CYGWIN*|MINGW*|MSYS*)
            powershell -Command "
                Get-ChildItem 'C:\Program Files\' -Recurse -File |
                ForEach-Object {
                    \$cert = (Get-AuthenticodeSignature \$_).SignerCertificate
                    if (\$cert -eq \$null -or (\$cert.Subject -notlike '*Microsoft*' -and \$cert.Subject -notlike '*Apple*')) {
                        Write-Output \"Unsigned or suspicious software found: \$_\"
                        Add-Content -Path 'C:\fireblocker\unsigned_software.log' -Value \$_
                    }
                }
            "
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Function to scan for malicious activity (cross-platform)
scan_malicious_activity() {
    echo "Scanning for potentially malicious activity..."

    case "$OS" in
        Linux*|Darwin*)
            tcpdump -i any -w /var/log/fireblocker/suspicious_activity.pcap -c 100 > /dev/null 2>&1
            strings /var/log/fireblocker/suspicious_activity.pcap | grep "suspicious_pattern" > /var/log/fireblocker/malware_detected.txt

            if [[ -s /var/log/fireblocker/malware_detected.txt ]]; then
                echo "Potentially malicious activity detected. Creating antivirus..."
                create_antivirus /var/log/fireblocker/malware_detected.txt
            else
                echo "No malicious activity detected."
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            powershell -Command "
                netsh trace start capture=yes tracefile=C:\fireblocker\suspicious_activity.etl
                Start-Sleep -Seconds 30
                netsh trace stop
                Get-WinEvent -Path 'C:\fireblocker\suspicious_activity.etl' | Select-String -Pattern 'suspicious_pattern' > 'C:\fireblocker\malware_detected.txt'

                if (Test-Path 'C:\fireblocker\malware_detected.txt') {
                    Write-Output 'Potentially malicious activity detected. Creating antivirus...'
                    .\fireblocker.sh create-antivirus 'C:\fireblocker\malware_detected.txt'
                } else {
                    Write-Output 'No malicious activity detected.'
                }
            "
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Function to create antivirus signatures or block rules dynamically
create_antivirus() {
    local malware_file="$1"
    echo "Creating antivirus signature for detected malware..."

    case "$OS" in
        Linux*|Darwin*)
            while IFS= read -r line; do
                ip=$(echo $line | awk '{print $1}')
                pattern=$(echo $line | awk '{print $3}')

                if [[ $pattern == "suspicious_pattern" ]]; then
                    echo "Blocking IP: $ip"
                    iptables -A INPUT -s $ip -j DROP
                fi
            done < "$malware_file"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            powershell -Command "
                \$content = Get-Content '$malware_file'
                foreach (\$line in \$content) {
                    \$ip, \$pattern = \$line -split ' '
                    if (\$pattern -eq 'suspicious_pattern') {
                        Write-Output \"Blocking IP: \$ip\"
                        New-NetFirewallRule -DisplayName 'Block Malicious IP' -Direction Inbound -LocalPort Any -RemoteAddress \$ip -Action Block
                    }
                }
            "
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    echo "Antivirus signature created and applied."
}

# Function to schedule low-intensity scans every hour
schedule_scan_low() {
    while true; do
        echo "Running scheduled low-intensity scan..."
        check_certificates
        scan_malicious_activity
        sleep 3600  # Sleep for 1 hour
    done &
}

# Function to monitor for new files downloaded from the internet
monitor_downloads() {
    echo "Monitoring for new downloads..."

    case "$OS" in
        Linux*)
            inotifywait -m -e close_write --format '%w%f' "$HOME/Downloads" | while read file; do
                echo "New file downloaded: $file"
                scan_deep "$file"
            done
            ;;
        Darwin*)
            fswatch -o "$HOME/Downloads" | while read event; do
                echo "New file downloaded."
                scan_deep
            done
            ;;
        CYGWIN*|MINGW*|MSYS*)
            powershell -Command "
                \$watcher = New-Object System.IO.FileSystemWatcher
                \$watcher.Path = '$env:USERPROFILE\Downloads'
                \$watcher.Filter = '*.*'
                \$watcher.EnableRaisingEvents = \$true
                \$watcher.IncludeSubdirectories = \$false
                \$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite'

                Register-ObjectEvent \$watcher 'Created' -Action {
                    Write-Output \"New file downloaded: \$Event.SourceEventArgs.FullPath\"
                    .\fireblocker.sh scan-deep
                }
                while (\$true) { Start-Sleep -Seconds 1 }
            "
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Function to monitor for new drives
monitor_new_drives() {
    echo "Monitoring for new drives..."

    case "$OS" in
        Linux*)
            udevadm monitor --subsystem-match=block | while read -r line; do
                if [[ "$line" =~ "add" ]]; then
                    echo "New drive detected."
                    scan_deep
                fi
            done
            ;;
        Darwin*)
            while true; do
                sleep 5
                if diskutil list | grep -q 'external'; then
                    echo "New external drive detected."
                    scan_deep
                fi
            done
            ;;
        CYGWIN*|MINGW*|MSYS*)
            powershell -Command "
                while (\$true) {
                    Get-WmiObject Win32_DiskDrive | Where-Object { \$_.InterfaceType -eq 'USB' } | ForEach-Object {
                        Write-Output 'New USB drive detected.'
                        .\fireblocker.sh scan-deep
                    }
                    Start-Sleep -Seconds 5
                }
            "
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Function to perform a deep scan
scan_deep() {
    echo "Performing a deep scan for malware..."

    case "$OS" in
        Linux*|Darwin*|CYGWIN*|MINGW*|MSYS*)
            check_certificates
            scan_malicious_activity
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Start the firewall and other monitoring services
case "$1" in
    start)
        setup_firewall
        schedule_scan_low
        monitor_downloads
        monitor_new_drives
        ;;
    stop)
        echo "Stopping Fireblocker..."
        iptables -F
        kill $(jobs -p)
        ;;
    scan-low)
        check_certificates
        scan_malicious_activity
        ;;
    scan-deep)
        scan_deep
        ;;
    *)
        echo "Usage: $0 {start|stop|scan-low|scan-deep}"
        ;;
esac
