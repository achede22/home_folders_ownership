#!/bin/bash
#set -x
#trap read debug

# Subject: RE: [External] Incident INC7069358 has been assigned to you. Priority: 3 - Moderate Client: ALSC Description: Servers joined with Winbind - Not joined
# 
# Problem is that we’re maintaining the uid incorrect mapping. 
# Delete home directory folders may help for standalone users, but not for existing applications.
# 
# Only option that comes to my mind is to track any uuid that exist previous to the migration. 
# For example, track each owner and uid for each file
# 
# User | UUID
# UserA;100010101
# UserB;100010012
# 
# After track this do a find for any file with that UUID, and change to user string A.
# 
# Regards,
# 
# ________________________________________________________________
# Somebody


# script by Hernán De León
# 2018

#run as root or exit
whoami | grep -v "root" && echo "Run this script as ROOT user" && exit 1

# check if windbind is installed
rpm -qa | grep samba winbind && echo "Oudated windbind found"

service sssd status
id chef_administrator 

# this script it for issued RH6 instances, if not, exit
cat /etc/redhat-release | grep 6 || exit 1

join_ad(){

	mkdir /tmp/AD_packages
	cd /tmp/AD_packages
	curl -O https://s3.amazonaws.com/software-installable-bin/Linux_Scripts/linux_ad_integration.sh
	
	# If there is an error Downloading the linux_ad_integration.sh script.
	head linux_ad_integration.sh | grep "Access Denied" && \
	echo "ERROR: Please whitelist the instance IP in the C3 pfSense to download the linux_ad_integration script."
	
	
	# ASKS for AD Credentials:
	echo "Insert user with \"domain admin\" rights"; read AD_USER
	# echo "Password:"; read AD_PSSWD --> the script will ask for a password
	
	##Get the Active Directory IP from resolv.conf
	export AD_IP=$(cat /etc/resolv.conf | grep -m 1 nameserver | awk '{printf $2}')
	echo "AD IP: $AD_IP"
	#telnet $AD_IP 389

	chmod +x linux_ad_integration.sh 
	./linux_ad_integration.sh --cleanoldconfigs
	
	bash -x linux_ad_integration.sh --install $AD_IP $AD_USER # $AD_PSSWD --> the script will ask for a password

}


#sssd is running or install it! 
service sssd status || join_ad 

#sssd is running or exit 
service sssd status || exit 1 

#AD is working or exit
id chef_administrator || exit 1

echo "AD INTEGRATION IS WORKING"

# create folder
mkdir /tmp/USERS_UID 2> /dev/null
MyFolder="/tmp/USERS_UID"

ls -al | tee $MyFolder/home_ownership_found.txt

echo "Get users name"
# List ONLY folders, and delete the  "/" at the end
cd /home/ # Go to home folder
ls -C1 -d */ > $MyFolder/USERNAME_LIST.txt

## checking if the folders have "/" at the end as : 
#a.dayanand.wadkar/
cat $MyFolder/USERNAME_LIST.txt | grep "/" && ls -C1 -d */ | rev | cut -c 2- | rev | sort > $MyFolder/USERNAME_LIST.txt 

echo "get users id"
cat $MyFolder/USERNAME_LIST.txt  | xargs -L1 id -u  &> $MyFolder/UID_LIST.txt #inclueded error prompt
cat $MyFolder/UID_LIST.txt | grep -i "No such user" > $MyFolder/Users_not_in_AD.txt

echo "join both into a table"
paste $MyFolder/UID_LIST.txt $MyFolder/USERNAME_LIST.txt | grep -iv "No such user" | sort -n > $MyFolder/USERS_TABLE.txt
cat $MyFolder/USERS_TABLE.txt

echo "Folders without users in AD"
cat $MyFolder/Users_not_in_AD.txt

change_ownership() {
			echo "############################################-- Scanning,  Please Wait --###########################################"
			echo "# User Name is $f"
			echo "# User ID is $MyID"
			echo "# Primary Group is $MyGROUP \n\n"
			
			echo "### Search folders owned by $f"
			find / -name $f > $MyFolder/owned_by_$f.txt 2>/dev/null
			
			echo "### Changing folders ownership if needed"
			cat $MyFolder/owned_by_$f.txt | xargs -L1 chown -Rv "$f:$MyGROUP" 2>&1 | tee $MyFolder/owned_by_$f_changed.log
}

# Search folder owned by each user 
MyUSER=`cat $MyFolder/USERNAME_LIST.txt | grep -iv 'No such user\| root \| ec2-user' |sort -n`
	for f in $MyUSER
	do
		MyID=`id -u $f` #get User ID 
		MyUSERNAME="$f" #check username
		MyGROUP=`id -gn $f` #check user's primary group, not assume "domain users".
			
		if [ $(echo -n $MyID) -gt 10000 ]; then # check if it's a local user or AD user, skipping Local users.
			# check if user exist in AD, if "No such user", skip it.
			id -u $f && change_ownership # do it for every user with ID.
		fi	
	done

ls -al /home | tee $MyFolder/home_ownership_results.txt

echo "######### Logs and information at $MyFolder"

exit 0
