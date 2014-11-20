#!/bin/bash

setEcho() {
	Echo=""
	if [ -x "/bin/echo" ]; then
		Echo="/bin/echo -e"
	elif [ -x "`which printf`" ]; then
		Echo="`which printf` %b\n"
	else
		Echo="echo"
	fi

	${Echo} "echo command is set to be '${Echo}'"
}

echo "loading script.bootstrap.functions.sh"



ValidateConfig() {
	# criteria for a valid config is:
	#  - populated attribute: installer_section0_buildComponentList and MUST contain one or both of 'eduroam' or 'shibboleth
	#  - non empty attributes for each set
	#
	# this parses all attributes in the configuration file to ensure they are not zero length
	#
	#
	#	Methodology: 
	#				enumerate and iterate over the field installer_section0_buildComponentList
	#				based on the features in there, assemble the required fields 
	#					iterate over each variable name and enforce non empty state, bail entirely if failed

	#  	the old check: - anything, but non empty: vc_attribute_list=`cat ${Spath}/config|egrep -v "^#"| awk -F= '{print $1}'|awk '/./'|tr '\n' ' '`
	
	vc_attribute_list=""

	# build our required field list dynamically

	eval set -- "${installer_section0_buildComponentList}"

	while [ $# -gt 0 ]
	do
			# uncomment next 3 echo lines to diagnose variable substitution
			# ${Echo} "DO======${tmpVal}===== ---- $1, \$$1, ${!1}"
		if [ "XXXXXX" ==  "${1}XXXXXX" ]
        	then
			# ${Echo} "##### $1 is ${!1}"
			# ${Echo} "########EMPTYEMPTY $1 is empty"
			${Echo} "NO COMPONENTS SELECTED FOR VALIDATION - EXITING IMMEDIATELY"
			exit

		else
			#debug ${Echo} "working on ${1}"
			tmpFV="requiredNonEmptyFields${1}"
			

			#debug ${Echo} "=============dynamic var: ${tmpFV}"


			vc_attribute_list="${vc_attribute_list} `echo "${!tmpFV}"`";

			#settingsHumanReadable=" ${settingsHumanReadable}  ${tmpString}:  ${!1}\n"
			#settingsHumanReadable="${settingsHumanReadable} ${cfgDesc[$1]}:  ${!1}\n"
		fi
	
		shift
	done
	
	#=======

	tmpBailIfHasAny=""

	#old: vc_attribute_list=`cat ${Spath}/config|egrep -v "^#"| awk -F= '{print $1}'|awk '/./'|tr '\n' ' '`
	
	# uses indirect reference for variable names. 
	
	# ${Echo} "======working with ${vc_attribute_list}"



	eval set -- "${vc_attribute_list}"
	while [ $# -gt 0 ]
	do
			# uncomment next 3 ${Echo} lines to diagnose variable substitution
			# ${Echo} "DO======${tmpVal}===== ---- $1, \$$1, ${!1}"
		if [ "XXXXXX" ==  "${!1}XXXXXX" ]
        	then
			# ${Echo} "##### $1 is ${!1}"
			# ${Echo} "########EMPTYEMPTY $1 is empty"
			tmpBailIfHasAny="${tmpBailIfHasAny} $1 "
		else
			# ${Echo} "ha"
			tmpString=" `echo "${cfgDesc[$1]}"`";
			tmpval=" `echo "${!1}"`";
			#settingsHumanReadable=" ${settingsHumanReadable}  ${tmpString}:  ${!1}\n"
			settingsHumanReadable="${settingsHumanReadable} ${cfgDesc[$1]}:  ${!1}\n"
		fi
	
		shift
	done
	#
	# announce and exit when attributes are non zero
	#
		if [ "XXXXXX" ==  "${tmpBailIfHasAny}XXXXXX" ]
		then
			${Echo} ""
		else
			${Echo} "\n\nDoing pre-flight check..\n"
			sleep 2;
			${Echo} "Discovered some required field as blank from file: ${Spath}/config\n"
			${Echo} " ${tmpBailIfHasAny}";
			echo ""	
			${Echo} "Please check out the file for the above empty attributes. If needed, regenerate from the config tool at ~/www/index.html\n\n"
			exit 1;
		fi

cat > ${freeradiusfile} << EOM
${settingsHumanReadable}
EOM

	# Set certificate variables
	certOrg="${freeRADIUS_svr_org_name}"
	certC="${freeRADIUS_svr_country}"
# 	certLongC="${freeRADIUS_svr_commonName}"
}

guessLinuxDist() {
	lsbBin=`which lsb_release 2>/dev/null`
	if [ -x "${lsbBin}" ]
	then
		dist=`lsb_release -i 2>/dev/null | cut -d':' -f2 | sed -re 's/^\s+//g'`
	fi

	if [ ! -z "`${Echo} ${dist} | grep -i 'ubuntu' | grep -v 'grep'`" ]
	then
		dist="ubuntu"
	elif [ ! -z "`${Echo} ${dist} | grep -i 'redhat' | grep -v 'grep'`" ]
	then
		dist="redhat"
	elif [ -s "/etc/centos-release" ]
	then
		dist="centos"
	elif [ -s "/etc/redhat-release" ]
	then
		dist="redhat"
	else
		really=$(askYesNo "Distribution" "Can not guess linux distribution, procede assuming ubuntu(ish)?")

		if [ "${really}" != "n" ]
		then
			dist="ubuntu"
		else
			cleanBadInstall
		fi
	fi
}


###
### experimental
###

validateConnectivity()

{

##############################
# variables definition
##############################
config_dir='/root/idp-installer-CAF'
test_ldapserver=$(cat ${config_dir}/config | grep ldapserver | awk -F"'" '{print $2}')
ldap_password=$(cat config | grep ldappass | awk -F"'" '{print $2}')
ldap_user=$(cat config | grep ldapbinddn | awk -F"'" '{print $2}')
distr_install_nc='yum install -y nc'
distr_install_ldaptools='yum install -y openldap-clients'
ntpserver=$(cat config | grep ntpserver | awk -F"'" '{print $2}')
myecho=${Echo}

##############################
# functions definition
##############################
function lao () {
        # log, execute and output
        $1 | tee -a ${statusFile}
}

function loy () {
        # log and execute only
        echo "$1" >> ${statusFile}
        $1 &>> ${statusFile}
}

##############################
# install additional packages
##############################
lao "$myecho ---------------------------------------------"
lao "$myecho Installing additional software..."
loy "$distr_install_nc"
loy "$distr_install_ldaptools"
lao "$myecho Validating ${test_ldapserver} reachability..."

##############################
# PING test
##############################
lao "$myecho PING testing..."

echo "ping -c 4 ${test_ldapserver}" >> ${statusFile}
# create pipe to avoid 'while read' limitations
mkfifo mypipe
ping -c 4 ${test_ldapserver} > mypipe &

while read pong 
do
  echo $pong | tee -a ${statusFile}
  FF=$(echo $pong | grep "packet" | awk '{print $6}')
  if [ ! -z $FF ]
        then DD=$FF
  fi
done < mypipe
rm -f mypipe
if [ ! -z $DD ]
then
  if [ $DD == "0%" ]
    then
        lao "$myecho ping - - - - ok"
        PING="ok"
  elif [ $DD == "100%" ]
    then
        lao "$myecho Ping - - - - failed"
        PING="failed"
  elif [ $DD == "25%" -o $DD == "50%" -o $DD == "75%" ]
    then
        lao "$myecho Ping - - - - intermitten"
        PING="warning"
    else
        lao "$myecho Ping - - - - failed"
        PING="failed"
  fi
else
        lao "$myecho Ping - - - - failed"
        PING="failed"
fi

##############################
# port availabilty check
##############################
lao "$myecho Port availability checking..."

loy "nc -z -w5 ${test_ldapserver} 636 "
  if [ $? == "0" ]
    then
        lao "$myecho port 636 - - - - ok"
        PORT636="ok"
    else
        lao "$myecho port 636 - - - - failed"
        PORT636="failed"
  fi

loy "nc -z -w5 ${test_ldapserver} 389"
  if [ $? == "0" ]
    then
        lao "$myecho port 389 - - - - ok"
        PORT389="ok"
    else
        lao "$myecho port 389 - - - - failed"
        PORT389="failed"
  fi

#############################
# retrive certificate
#############################
  if [ $PORT636 == "ok" ]
    then
        lao "$myecho Trying retrieve certificate..."
        echo "echo | openssl s_client -connect ${test_ldapserver}:636 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | openssl x509 -noout -subject -dates -issuer" >> ${statusFile}
        echo | openssl s_client -connect ${test_ldapserver}:636 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | openssl x509 -noout -subject -dates -issuer | tee -a ${statusFile}
        if [ $? == "0" ]
          then
                lao "$myecho certificate check - - - - ok"
                CERTIFICATE="ok"
                enddate=$(echo | openssl s_client -connect dc2.ad.cybera.ca:636 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | openssl x509 -noout -subject -dates -issuer | grep notAfter | awk -F"=" '{print $2}')

                cert=$(date --date="$enddate" +%s)
                now=$(date +%s)
                nowexp=$(date -d "+30 days" +%s)

                if [ $cert -lt $now ]
                  then
                    lao "$myecho ERROR: Certificate expired!"
                    CERTIFICATE="failed"
                  else
                    lao "$myecho Certificate still valid"
                fi

                if [ $cert -lt $nowexp ]
                  then
                    laa "$myecho WARNING: certificate will expire soon"
                    CERTIFICATE="warning"
                fi
          else
                lao "$myecho certificate check - - - - failed"
                CERTIFICATE="failed"
        fi
    else
        lao "$myecho Port 636 is closed. Cancel certificate check"
        CERTIFICATE="failed"
fi

##############################
# bind LDAP user
##############################
lao "$myecho LDAP bind checking...(might take few minutes)"
echo "ldapwhoami -vvv -h ${test_ldapserver} -D \"${ldap_user}\" -x -w \"${ldap_password}\"" >> ${statusFile}
ldapwhoami -vvv -h ${test_ldapserver} -D "${ldap_user}" -x -w "${ldap_password}" &>> ${statusFile}
  if [ $? == "0" ]
    then
        lao "$myecho ldap bind - - - - ok"
        LDAP="ok"
    else
        lao "$myecho ldap bind - - - - failed"
        LDAP="failed"
  fi

##############################
# ntp server check
##############################
lao "$myecho Validating ntpserver (${ntpserver}) reachability..."
$myecho "ntpdate ${ntpserver}" >> ${statusFile}
ntpcheck=$(ntpdate ${ntpserver} 2>&1 | tee -a ${statusFile} | awk -F":" '{print $4}' | awk '{print $1 $2}')

if [ $ntpcheck == "noserver"  ]
        then
                lao "$myecho ntpserver - - - - failed"
                NTPSERVER="failed"
        else
                lao "$myecho ntpserver - - - - ok"
                NTPSERVER="ok"
fi
###############################
# summary results
###############################
lao "$myecho ---------------------------------------------"
echo "Summary:"
echo "PING        - $PING"
echo "PORT636     - $PORT636"
echo "PORT389     - $PORT389"
echo "CERTIFICATE - $CERTIFICATE"
echo "LDAP        - $LDAP"
echo "NTPSERVER   - $NTPSERVER"
lao "$myecho ---------------------------------------------"

###############################
# pause and warning message
###############################
if [ $CERTIFICATE == "failed" -o $LDAP == "failed" ]
        then
                MESSAGE="[ERROR] Reachability test has been failed. Installation will exit [press Enter key]: "
                echo -n $MESSAGE
                read choise
                if [ ! -z $choise ]
                then
                        if [ $choise != "continue" ]
                                then
                                        echo "Installation has been canceled."
                                        exit
                        fi
                else
                        echo "Installation has been canceled."
                        exit
                fi
elif [ $PING == "failed" -o $PING == "intermitten" -o $PORT389 == "failed" -o $CERTIFICATE == "warning" -o $NTPSERVER == "failed" ];
        then
                MESSAGE="[WARNING] Reachability test completed with some uncritical exceptions. Do you want to continue? [y/n] "
                echo -n $MESSAGE
                read choise
                if [ ! -z $choise ]
                then
                        if [ $choise == "y" -o $choise == "yes" ]
                                then
                                        echo "Continue..."
                                else
                                        echo "Installation has been canceled."
                                        exit
                        fi
                else
                        echo "Installation has been canceled."
                        exit
                fi
        else
                MESSAGE="[SUCCESS] Reachability test has been completed successfully. [press Enter to continue] "
                echo -n $MESSAGE
                read choise
fi

echo "Starting installation script..."


}

