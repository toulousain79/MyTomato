#!/opt/bin/bash

#### Variables declaration
declare gsDirOverLoad gsDirLogs gsScriptName gsOpkgPackagesList gdDateTime gbRepoUpgrade_Enable

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### OPKG
opkg update
opkg upgrade

if [ -f "${gsOpkgPackagesList}" ]; then
	while read -r line; do
		sPackage="$(echo "${line}" | awk '{ print $1 }')"
		(! opkg list-installed | grep -q "${sPackage}") && opkg install "${sPackage}" \
			logger -p user.notice "| ${gsScriptName} | EntWare install package '${sPackage}'"
	done <"$gsOpkgPackagesList"
fi

logger -p user.notice "| ${gsScriptName} | EntWare generate pakages installed list"
opkg list-installed | awk '{ print $1 }' >"${gsDirLogs}/opkg_list-installed_${gdDateTime}.txt"

#### MyTomato repo
if [ "${gbRepoUpgrade_Enable}" -eq 1 ]; then
	[ -d "/opt/MyTomato" ] && cd "/opt/MyTomato" || exit 1
	git fetch origin
	git reset --hard origin/master
	git pull origin master
fi

#### SCRIPTs
chmod +x ${gsDirScripts}/*
[ -f /opt/MyTomato/P2Partisan/p2partisan.sh ] && chmod +x /opt/MyTomato/P2Partisan/p2partisan.sh

#### NVRAM save
gfnNvramSave

exit 0
