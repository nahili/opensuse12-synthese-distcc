#!/bin/bash

# Startup the icecream setup as slave or master

function help ()
{
	echo "Usage : docker run [-p 1194:1194/udp] --privileged -v /dev/net/tun:/dev/net/tun opensuse12-distcc {master {password}|slave {master} {password}|bash|help}"
	echo "Master example : docker run -i -t --rm -p 1194:1194/udp --privileged -v /dev/net/tun:/dev/net/tun opensuse12-distcc master toto"
	echo "Slave example : docker run -i -t --rm --privileged -v /dev/net/tun:/dev/net/tun opensuse12-distcc slave 192.168.0.1 toto"
}

MODE="$1"
MASTER="$2"
MAXPROC=$(grep -c ^processor /proc/cpuinfo)
USER="distcc"
PASSWORD="$3"

# Show help and quit
if [[ $MODE == "help" || $MODE == "" ]]; then
	help
	exit 1
fi

# First : print out IP
echo "We are $HOSTNAME"
ip addr show eth0 | grep -oE 'inet .*'
echo "Mode : $MODE"
echo "Max $MAXPROC jobs"

# Bash mode, open a terminal and that's all
if [[ $MODE == "bash" ]]; then
	/bin/bash
	exit 0
fi

# Master setup : run the scheduler
if [[ $MODE == "master" ]]; then
	echo "Master mode"
	MASTER="localhost"
	PASSWORD="$2"
	
	# Change user password
	echo "distcc:$PASSWORD" | chpasswd
	
	# Start the VPN connection
	openvpn /etc/openvpn/server.conf

else # Slave mode : start VPN client

	# Setup the config
	sed -i "s/#SERVER#/$MASTER/g" /etc/openvpn/client.conf
	sed -i "s/#PORT#/1194/g" /etc/openvpn/client.conf
	
	# Setup the user to use
	echo -e "distcc\n$PASSWORD" > /etc/openvpn/pass.txt
	
	# Launch openvpn 
	openvpn /etc/openvpn/client.conf
fi

# Launch avahi
/etc/init.d/dbus start
/etc/init.d/avahi-daemon start
/etc/init.d/avahi-dnsconfd start

# Run the daemon
touch /var/log/distccd.log
chown distcc /var/log/distccd.log
distccd --listen 0.0.0.0 --allow 10.99.25.0/24 --log-level=info --log-file=/var/log/distccd.log --daemon --zeroconf

# In auto mode, do not block
if [[ $MODE != "auto" ]]; then

	# Show the logs
	tail -f /var/log/distccd.log /var/log/vpn.log

	# Fallback to bash
	/bin/bash
fi
