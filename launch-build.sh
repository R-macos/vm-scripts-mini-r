#!/bin/bash

vmpid="$1"
mac="$2"

if [ -z "$mac" ]; then
    echo "ERROR: no MAC address was passed!"
    exit 1
fi

echo -n Waiting for IP address of $mac 
## arp drops leading zeros so remove them
mac=$(echo $mac | sed -e 's/^0//' -e 's/:0/:/g')
i=0
while (( i < 40 )); do
    ip=$(arp -an | sed -nE 's/.*\(([0-9.]+)\).*'$mac'.*/\1/pi')
    if [ -n "$ip" ]; then break; fi
    echo -n .
    sleep 1
    ((i++))
done
echo ''
if [ -z "$ip" ]; then
    echo "ERROR: time out while waiting for an IP address"
    exit 1
fi

rm -f known-hosts
ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=known-hosts rbuild@$ip '/Volumes/My\ Shared\ Files/run-arm64.sh' build.sh
