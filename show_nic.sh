#!/bin/sh

# Get the list of VMs
esxcli network vm list | awk 'NR>2' > /tmp/vmlist

while read -r line; do
    WorldID=$(echo $line | awk '{print $1}')
    VMName=$(echo $line | awk ' {print $2}')
    PortList=$(esxcli network vm port list -w $WorldID)
    NICID=$(echo "$PortList" | grep "Team Uplink:" | awk '{print $3}')
    MACID=$(echo "$PortList" | grep "MAC Address:" | awk '{print $3}')
    echo "VM: $VMName                   NIC: $NICID    MAC: $MACID"
    echo "For more Details: esxcli network vm port list -w $WorldID"
done < /tmp/vmlist

# Clean up the temporary file
rm /tmp/vmlist
