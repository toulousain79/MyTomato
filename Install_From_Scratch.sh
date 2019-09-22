#!/bin/sh

# https://github.com/toulousain79/MyTomato

#### Variables declaration
gsDirLogs=""
gsDirBackups=""
gsDirArmExtras=""
gsDirOverLoad=""
gsWan1_DNS=""
[ -n "${1}" ] && FILESYSTEM="${1}" || FILESYSTEM="ext4"

#### Check if OPKG already exist
(type opkg >/dev/null) && echo "ERROR: 'opkg' already exist" && exit 1

#### Mount /opt
(df -h | grep -q '/tmp/mnt/ENTWARE') && umount /tmp/mnt/ENTWARE
echo "LABEL=ENTWARE /opt ${FILESYSTEM} defaults,data=writeback,noatime,nodiratime 0 0" >/etc/fstab
mount -a
(! df -h | grep -q '/opt') && echo "ERROR: '/opt' not mounting" && exit 1

#### Install ENTWARE
wget -O - http://bin.entware.net/armv7sf-k2.6/installer/generic.sh | sh

### Export
(! echo "$PATH" | grep -q '/opt/bin') && PATH=$PATH:/opt/bin
(! echo "$PATH" | grep -q '/opt/sbin') && PATH=$PATH:/opt/sbin
export PATH

wget -O - http://pkg.entware.net/sources/i18n_glib223.tar.gz | tar zx -C /tmp/
mv -v /tmp/i18n/locales/* /opt/usr/share/i18n/locales/
mv -v /tmp/i18n/charmaps/* /opt/usr/share/i18n/charmaps/
rm -rf /tmp/i18n

opkg update
opkg install \
	bash \
	wget \
	curl \
	bzip2 \
	less \
	lsof \
	perl \
	tar \
	unzip \
	sed \
	vim \
	vim-runtime \
	tcpdump \
	htop \
	gawk \
	bind-dig \
	file \
	strace \
	whereis \
	mlocate \
	git \
	jq \
	xxd \
	logrotate \
	mount-utils \
	coreutils-ln \
	coreutils-uniq \
	coreutils-kill \
	coreutils-dircolors \
	coreutils-dirname \
	coreutils-cp \
	coreutils-mv \
	coreutils-chown \
	coreutils-chmod \
	coreutils-cat \
	coreutils-basename \
	coreutils-install \
	coreutils-df \
	procps-ng-ps \
	procps-ng-pgrep \
	ca-certificates \
	ca-bundle \
	fake-hwclock \
	ntpdate \
	ntpd \
	rsync \
	openssh-sftp-server \
	nfs-kernel-server \
	nfs-kernel-server-utils \
	python \
	python3

#### NTP
ntpdate -4 -p 1 -u 0.fr.pool.ntp.org

#### Clone GitHub repoistory
if [ ! -d /opt/MyTomato ]; then
	git clone git://github.com/toulousain79/MyTomato.git /opt/MyTomato
else
	cd /opt/MyTomato || exit 1
	git fetch origin
	git reset --hard origin/master
	git pull origin master
fi

#### DNScrypt-proxy v2
if (! nvram get os_version | grep -q 'AIO'); then
	if [ ! -d /opt/usr/local/dnscrypt-proxy ]; then
		git clone git://github.com/jedisct1/dnscrypt-proxy.git /opt/usr/local/dnscrypt-proxy
	else
		cd /opt/usr/local/dnscrypt-proxy || exit 1
		git fetch origin
		git reset --hard origin/master
		git pull origin master
	fi
	if [ -f /opt/usr/local/dnscrypt-proxy/utils/generate-domains-blacklists/generate-domains-blacklist.py ]; then
		cd /opt/usr/local/dnscrypt-proxy/utils/generate-domains-blacklists/ || exit
		chmod +x generate-domains-blacklist.py
		# python generate-domains-blacklist.py >list.txt.tmp && mv -f list.txt.tmp blacklists.txt
	fi
fi

# Add /opt UUID to "/opt/MyTomato/root/ConfigOverload/vars"
cp -v /opt/MyTomato/root/TEMPLATEs/vars.tmpl /opt/MyTomato/root/ConfigOverload/vars
gsUsbOptUuid="$(blkid | grep 'ENTWARE' | awk '{ print $3 }' | cut -d '"' -f 2)"
if [ -f /opt/MyTomato/root/ConfigOverload/vars ]; then
	nNumLine=$(grep 'gsUsbOptUuid' -n -m 1 </opt/MyTomato/root/ConfigOverload/vars | cut -d ':' -f 1)
	sed -i "${nNumLine}"s/.*/gsUsbOptUuid=\""${gsUsbOptUuid}"\"/ /opt/MyTomato/root/ConfigOverload/vars
	nNumLine=$(grep 'gsUsbFileSystem' -n -m 1 <"/opt/MyTomato/root/ConfigOverload/vars" | cut -d ':' -f 1)
	sed -i "${nNumLine}"s/.*/gsUsbFileSystem=\""${FILESYSTEM}"\"/ /opt/MyTomato/root/ConfigOverload/vars
else
	{
		echo "########################################"
		echo "#### USB Disk"
		echo "gsUsbOptUuid=\"${gsUsbOptUuid}\""
		echo "gsUsbFileSystem=\"${FILESYSTEM}\""
		echo
	} >>/opt/MyTomato/root/ConfigOverload/vars
fi

#### Loading vars
[ ! -f /opt/MyTomato/root/SCRIPTs/inc/vars ] && {
	echo "Error, '/opt/MyTomato/root/SCRIPTs/inc/vars' file does not exist, aborting !"
	exit 1
}
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/ConfigOverload/vars
export PATH=/opt/bin:/opt/sbin:/opt/usr/bin:/opt/usr/sbin:/bin:/sbin:/mmc/bin:/mmc/sbin:/mmc/usr/bin:/mmc/usr/sbin:/usr/bin:/usr/sbin:/home/root
echo "Firmware Version: ${gsFirmwareVersion}"
echo "Firmware Year: ${gsFirmwareYear}"
echo "URL Arm-Extras: ${gsUrlArmExtras}"
echo "Locales: ${gsLocales}"
echo "Timezone: ${gsTimezone}"
echo "USB filesystem: ${gsUsbFileSystem}"
echo "USB UUID: ${gsUsbOptUuid}"
echo "Enable P2Partisan: ${gbP2Partisan_Enable}"
echo "Enable DSNcrypt: ${gbDNScrypt_Enable}"
echo "Default DNS (Quad 9): ${gsWan1_DNS}"
echo "Enable repo auto upgrade: ${gbRepoUpgrade_Enable}"

#### Add /opt/bin/bash to /opt/etc/shells
(! grep -q '/opt/bin/bash' /opt/etc/shells) && echo "/opt/bin/bash" >>/opt/etc/shells
cat /opt/etc/shells

#### Locales
[ -n "${gsLocales}" ] && /opt/bin/localedef.new -c -f UTF-8 -i "${gsLocales}" "${gsLocales}.UTF-8"
[ -n "${gsTimezone}" ] && ln -sfv /opt/share/zoneinfo/${gsTimezone} /opt/etc/localtime

#### TAG '/opt' and '/opt/var/log' with UUID to avoid deleting
if [ -n "${gsUsbOptUuid}" ]; then
	if [ ! -f /opt/.uuid ] || [ "$(cat /opt/.uuid)" != "${gsUsbOptUuid}" ]; then
		echo "${gsUsbOptUuid}" >/opt/.uuid
	fi
	if [ ! -f /opt/root/.uuid ] || [ "$(cat /opt/root/.uuid)" != "${gsUsbOptUuid}" ]; then
		echo "${gsUsbOptUuid}" >/opt/root/.uuid
	fi
	if [ ! -f /opt/var/log/.uuid ] || [ "$(cat /opt/var/log/.uuid)" != "${gsUsbOptUuid}" ]; then
		echo "${gsUsbOptUuid}" >/opt/var/log/.uuid
	fi
fi

#### Prepare some files and directories ####
# /opt/tmp
if (! mount -l | grep -q '/tmp'); then
	mount -t tmpfs -o size=256M,mode=0755 tmpfs /opt/tmp/
	cp -af /tmp/* /opt/tmp/
	rm -rRf /tmp/* && rm -rRf /tmp/.??*
	mount -v --bind /opt/tmp /tmp
fi

# /opt/var/log
if (! mount -l | grep -q '/tmp/var/log'); then
	if [ -f /tmp/var/log/messages ]; then
		cat /tmp/var/log/messages >>/opt/var/log/messages
		if [ ! -f /tmp/var/log/.uuid ]; then
			rm -rRfv /tmp/var/log/* && rm -rRf /tmp/var/log/.??*
		fi
		/opt/bin/mount -v --bind /opt/var/log /tmp/var/log
	fi
fi

# /opt/root
if (! mount -l | grep -q '/tmp/home/root'); then
	if [ ! -f /tmp/home/root/.uuid ]; then
		rm -rRf /tmp/home/root/* && rm -rRf /tmp/home/root/.??*
		rm -rf /opt/root
	fi
	/opt/bin/mount -v --bind /opt/MyTomato/root /tmp/home/root
fi
[ ! -h /opt/root ] && ln -s /opt/MyTomato/root/ /opt/root

# Rights
chmod +x ${gsDirScripts}/*

# Creating directories
mkdir -pv "${gsDirBackups}"
mkdir -pv "${gsDirArmExtras}"
mkdir -pv "${gsDirOverLoad}/p2partisan"
mkdir -pv "${gsDirOverLoad}/dnscrypt"

# Copy back all existing init files
/opt/bin/find /opt/etc/init.d/ -type f -name "*" -exec bash -c 'i="$1"; cp -v "${i}" "${gsDirBackups}/$(basename ${i}).original"' _ {} \;

# Copy all init files
/opt/bin/find "${gsDirTemplates}/init/" -name "*.tmpl" -exec bash -c 'i="$1"; cp -v "${i}" /opt/etc/init.d/$(basename $(echo "${i}" | sed "s/.tmpl//g;"))' _ {} \;
chmod +x /opt/etc/init.d/*

# Create empty file
touch /etc/dnsmasq-custom.conf
touch ${gsDirOverLoad}/.bash_aliases
/opt/bin/find "${gsDirTemplates}/p2partisan/" -name "*.txt.tmpl" -exec bash -c 'i="$1"; cp -v "${i}" ${gsDirOverLoad}/p2partisan/$(basename $(echo "$1" | sed "s/p2partisan.//g;s/.txt.tmpl//g;"))' _ {} \;
/opt/bin/find "${gsDirTemplates}/dnscrypt/" -name "*.txt.tmpl" -exec bash -c 'i="$1"; cp -v "${i}" ${gsDirOverLoad}/dnscrypt/$(basename $(echo "$1" | sed "s/.tmpl//g;"))' _ {} \;

#### NVRAM settings
# Administration > Scripts > Init
nvram set script_init="echo \"LABEL=SWAP none swap sw 0 0\" > /etc/fstab
echo \"LABEL=ENTWARE /opt ${FILESYSTEM} defaults,data=writeback,noatime,nodiratime 0 0\" >> /etc/fstab
touch /etc/dnsmasq-custom.conf"

# USB and NAS > USB Support>Run after mounting
nvram set script_usbmount="{ [ \"\$1\" == \"/opt\" ]; [ -f \"\$1/MyTomato/root/SCRIPTs/USB_AfterMounting.sh\" ]; } && bash \"\$1/MyTomato/root/SCRIPTs/USB_AfterMounting.sh\""
# USB and NAS > USB Support>Run before unmounting
{
	echo "{ [ \"\$1\" == \"/opt\" ]; [ -f \"\$1/MyTomato/root/SCRIPTs/USB_BeforeUnmounting.sh\" ]; } && bash \"\$1/MyTomato/root/SCRIPTs/USB_BeforeUnmounting.sh\""
	echo "sleep 2; service dnsmasq restart"
} >/tmp/script_usbumount
nvram set script_usbumount="$(cat /tmp/script_usbumount)"
# Administration > Scheduler > Custom 1
nvram set sch_c1=1,300,127 # Everyday at 5:00 am
nvram set sch_c1_cmd="bash ${gsDirScripts}/Upgrade.sh"
# Administration > Script > Shutdown
nvram set script_shut="[ -f ${gsDirScripts}/USB_BeforeUnmounting.sh ] && bash ${gsDirScripts}/USB_BeforeUnmounting.sh"
#### Administration > Logging > Syslog
nvram set log_file=1
nvram set log_events="acre,crond,dhcpc,ntp,sched"
nvram set log_file_custom=1
nvram set log_file_path="/var/log/messages"
nvram set log_file_keep=30
nvram set log_file_size=10240
nvram set log_limit=0
nvram set log_mark=30
### Administration > Logging > IP Traffic Monitoring
nvram set cstats_enable=0
nvram set cstats_path="${gsDirLogs}/"
nvram set cstats_offset=1
nvram set cstats_stime=1
nvram set cstats_include=
nvram set cstats_exclude=
nvram set cstats_sshut=1
nvram set cstats_bak=1
### Administration > Logging > Bandwidth Monitoring
nvram set rstats_enable=0
nvram set rstats_path="${gsDirLogs}/"
nvram set rstats_offset=1
nvram set rstats_stime=1
nvram set rstats_exclude=
nvram set rstats_sshut=1
nvram set rstats_bak=1
## Basic > Identification > Hostname
nvram set wan_hostname="MyTomato"
## Basic > Network > WAN Settings > WAN 1
nvram set wan_dns="${gsWan1_DNS}"
## Basic > Time
nvram set ntp_tdod=1
## VPN Tunneling > OpenVPN Client > Client 1 > Advanced
{
	echo "ca /opt/MyTomato/root/OpenVPN/client1/ca_example.crt"
	echo "cert /opt/MyTomato/root/OpenVPN/client1/demo_example.crt"
	echo "key /opt/MyTomato/root/OpenVPN/client1/demo_example.key"
	echo "tls-auth /opt/MyTomato/root/OpenVPN/client1/ta_example.key 1"
	echo "log /opt/MyTomato/root/OpenVPN/client1/client1.log"
	echo "verb 3"
} >>/tmp/openvpn_client1
nvram set vpn_client1_custom="$(cat /tmp/openvpn_client1)"

#### Cleaning
rm -fv /tmp/script_init
rm -fv /tmp/script_fire
rm -fv /tmp/script_usbumount
rm -fv /tmp/openvpn_client1
rm -fv /opt/etc/init.d/S77ntpdate
rm -fv /opt/etc/*.1
if (nvram get os_version | grep -q 'AIO'); then
	rm -fv /opt/etc/dnscrypt-proxy.toml
	rm -fv ${gsDirBackups}/dnscrypt-proxy*
	rm -fv /opt/etc/init.d/S09dnscrypt-proxy2
	rm -fv ${gsDirOverLoad}/dnscrypt*
	rm -fv ${gsDirOverLoad}/*.md
	rm -fv ${gsDirOverLoad}/*.minisig

	nNumLine=$(grep 'gbDNScrypt_Enable' -n -m 1 </opt/MyTomato/root/ConfigOverload/vars | cut -d ':' -f 1)
	sed -i "${nNumLine}"s/.*/gbDNScrypt_Enable=0/ /opt/MyTomato/root/ConfigOverload/vars
	if [ -f /opt/etc/init.d/S09dnscrypt-proxy2 ]; then
		nNumLine=$(grep 'ENABLED' -n -m 1 </opt/etc/init.d/S09dnscrypt-proxy2 | cut -d ':' -f 1)
		sed -i "${nNumLine}"s/.*/ENABLED=no/ /opt/etc/init.d/S09dnscrypt-proxy2
	fi
	if [ -f "${gsDirTemplates}/init/S09dnscrypt-proxy2.tmpl" ]; then
		nNumLine=$(grep 'ENABLED' -n -m 1 <"${gsDirTemplates}/init/S09dnscrypt-proxy2.tmpl" | cut -d ':' -f 1)
		sed -i "${nNumLine}"s/.*/ENABLED=no/ "${gsDirTemplates}/init/S09dnscrypt-proxy2.tmpl"
	fi

	nvram set dnscrypt2_enable=0
else
	nvram set dnscrypt2_enable=1
fi

# Commit
nvram commit

#### Create /opt/.autorun script
cp -v /opt/MyTomato/root/TEMPLATEs/.autorun.tmpl /opt/.autorun
chmod +x /opt/.autorun

#### MLocate
[ -f /opt/etc/group ] && (! grep -q 'mlocate' /opt/etc/group) && echo "mlocate:x:111:" >>/opt/etc/group
cat /opt/etc/group
updatedb

#### NVRAM config save
nvram set mytomato_config_save="${gdDateTime}"
nvram commit
nvram save "${gsDirBackups}/MyTomato_${gdDateTime}.cfg" >/dev/null 2>&1

#### Reboot needed
echo
echo
echo "Please, adapt '${gsDirOverLoad}/vars' as you want..."
echo
echo "And, reboot your router..."
echo "The reboot can take a while, so please be patient."
echo
echo "Maybe adapt your LAN IP address... ;-)"
echo
echo
