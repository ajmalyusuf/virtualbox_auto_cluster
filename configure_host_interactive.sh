#!/bin/bash

NUM_OF_NODES="UNKNOWN"
FIRST_IPADDR_LAST_OCTET="UNKNOWN"
THIS_IP_LAST_OCTET="UNKNOWN"
THIS_MAC_ADDRESS="UNKNOWN"
RESTART_PROMPT="ON"

configured_ip_prefix="192.168.66."

if [ "$NUM_OF_NODES" == "UNKNOWN" ]
then
	read -p 'Enter the No. of nodes in the cluster: ' no_nodes
else
	no_nodes=$NUM_OF_NODES
fi

if [ "$FIRST_IPADDR_LAST_OCTET" == "UNKNOWN" ]
then
	echo "Enter the last part/octet of the IP Address of the first node"
	echo "(Other nodes will assume the subsequent numbers)"
	read -p 'Enter the start IP: '$configured_ip_prefix last_octet
else
	last_octet=$FIRST_IPADDR_LAST_OCTET
fi

if [ "$THIS_IP_LAST_OCTET" == "UNKNOWN" ]
then
	read -p 'Enter the IP address of this machine: '$configured_ip_prefix this_ip
else
	this_ip=$THIS_IP_LAST_OCTET
fi

this_ip=${configured_ip_prefix}${this_ip}
this_host_name=""

grep -v $configured_ip_prefix /etc/hosts > ./hosts.temp

echo "Below are the IP and Hostname for each node of the ${no_nodes} nodes cluster..."
last_part=$last_octet
counter=1
while [ $counter -le $no_nodes ]
do
        ip=${configured_ip_prefix}${last_part}
        host_name="n${counter}-${no_nodes}nc.hdp.com"
        if [ "$ip" == "$this_ip" ]; then
                this_host_name=$host_name
        fi
        mapping="${ip} ${host_name}"
        echo $mapping
        echo $mapping >> ./hosts.temp
        last_part=$((last_octet + counter))
        ((counter++))
done

grep -iv hostname /etc/sysconfig/network > ./network.temp
echo "HOSTNAME=${this_host_name}" >> ./network.temp

date_in_epoch=`date +%s`
echo "Backing up /etc/hosts as /etc/hosts.${date_in_epoch}"
echo "Adding IP <-> Hostname mappings to /etc/hosts..."
mv /etc/hosts /etc/hosts.${date_in_epoch}
mv ./hosts.temp /etc/hosts

echo "Backing up /etc/sysconfig/network to /etc/sysconfig/network.${date_in_epoch}..."
echo "Adding hostname to /etc/sysconfig/network..."
mv /etc/sysconfig/network /etc/sysconfig/network.${date_in_epoch}
mv ./network.temp /etc/sysconfig/network

if [ "$THIS_MAC_ADDRESS" == "UNKNOWN" ]
then
	echo "Enter the MAC Address from VirtualBox (12 chars without ':')"
	read -p 'Settings->Network->Adaptor 1: ' nat_mac_add

	len=${#nat_mac_add}
	while [ "$len" -ne "12" ]
	do
       		echo "Incorrect Mac Address !"
       		read -p 'Settings->Network->Adaptor 1: ' nat_mac_add
       		len=${#nat_mac_add}
	done
else
	nat_mac_add=$THIS_MAC_ADDRESS
fi

formatted_mac_add=${nat_mac_add:0:2}
for i in {2..10..2}
do
        formatted_mac_add+=":${nat_mac_add:$i:2}"
done

grep -iv "HWADDR=" /etc/sysconfig/network-scripts/ifcfg-eth0 > ./ifcfg-eth0.temp
echo "Backing up /etc/sysconfig/network-scripts/ifcfg-eth0..."
echo "Configuring ${formatted_mac_add} for eth0 network..."
echo "HWADDR=${formatted_mac_add}" >> ./ifcfg-eth0.temp

mv /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/backup.ifcfg-eth0.${date_in_epoch}
mv ./ifcfg-eth0.temp /etc/sysconfig/network-scripts/ifcfg-eth0

grep -iv "IPADDR=" /etc/sysconfig/network-scripts/ifcfg-eth1 > ./ifcfg-eth1.temp
echo "Backing up /etc/sysconfig/network-scripts/ifcfg-eth1..."
echo "Configuring ${this_ip} for eth1 network..."
echo "IPADDR=${this_ip}" >> ./ifcfg-eth1.temp

mv /etc/sysconfig/network-scripts/ifcfg-eth1 /etc/sysconfig/network-scripts/backup.ifcfg-eth1.${date_in_epoch}
mv ./ifcfg-eth1.temp /etc/sysconfig/network-scripts/ifcfg-eth1

echo "Configuring hostname as ${this_host_name}..."
hostname ${this_host_name}
echo "Checking hostname..."
echo "--------------------"
hostname -f
echo "--------------------"

echo "Removing /etc/udev/rules.d/70-persistent-net.rules..."
rm -f /etc/udev/rules.d/70-persistent-net.rules

if [ "$RESTART_PROMPT" == "ON" ]
then
	echo "All network configurations completed..."
	echo "Press ENTER for rebooting the server"
	read -p 'or any key for verifying the changes and manually rebooting: ' result

	if [ "$result" != "" ]; then
		exit 0
	fi
fi

echo "Rebooting..."
reboot

#sed -i 's/10.0.1.11$/10.0.1.21/g' ./hosts.temp

#while IFS='' read -r line || [[ -n "$line" ]]
#do
#       echo $line
#done < ./hosts.temp

