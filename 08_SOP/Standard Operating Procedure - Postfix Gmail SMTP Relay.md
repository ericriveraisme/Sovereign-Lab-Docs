# Standard Operating Procedure: Postfix Gmail SMTP Relay

## 1. Overview

By default, virtual machines cannot send emails to external addresses (like Gmail or Outlook) without being flagged as spam or blocked outright. This SOP details how to configure Postfix on a local Linux VM to securely authenticate with a Google account using an App Password. This allows internal lab scripts to send critical alerts to an external administrator inbox.

## 2. Prerequisites

- A Google Account.
    
- 2-Step Verification enabled on the Google Account.
    
- A 16-character **Google App Password** generated specifically for this VM.
    

## 3. Installation

Install the necessary mail utilities and the Postfix mail transfer agent.

```
sudo apt update
sudo apt install mailutils postfix -y
```

During the interactive installation (TUI), provide the following answers:

1. **General type of mail configuration:** `Internet Site`
    
2. **System mail name:** `sovereign-ops` (or the respective hostname)
    

_(If you need to re-run the configuration GUI later, use `sudo dpkg-reconfigure postfix`)_

## 4. Configuration

### Step 1: Edit the Main Configuration

Edit the main Postfix configuration file to define the Gmail relay and security parameters.

```
sudo nano /etc/postfix/main.cf
```

Scroll to the bottom of the file. If a `relayhost` line already exists, delete it. Paste the following "Golden Config" block:

```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
header_size_limit = 4096000
inet_protocols = ipv4
```

### Step 2: Provide Google Credentials

Create the password file that Postfix will use to authenticate with Google.

```
sudo nano /etc/postfix/sasl_passwd
```

Add your credentials in the following format (replace `YOUR_APP_PASSWORD` with the 16-character string, no spaces):

```
[smtp.gmail.com]:587  your.email@gmail.com:YOUR_APP_PASSWORD
```

### Step 3: Secure and Hash the Credentials

_(Security+ Principle: Least Privilege & Obfuscation)_

Standard users should not be able to read the plain-text application password. We must restrict file permissions and compile the file into a database format Postfix can read.

```
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
```

## 5. Service Restart and Testing

Restart the Postfix service to apply the new configurations and compiled password hash.

```
sudo systemctl restart postfix
```

Test the outbound relay by sending a test email to your external address:

```
echo "Testing the Sovereign Ops Alert System" | mail -s "Sovereign Lab Test" your.email@gmail.com
```

Check your external inbox (and spam folder). If the email arrives, the SMTP relay is successfully established.