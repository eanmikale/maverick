#!/bin/bash

if [ "$1" != "tx" ] && [ "$1" != "rx" ]; then
    echo "wifibc.sh must be called with either tx or rx argument"
    exit 1
fi

# Set defaults, can be overriden in /srv/maverick/config/network/wifibc-[tx|rx].conf
KEY=/srv/maverick/data/network/wifibc/$1.key
UDPPORT=5600
RADIOPORT=1
RSK=8
RSN=12
MAVLINKAGG=
INTERFACE=

# Override values from config file
[ ! -r /srv/maverick/config/network/wifibc/$1.conf ] || . /srv/maverick/config/network/wifibc/$1.conf

if [ -z $INTERFACE ]; then
    echo "Error: Interface not specified"
    exit 1
fi

# Parse config options
if [ ! -z $MAVLINKAGG ]; then
    _MAVLINKAGG="-m $MAVLINKAGG"
else
    _MAVLINKAGG=""
fi

# Call wifibc with configured arguments
echo /srv/maverick/software/wifibc/bin/wfb_$1 -K $KEY -k $RSK -n $RSN -u $UDPPORT -p $RADIOPORT $_MAVLINKAGG $INTERFACE
/srv/maverick/software/wifibc/bin/wfb_$1 -K $KEY -k $RSK -n $RSN -u $UDPPORT -p $RADIOPORT $_MAVLINKAGG $INTERFACE
