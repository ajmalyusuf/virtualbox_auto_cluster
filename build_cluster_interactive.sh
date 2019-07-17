#!/bin/bash

PING_ATTEMPTS=3

CLUSTER_NAME="Amabri 2.4.2 and HDP 2.5.3"
OS_NAME="Cent67"
CONFIGURED_IP_PREFIX="192.168.66."
NUM_OF_NODES=3
FIRST_IPADDR_LAST_OCTET=101
SSH_IPADDR=192.168.66.100

counter=0
while [ $counter -lt $NUM_OF_NODES ]
do
	node_name=$OS_NAME'-N'$((counter+1))'-'$NUM_OF_NODES'N-'$((FIRST_IPADDR_LAST_OCTET+counter))
	THIS_IP_LAST_OCTET=$((FIRST_IPADDR_LAST_OCTET+counter))
	((counter++))
	echo "----------------------------"$node_name"----------------------------"
	
	proceed_with_configuration=0

	installed_vms=`VBoxManage list vms | grep $node_name | cut -d'"' -f2`
	search_string=" "; for i in `echo "$installed_vms"`; do search_string="$search_string$i "; done
	is_vm_installed=`echo "$search_string" | grep " $node_name " | wc -l`

	if [ $is_vm_installed == 1 ]
	then
		echo $node_name" is already installed. Skipping import..."
		SSH_IPADDR=$CONFIGURED_IP_PREFIX$THIS_IP_LAST_OCTET
	else
		proceed_with_configuration=1
		disk_name=$node_name'-disk1.vmdk'
		VBoxManage import --options keepallmacs /Users/ayusuf/Documents/MyData/auto_cluster/n1-100.ova --vsys 0 --vmname $node_name --vsys 0 --unit 12 --disk /Users/ayusuf/VirtualBox\ VMs/$node_name/$disk_name
		VBoxManage modifyvm ${node_name} --groups "/${CLUSTER_NAME}"
	fi

	running_vms=`VBoxManage list runningvms | grep $node_name | cut -d'"' -f2`
	search_string=" "; for i in `echo "$running_vms"`; do search_string="$search_string$i "; done
	is_vm_running=`echo "$search_string" | grep " $node_name " | wc -l`

	if [ $is_vm_running == 1 ]
	then
		echo $node_name" is already running. Skipping start..."
	else
		echo "Starting the VM : "$node_name
		VBoxManage startvm $node_name
		#VBoxManage startvm $node_name --type headless
	fi

	if [ $proceed_with_configuration == 0 ]
	then
		echo "The VM is already installed."
		read -p 'Do you want to reconfigure? Type y to reconfigure. (n) :' choice
		if [ "$choice" != "y" ]
		then
			echo "Skipping configuring the VM : "$node_name
			continue
		fi
		#read -p 'Enter the Last Octet of the IP Address: '$CONFIGURED_IP_PREFIX last_octet
		#SSH_IPADDR=${CONFIGURED_IP_PREFIX}${last_octet}
	fi

	nat_macaddress=`VBoxManage showvminfo $node_name --machinereadable | grep "macaddress1" | cut -d'"' -f2`

	cp configure_host_interactive.sh configure_host_${node_name}.sh
	sed -i "" "s/NUM_OF_NODES=\"UNKNOWN\"/NUM_OF_NODES=$NUM_OF_NODES/g" configure_host_${node_name}.sh
	sed -i "" "s/FIRST_IPADDR_LAST_OCTET=\"UNKNOWN\"/FIRST_IPADDR_LAST_OCTET=$FIRST_IPADDR_LAST_OCTET/g" configure_host_${node_name}.sh
	sed -i "" "s/THIS_IP_LAST_OCTET=\"UNKNOWN\"/THIS_IP_LAST_OCTET=$THIS_IP_LAST_OCTET/g" configure_host_${node_name}.sh
	sed -i "" "s/THIS_MAC_ADDRESS=\"UNKNOWN\"/THIS_MAC_ADDRESS=${nat_macaddress}/g" configure_host_${node_name}.sh
	sed -i "" "s/RESTART_PROMPT=\"ON\"/RESTART_PROMPT=\"OFF\"/g" configure_host_${node_name}.sh

	echo "Waiting for the VM to be booted...("$SSH_IPADDR")"
	ssh_response=`nc -z -w 2 $SSH_IPADDR 22 > /dev/null; echo $?;`
	echo "Response (Attempt 1) : "$ssh_response
	
	attempt=0
	while [ $ssh_response -eq 1 ]
	do
		((attempt++))
		echo "Attempting... "$attempt
		ssh_response=`nc -z -w 2 $SSH_IPADDR 22 > /dev/null; echo $?;`
		echo "Response (Attempt"$attempt") : "$ssh_response
	
		if [ $attempt == $PING_ATTEMPTS ]
		then
			echo "Tried maximum configured attepts..."
			echo "Skipping this configuring..."$node_name
			break
		fi
	done

	if [ $ssh_response == 0 ]
	then
		echo "Configuring the client machine. You will be prompted for root password."
		ssh root@$SSH_IPADDR 'bash -s' < configure_host_${node_name}.sh
	fi
done


# VBoxManage controlvm Ajmal savestate
# VBoxManage modifyvm Cent67-N1-3N-26 --macaddress1 0800276EC5B5
# ssh root:hadoop@10.0.1.2 'bash -s' < shutdown.sh

