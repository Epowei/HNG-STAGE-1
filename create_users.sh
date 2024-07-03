#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Set log file and secure password file locations
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create the log file and secure password file with the correct permission if it does not exist
setup_files() {
  if [ ! -d "/var/log" ]; then
    mkdir -p "/var/log"
  fi

  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
  fi

  if [ ! -d "/var/secure" ]; then
    mkdir -p "/var/secure"
  fi

  if [ ! -f "$PASSWORD_FILE" ]; then
    touch "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
  fi
}

# Function to generate a random password
generate_password() {
  local password=$(openssl rand -base64 12)
  echo "$password"
}

# Log actions
log_action() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

USER_FILE="$1"

# Ensure the user file exists
if [ ! -f "$USER_FILE" ]; then
  echo "User file not found!"
  exit 1
fi

# Setup log and password files
setup_files

# Process the user file
while IFS=';' read -r username groups; do
  # Remove whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  
  # Skip empty lines
  if [ -z "$username" ]; then
    continue
  fi
  
  # Create user if it doesn't exist
  if id "$username" &>/dev/null; then
    log_action "User $username already exists. Skipping creation."
  else
    # Create the user's personal group
    if ! getent group "$username" &>/dev/null; then
      groupadd "$username"
      log_action "Created group $username."
    fi

    # Create the user and add to the personal group
    useradd -m -g "$username" "$username"
    log_action "Created user $username with personal group $username."

    # Generate a random password and set it for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    log_action "Set password for user $username."

    # Store the password securely
    echo "$username:$password" >> "$PASSWORD_FILE"
  fi
  
  # Add user to additional groups
  if [ -n "$groups" ]; then
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
      group=$(echo "$group" | xargs) # Remove whitespace
      if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        log_action "Created group $group."
      fi
      usermod -aG "$group" "$username"
      log_action "Added user $username to group $group."
    done
  fi
  
  # Set appropriate permissions for the home directory
  chmod 700 "/home/$username"
  chown "$username:$username" "/home/$username"
  log_action "Set permissions for /home/$username."

done < "$USER_FILE"

log_action "User creation and configuration completed."

echo "User creation and configuration completed. Check $LOG_FILE for details."
