#!/opt/bin/bash

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

[ -z "${gsOrange_FTI}" ] && {
	echo
	echo "'gsOrange_FTI' variable is not defined in '\"${gsDirOverLoad}/vars\"', aborting !"
	exit 1
}

(! df -h | grep -q '/opt') && {
	echo "ERROR: '/opt' not mounting"
	exit 1
}

#### Orange - DHCP Mode
# https://lafibre.info/remplacer-livebox/tuto-mode-dhcp-sur-firmware-tomato/12/

## Install neeeded tools
# convert string to hexa
if (opkg list-installed | grep -q 'xxd'); then
	opkg update
	opkg install xxd
	HEXA="$(xxd -p -u <<<"$(echo "${gsOrange_FTI}" | cut -d '/' -f 2)" | sed 's/0A$//')"
else
	echo
	echo "'xxd' package is missing, aborting !"
	exit 1
fi

## Basic > Network > WAN Settings
nvram set wan_ppp_username="${gsOrange_FTI}"
nvram set wan_proto=dhcp

## Advanced > Network > WAN Settings
nvram set wan_iface=vlan832
nvram set wan_ifname=vlan832
nvram set wan_ifnameX=vlan2
nvram set wan_ifnames=vlan832
nvram set wandevs=vlan2
nvram set vlan2vid=832
nvram set vlan2tag=1

## Advanced -> DHCP/DNS -> DHCP Client (WAN)
#nvram set dhcpc_custom="~u2014retries=2 ~u2014timeout=5 ~u2014tryagain=310"

## Adminsitration > Script > Init
nvram get script_init >/tmp/script_init
sed -i '/# Orange DHCP Mode/d' /tmp/script_init
sed -i '/\/tmp\/sbin/d' /tmp/script_init
sed -i '/udhcpc/d' /tmp/script_init
{
	echo "# Orange DHCP Mode"
	echo "cp -R /sbin/ /tmp/sbin"
	echo "rm /tmp/sbin/udhcpc"
	echo "echo 'exec busybox udhcpc -O 0x4d -O 0x5a -x 0x4d:2b46535644534c5f6c697665626f782e496e7465726e65742e736f66746174686f6d652e4c697665626f7834 -x 0x5a:00000000000000000000001a0900000558010341010d6674692f${HEXA} \"\$*\"' >/tmp/sbin/udhcpc"
	echo "chmod +x /tmp/sbin/udhcpc"
	echo "mount --bind /tmp/sbin/ /sbin"
} >>/tmp/script_init
nvram set script_init="$(cat /tmp/script_init)"
rm -f /tmp/script_init

## Adminsitration > Script > Firewall
echo "### Version 17 20190117
### https://lafibre.info/remplacer-livebox/tuto-remplacer-la-livebox-par-un-routeur-dd-wrt-internet-tv/

### Priorite / CoS pour Internet
# File 0 (par defaut) pour le DHCP (raw-socket), file 1 pour le reste du trafic
vconfig set_egress_map vlan832 0 6
vconfig set_egress_map vlan832 1 0

### Support TV, priorite / CoS pour l'ensemble des files
if ( nvram show |sort |grep 'vlan' |grep -q '840' ); then
	for i in \$(seq 0 7); do
		vconfig set_egress_map vlan840 \"\$i\" 5
	done
fi

### On classe le trafic Internet dans les bonnes files
# Tout le trafic priorite 1 (CoS 0)
iptables -t mangle -A POSTROUTING -j CLASSIFY --set-class 0000:0001
# Client DHCP non raw-socket (pas le cas de udhcpc) mais sert aussi pour le renew
iptables -t mangle -A POSTROUTING -o vlan832 -p udp --dport 67 -j CLASSIFY --set-class 0000:0000" >/opt/etc/orange_ack_script_fire.sh

nvram get script_fire >/tmp/script_fire
sed -i '/orange_ack_script_fire/d' /tmp/script_fire
echo "sh /opt/etc/orange_ack_script_fire.sh" >/tmp/script_fire
nvram set script_fire="$(cat /tmp/script_fire)"
rm -f /tmp/script_fire

## Commit
nvram commit

### Reboot needed
echo
echo
echo "Please, reboot your router..."
echo
echo

exit 0
