#!/bin/bash
#This script is based on the tutorial that can be found at:
#http://docs.openstack.org/trunk/openstack-compute/install/apt/content/

localrc="localrc"


source functions.sh
source $localrc

###################################################################################

##Check for admin rights
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

###################################################################################

##Install the imaging service, Glance!
##Install the package
func_install glance glance-api glance-registry python-glanceclient glance-common

##Check if keystone password exists,
##if it does not, ask the user for one.
if [ ! -n "$GLANCEPASS" ]
then
	func_set_password "GLANCEPASS" "Glance user"
	GLANCEPASS=$(func_retrieve_value "GLANCEPASS")
fi

##Give Glance access to the database.
mysql -u root -p"$MYSQLPASS" <<EOF
CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY "$GLANCEPASS";
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY "$GLANCEPASS";
EOF

##Check the ip of the glance service.
if [ ! -n "$GLANCEIP" ]
then
	echo "On which host has Glance been installed? Please use the IP and not the hostname"
	GLANCEIP=$(func_ask_user)
	func_set_value "GLANCEIP" $GLANCEIP
fi

##Configure glance to use mysql
func_replace "/etc/glance/glance-api.conf" 	"sql_connection = sqlite:////var/lib/glance/glance.sqlite" "sql_connection = mysql://glance:$GLANCEPASS@$GLANCEIP/glance"
func_replace "/etc/glance/glance-registry.conf" "sql_connection = sqlite:////var/lib/glance/glance.sqlite" "sql_connection = mysql://glance:$GLANCEPASS@$GLANCEIP/glance"

##Set up the correct credentials
func_replace "/etc/glance/glance-api.conf" "auth_host = 127.0.0.1" 			"auth_host = $KEYSTONEIP"
func_replace "/etc/glance/glance-api.conf" "admin_tenant_name = %SERVICE_TENANT_NAME%" 	"admin_tenant_name = service"
func_replace "/etc/glance/glance-api.conf" "admin_user = %SERVICE_USER%" 		"admin_user = glance"
func_replace "/etc/glance/glance-api.conf" "admin_password = %SERVICE_PASSWORD%"	"admin_password = glance"

func_replace "/etc/glance/glance-registry.conf" "auth_host = 127.0.0.1" 			"auth_host = $KEYSTONEIP"
func_replace "/etc/glance/glance-registry.conf" "admin_tenant_name = %SERVICE_TENANT_NAME%" 	"admin_tenant_name = service"
func_replace "/etc/glance/glance-registry.conf" "admin_user = %SERVICE_USER%" 			"admin_user = glance"
func_replace "/etc/glance/glance-registry.conf" "admin_password = %SERVICE_PASSWORD%"		"admin_password = glance"

##Configure the rabbit backend
func_replace "/etc/glance/glance-api.conf" "notifier_strategy = noop" 	"notifier_strategy = rabbit"
func_replace "/etc/glance/glance-api.conf" "rabbit_host = localhost" 	"rabbit_host = $KEYSTONEIP"
func_replace "/etc/glance/glance-api.conf" "rabbit_password = guest" 	"rabbit_password = $RABBITPASS"

##Next, restart the glance service so that it picks up the new database configuration.
##Lastly, initialize the new glance database.
service glance-api restart
service glance-registry restart
glance-manage db_sync

echo "export SERVICE_TOKEN=$ADMINTOKEN" > glancerc
echo "export OS_USERNAME=$ADMINUSERNAME" >> glancerc
echo "export OS_PASSWORD=$ADMINUSERPASS" >> glancerc
echo "export OS_TENANT_ID=$DEFTENANTID" >> glancerc
echo "export OS_AUTH_URL=\"http://$KEYSTONEIP:5000/v2.0/\" " >> glancerc
