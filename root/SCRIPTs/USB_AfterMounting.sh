#!/opt/bin/bash

#### Restore last date time
fake-hwclock load force

#### Variables declaration
declare gsDirOverLoad gsDirTemplates gsDirLogs gsDirArmExtras gsDirBackups gsDirOpenVpn
declare gbP2Partisan_Enable gsUsbOptUuid gsUsbFileSystem gsScriptName

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### Sync time
gfnNtpUpdate

#### Creating directories
[ ! -d "${gsDirLogs}" ] && mkdir -pv "${gsDirLogs}"
[ ! -d "${gsDirBackups}" ] && mkdir -pv "$gsDirBackups"
[ ! -d "${gsDirArmExtras}" ] && mkdir -pv "${gsDirArmExtras}"

#### SCRIPTs
chmod +x ${gsDirScripts}/*

#### Restore config if needed
if [ -z "$(nvram get mytomato_config_save)" ]; then
	sLastConfig="$(find ${gsDirBackups}/ -type f -name "MyTomato_*.cfg" -exec ls -A1t {} + | head -1)"
	if [ -n "${sLastConfig}" ] && [ -f "${sLastConfig}" ]; then
		(nvram restore "${sLastConfig}") && reboot
	fi
fi

#### NVRAM settings
gfnNvramUpdate 'fstab'
gfnNvramUpdate 'dnsmasq'
gfnNvramUpdate 'dns_wan1'

#### Environment Config (/opt/root, /opt/var/log, ...)
bash "${gsDirScripts}/Environment_Config.sh"

#### Entware Update
bash "${gsDirScripts}/Upgrade.sh"

#### P2Partisan install
if [ ! -f /opt/MyTomato/P2Partisan/p2partisan.sh ] && [ "${gbP2Partisan_Enable}" -eq 1 ]; then
	logger -p user.notice "| ${gsScriptName} | Start P2Partisan installation"
	gfnP2pArtisanStartStop
	logger -p user.notice "| ${gsScriptName} | End of P2Partisan installation"
fi

#### DNScrypt install
gfnInstallDnscryptProxy "$@"

#### Loading Additional modules
bash "${gsDirScripts}/Load_ArmExtras.sh"

#### Services
bash "${gsDirScripts}/Services_Start.sh"

#### NVRAM config save
gfnNvramSave

exit 0
