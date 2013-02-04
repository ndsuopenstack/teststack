function func_install {
	COMMAND_INSTALL="apt-get install -y"
	if [ ! -n "$1" ]
	then
		func_echo "No parameter for install function"
		exit 1
	else
		for package in "$@"
		do
			args="$args $package"
		done
		COMMAND_INSTALL="$COMMAND_INSTALL $args"
		func_echo "$COMMAND_INSTALL"
		$COMMAND_INSTALL
		if [ $? -eq 0 ]
		then
			func_echo "Install process of packages $1 run correctly "
		else
			func_echo "Install process of packages $1 failed"
			exit 1
		fi
	fi
}

function func_pre {
	func_install debconf
}

function func_install_my-sql {
	if [ ! -n "$1" ]
	then
        	func_echo "No password provided"
		func_echo "Exiting now"
           	exit 1
       	else
		PASSWORD=$1
		echo mysql-server mysql-server/root_password select $PASSWORD | debconf-set-selections
		echo mysql-server mysql-server/root_password_again select $PASSWORD | debconf-set-selections
	fi
	func_install mysql-server
}

function funct_add_cloud_archive {
#	apt-get update
#	apt-get upgrade -y
	apt-get install ubuntu-cloud-keyring
	echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main" > /etc/apt/source.d/folsom.list
	apt-get update
}

function func_ask_user {
	read -e val
	echo $val
}

function func_set_value {
	key=$1
	val=$2
	eval "$key=$val"
        echo "export $key=$val" >> $localrc
}

function func_set_password {
	var=$1
	mesg=$2
	pw=" "
	while true; do
		func_echo "Enter a password used for: $mesg."
		func_echo "If no password is provided, a random password will be generated:"
	        read -e $var
	        pw=${!var}
	        [[ "$pw" = "`echo $pw | tr -cd [:alnum:]`" ]] && break
	        func_echo "Invalid chars in password.  Try again:"
	done
	if [ ! $pw ]; then
		pw=`openssl rand -hex 10`
		func_echo "Password: $pw"
	fi
	func_set_value "$var" "$pw"
}

function func_retrieve_value {
	key=$1
	grep "$key" "$localrc" | cut -d'=' -f2 | sed 's/export //g'
}

function func_clear_values {
	rm "$localrc"
}

function func_replace_param {
	file=$1
	parameter=$2
	newvalue=$3

	func_echo "In file $file - Parameter \"$parameter\" is been set to \"$newvalue\""

	oldline=$(sed 's/ //g' $file | grep "^$parameter=")
	sed -i 's/ //g' $file
	newvaluefixed=$(echo $newvalue | sed -e 's/[]\/()$*.^|[]/\\&/g')
	oldlinefixed=$(echo $oldline | sed -e 's/[]\/()$*.^|[]/\\&/g')
	sed -i "s/$oldlinefixed/$parameter=$newvaluefixed/g" $file
	newline=$(cat $file | grep "^$parameter=")

	func_echo $oldline
	func_echo "V-V-V-V-V-V-V-V"
	func_echo $newline
}

function func_create_tenant {
	ADMINTOKEN=$1
	KEYSTONEIP=$2
	TENANTNAME=$3
	DESCRIPTION="No description"
       	TENANTID=$(keystone --token "$ADMINTOKEN" --endpoint http://"$KEYSTONEIP":35357/v2.0 tenant-create --name "$TENANTNAME" --description "$DESCRIPTION" | grep "id" | sed 's/ //g')
	echo $TENANTID
}

function func_create_user {
	ADMINTOKEN=$1
	KEYSTONEIP=$2
	TENANTID=$3
	USERNAME=$4
	PASSWORD=$5
	ADMINUSERID=$(keystone --token "$ADMINTOKEN" --endpoint http://"$KEYSTONEIP":35357/v2.0 user-create --tenant-id "$TENANTID"  --name "$USERNAME" --pass "$PASSWORD" | grep "id" | sed 's/ //g' | cut -d'|' -f3)	
	echo $USERID
}

function func_create_role {
	ADMINTOKEN=$1
	KEYSTONEIP=$2
	ROLEID=$3
	ADMINROLEID=$(keystone --token "$ADMINTOKEN" --endpoint http://"$KEYSTONEIP":35357/v2.0 role-create --name "$ROLENAME" | grep "id" | sed 's/ //g' | cut -d'|' -f3)
	echo $ROLEID
}

function func_user_role_add {
	ADMINTOKEN=$1
	KEYSTONEIP=$2
	USERID=$3
	TENANTID=$4
	ROLEID=$5
	keystone --token "$ADMINTOKEN" --endpoint http://"$KEYSTONEIP":35357/v2.0 user-role-add --user "$USERID" --tenant_id "$TENANTID" --role "$ROLEID"
}

function func_echo {
	MSG=$1
	echo -e "\E[32m$MSG"
	tput sgr0
}