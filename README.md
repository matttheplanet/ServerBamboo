# ServerBamboo

ServerBamboo is a menu driven Bash script to quickly manage server prep, user creation and the Iptables firewalls on Kali and other Debian based servers.

Created by Matt Dunn

## Installation

Use Git to pull down and use the script.

```bash
git clone https://github.com/matttheplanet/ServerBamboo.git
```

## bamboo.conf

Make sure to update the bamboo.conf file with any static IPs, ports or etc. that you regularly use with ServerBamboo to set them as default. Variables set in bamboo.conf will be automatically used by ServerBamboo.sh

## Usage

```bash
cd ./ServerBamboo
sudo ./ServerBamboo.sh
```
Select your menu option

```bash
Server Bamboo is a tool to quickly configure, manage and secure pentest servers

***BE SURE TO EDIT THE bamboo.conf file with your static entries to save time!!!***

Choose an option: 
1) Kali Prep
2) Add Sudo Users
3) Add Basic Users
4) Firewall - Configure Admin Access
5) Firewall - Add Victim IPs/Networks
6) Firewall - Add Custom Rules
7) Quit
```

### Kali Prep

Run apt updates, enable SSH, disable password and root SSH logins and install the software Screen. MAKE SURE you have a non root account with a functional SSH key configured and tested before running this command.

### Add Sudo Users

Add additional users with Sudo and SSH rights, prompts for password and public SSH key. Creates SSH authorized keys file. Multiple users can be created at once.

### Add Basic Users

Add users with SSH access in your desired basic user group. This will add new users with the option to add their public SSH keys. Useful for creating user accounts for users you don't want full sudo access to the system. Make sure to customize your sudoers file if these users do need some sudo access.

### Firewall - Configure Admin Access

Create Iptables rules to allow administrative access to the server. This can be to allow SSH, Teamserver or other port access to the server that you do not want to expose to the whole Internet. Changes persist reboot in Kali. There is the option when running this feature to wipe existing rulesets, which can be useful for cleaning up a server after a project. 

### Firewall - Add Victim IPs/Networks

Add addtional Iptables rules to allow victims to access your C2 server. Useful for only a client or your test servers access to your C2 servers. Changes persist reboot in Kali.

### Firewall - Add Custom Rules

Add custom TCP allow rules to the firewall. Allow TCP ports to be accessed by the desired IPs/CIDR ranges.

### Quit

Quit ServerBamboo




## License
[GNU GPLV3](https://www.gnu.org/licenses/gpl-3.0.en.html)
