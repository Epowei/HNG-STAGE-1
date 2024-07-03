As a SysOps engineer, automating user creation and management is essential for maintaining system efficiency and security, especially when onboarding new developers. This article presents a robust Bash script to read a text file with usernames and group names, create the necessary users and groups, set up home directories, generate random passwords, and log all actions. 

This task was given as part of HNG internship program - more info at [hng internship](https://hng.tech/internship)
Find and hire elite freelance talent at  https://hng.tech/hire

## Script Overview
The script, create_users.sh, performs the following tasks:

1. Read a text file with user and group information.
2. Create users and groups based on the information.
3. Set up home directories with appropriate permissions.
4. Generate random passwords for each user.
5. Log actions to /var/log/user_management.log.
6. Store passwords securely in /var/secure/user_passwords.txt.

## Script Breakdown
**1. Setting Up Log and Password Files**
We start by defining the paths for the log and password files:
```
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
```

The **setup_files** function ensures these files and directories exist with the correct permissions:

```
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
```

**2. Generating Random Passwords**
The **generate_password** function uses OpenSSL to generate a random password:

```
generate_password() {
  local password=$(openssl rand -base64 12)
  echo "$password"
}
```

**3. Logging Actions**
The **log_action** function logs messages to the log file with timestamps:

```
log_action() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}
```

**4. Processing the User File**
The script processes the user file provided as an argument. It reads each line, splits the username and groups, and creates the necessary users and groups:

```
USER_FILE="$1"

if [ ! -f "$USER_FILE" ]; then
  echo "User file not found!"
  exit 1
fi

setup_files

while IFS=';' read -r username groups; do
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  if [ -z "$username" ]; then
    continue
  fi
  
  if id "$username" &>/dev/null; then
    log_action "User $username already exists. Skipping creation."
  else
    if ! getent group "$username" &>/dev/null; then
      groupadd "$username"
      log_action "Created group $username."
    fi

    useradd -m -g "$username" "$username"
    log_action "Created user $username with personal group $username."

    password=$(generate_password)
    echo "$username:$password" | chpasswd
    log_action "Set password for user $username."

    echo "$username:$password" >> "$PASSWORD_FILE"
  fi
  
  if [ -n "$groups" ]; then
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
      group=$(echo "$group" | xargs)
      if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        log_action "Created group $group."
      fi
      usermod -aG "$group" "$username"
      log_action "Added user $username to group $group."
    done
  fi
  
  chmod 700 "/home/$username"
  chown "$username:$username" "/home/$username"
  log_action "Set permissions for /home/$username."

done < "$USER_FILE"

log_action "User creation and configuration completed."

```

**Using the Script**
* Save the Script: Save the script as **create_users.sh**.
* Make the Script Executable:

```
chmod u+x create_users.sh
```

* Prepare the User File: Create a text file (e.g., users.txt) with the following format:

```
light; sudo,dev,www-data
idimma; sudo
mayowa; dev,www-data
```

* Run the Script:

```
sudo ./create_users.sh users.txt
```

**Explanation of the Script**
1. **Setup Files**: The script first ensures that the log file and secure password file exist and have the appropriate permissions.
2. **Read and Process User File**: It reads the user file line by line, processes each username and associated groups, and handles the creation or modification of users and groups.
3. **Error Handling**: The script checks if users or groups already exist and skips creation if they do, logging the actions appropriately.
4. **Security**: Random passwords are generated for each user and stored securely. Permissions for home directories and the password file ensure security and privacy.
5. **Logging:** All actions are logged to /var/log/user_management.log with timestamps for easy auditing and troubleshooting.

### Conclusion
This script automates the tedious task of user creation and management, ensuring consistency and security across your systems. By logging all actions and securely storing passwords, it provides a reliable way to onboard new developers and manage user accounts efficiently.

