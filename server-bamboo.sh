#!/bin/bash
#
#Script to quickly configure C2 and other servers adapted from : https://github.com/n0pe-sled/Postfix-Server-Setup/blob/master/ServerSetup.sh
#By Matt Dunn (MattThePlanet)

if [[ $EUID -ne 0 ]]; then
	echo "Please run this script as root" 1>&2
	exit 1
fi

### Functions ###

#Create basic user group, configure SSH and install software
kali_initialize() {
    echo ""
    echo "This performs the initial server setup such as a limited user group creation and SSH setup"
    echo ""
    echo "*****WARN: This will disable Root and password login in SSH"
    echo ""
    read -p "Did you create a non-root user with an SSH key and sudo access?  (Y/N)" -n 1 -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Please create a non-root user with an SSH key and sudo access before continuing"
		exit 1
    fi
	echo ""
	echo "Updating Server"
	#You could adjust the two lines below to make them quieter with the -qq option and redirect output to >/dev/null
	apt-get update
	apt-get dist-upgrade -y
	echo ""
	echo "Creating basic users group"
	basicusers=""
	. ./bamboo.conf
	
	#Check for basic users group
	if [ -z "$basicusers" ]
	then 
		#Get Admin internet IPs
		echo ""
		echo "Enter a group name for basic users who have limited access" 
		read basicusers
		echo ""
	fi
	groupadd $basicusers

	echo "Installing Screen"
	apt-get -qq install screen -y
	echo ""
	echo "*********************************************************************************" 
	echo "Remember to manually edit the Sudoers file to add the required sudo access for basic users on this server"
	echo "Configuring SSH"
	systemctl enable ssh.service
	systemctl start ssh.service
	#Secure SSH 
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
	sed -i 's/\PermitRootLogin.*/PermitRootLogin\ no/' /etc/ssh/sshd_config
	sed -i 's/\#PermitRootLogin.*/PermitRootLogin\ no/' /etc/ssh/sshd_config
	sed -i 's/PasswordAuthentication.*/PasswordAuthentication\ no/' /etc/ssh/sshd_config
	sed -i 's/\#PasswordAuthentication.*/PasswordAuthentication\ no/' /etc/ssh/sshd_config
	service sshd restart
}

#Create sudo user accounts, add them to groups, create ssh config and key files
add_sudo_users() {
    echo ""
    echo "Create sudo users"
	echo ""
	echo "Creating Privileged Users"
	echo "Enter usernames separated by commas with no spaces e.g. mark,tom,paul,lynn,kat"
	read users
	for i in $(echo $users | sed "s/,/ /g")
	do
		#Create a user account for each user and other stuff
		adduser --gecos "" $i
		usermod -a -G ssh $i
		usermod -a -G sudo $i
		basicusers=""
		. ./bamboo.conf
		#Check basic users group existance
		if [ -z "$basicusers" ]
		then 
			#Get basic users group"
			echo ""
			echo "Enter the group name for basic users who have limited access"
			read basicusers
			echo ""
		fi
		usermod -a -G $basicusers $i
		#add ssh stuff
		mkdir /home/$i/.ssh
		chown $i /home/$i/.ssh
		chgrp $i /home/$i/.ssh
		chmod 700 /home/$i/.ssh
		echo ""
		echo "***************************"
		echo "Input ssh public key for $i"
		read sshkey
		echo $sshkey > /home/$i/.ssh/authorized_keys
		chmod 600 /home/$i/.ssh/authorized_keys
		chown $i /home/$i/.ssh/authorized_keys
	done
}

#Create limited user accounts, add them to groups, create ssh config and key files
add_basic_users() {
    echo ""
    echo "Create limited sudo user accounts and add them to the basic users group"
    echo "*******************************************************************************"
	echo "Enter usernames separated by commas with no spaces e.g. mark,tom,paul,lynn,kat"
	read users
	basicusers=""
	. ./bamboo.conf
	#Check basic users group existance
	if [ -z "$basicusers" ]
	then 
		#Get basic users group"
		echo ""
		echo "Enter the group name for basic users who have limited access"
		read basicusers
		echo ""
	fi
	for i in $(echo $users | sed "s/,/ /g")
	do
		#Create a user account for each user and other stuff
		adduser --gecos "" $i
		usermod -a -G ssh $i
		usermod -a -G $basicusers $i
		#add ssh stuff
		mkdir /home/$i/.ssh
		chown $i /home/$i/.ssh
		chmod 700 /home/$i/.ssh
		echo "input ssh public key for $i"
		read sshkey
		echo $sshkey > /home/$i/.ssh/authorized_keys
		chmod 600 /home/$i/.ssh/authorized_keys
		chown $i /home/$i/.ssh/authorized_keys
	done
}

#Create admin access roles (Such as teamserver and ssh access to a Cobalt Strike server)
admincs_firewall() {

	echo "Setting CS admin access firewall rules."
    echo ""
	echo "Current Rules"
	iptables -L 
	read -p "Nuke current IPtables rules? Y/N " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		iptables -P INPUT ACCEPT
		iptables -P FORWARD ACCEPT
		iptables -P OUTPUT ACCEPT
		iptables -F
		iptables -L
	fi
	echo "IP Tables Rules Nuked"
	echo ""
	echo "Creating admin access rules for your server"

    #check if adminips or ports are set in config file
	adminips=""
	adminports=""
	. ./bamboo.conf
	
	#Check admin ips
	if [ -z "$adminips" ]
	then 
		#Get Admin internet IPs
		echo ""
		echo "Enter admin IP addresses or CIDR ranges in comma separated format e.g. 10.1.1.1,10.2.1.1 or 10.1.0.0/24,10.1.1.5: " 
		read adminips
		echo ""
	fi

	#Check for admin ports
	if [ -z "$adminports" ]
	then 
		#Get Admin internet IPs
		echo ""
		echo "Enter admin ports to allow connection to in comma separated format (e.g. 50050,22 )" 
		read adminports
		echo ""
	fi

	#Set admin access
	echo "Configuring firewall rules"
	iptables -A INPUT -s $adminips -p tcp --match multiport --dport $adminports -j ACCEPT
	
    #Allow related and already established connections, which could be needed in some cases for the web server and what not
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	
    #Set default INPUT, FOWARD and OUTPUT rules
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT ACCEPT

    #Save the updated rules
	mkdir -p /etc/iptables
    sh -c 'iptables-save > /etc/iptables/rules.v4'

    #Ensure Firewall Rules load at boot
	if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
    	echo "setting up iptables on boot"
		sh -c  'echo "#!/bin/bash" > /etc/network/if-pre-up.d/iptables'
		sh -c 'echo "/sbin/iptables-restore < /etc/iptables/rules.v4" >> /etc/network/if-pre-up.d/iptables'
		sh -c 'chmod 755 /etc/network/if-pre-up.d/iptables'
	fi
	
}

#Add client IPs or ranges to allow access on any desired ports
clientips_firewall() {
    echo ""
	echo "This will add new ALLOWED victim IPs/Ranges to the existing Iptables ruleset"
	echo ""
	echo "Enter the VICTIM IP addresses or CIDR ranges in comma separated format e.g. 10.1.1.1,10.2.1.1 or 10.1.0.0/24,10.1.1.5: " 
	read ips
	echo ""
	#Check for victim ports
	victimports=""
	. ./bamboo.conf
	if [ -z "$victimports" ]
	then 
		#Get victim ports
		echo ""
		echo "Enter the ports to allow access to from the victim IP addresses, in a comma separated format e.g. 443,80,1337:"
		read victimports
		echo "***********************************************************"
		echo ""
	fi
	
	iptables -A INPUT -s $ips -p tcp --match multiport --dport $victimports -j ACCEPT
    #Save the updated rules
	mkdir -p /etc/iptables
    sh -c 'iptables-save > /etc/iptables/rules.v4'

     #Ensure Firewall Rules load at boot
	if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
    	echo "setting up iptables on boot"
		sh -c  'echo "#!/bin/bash" > /etc/network/if-pre-up.d/iptables'
		sh -c 'echo "/sbin/iptables-restore < /etc/iptables/rules.v4" >> /etc/network/if-pre-up.d/iptables'
		sh -c 'chmod 755 /etc/network/if-pre-up.d/iptables'
	fi
}

#Add client IPs or ranges to allow access on any desired ports
custom_firewall() {
    echo ""
	echo "This will help you add custom Iptables ALLOW rules to the existing ruleset"
	echo ""
	echo "Enter IP addresses or CIDR ranges to allow in comma separated format e.g. 10.1.1.1,10.2.1.1 or 10.1.0.0/24,10.1.1.5: " 
	read customips
	echo ""

	#Get ports to allow
	echo ""
	echo "Enter the ports to allow access to from the new IP addresses, in a comma separated format e.g. 443,80,1337:"
	read customports
	echo "***********************************************************"
	echo ""

	
	iptables -A INPUT -s $customips -p tcp --match multiport --dport $customports -j ACCEPT
    #Save the updated rules
	mkdir -p /etc/iptables
    sh -c 'iptables-save > /etc/iptables/rules.v4'

     #Ensure Firewall Rules load at boot
	if [ ! -f /etc/network/if-pre-up.d/iptables ]; then
    	echo "setting up iptables on boot"
		sh -c  'echo "#!/bin/bash" > /etc/network/if-pre-up.d/iptables'
		sh -c 'echo "/sbin/iptables-restore < /etc/iptables/rules.v4" >> /etc/network/if-pre-up.d/iptables'
		sh -c 'chmod 755 /etc/network/if-pre-up.d/iptables'
	fi
}



# Menu
all_done=0
while (( !all_done )); do
    options=("Kali Prep" "Add Sudo Users" "Add Basic Users" "Firewall - Configure Admin Access" "Firewall - Add Victim IPs/Networks" "Firewall - Add Custom Rules" "Quit")
	echo ""
	echo "Server Bamboo is a tool to quickly configure, manage and secure pentest servers"
	echo ""
	echo "***BE SURE TO EDIT THE bamboo.conf file with your static entries to save time!!!***"
	echo ""
    echo "Choose an option: "
    select opt in "${options[@]}"; do
        case $REPLY in
            1) kali_initialize;break ;;
            2) add_sudo_users; break ;;
			3) add_basic_users;break ;;
			4) admincs_firewall;break ;;
			5) clientips_firewall;break ;;
			6) custom_firewall;break ;;
			7) all_done=2; break ;;
			*) echo "Invalid Option Selected";;
        esac
    done
done

echo "Goodbye"




