#!/opt/bin/bash

#### Variables declaration
declare gsScriptName gsDirOverLoad gbP2Partisan_Enable

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### STOP all services ####
bash "${gsDirScripts}/Services_Stop.sh"

#### SysLog ####
gfnStartStopSyslogd 'start'

#### EntWare Services ####
gfnEntwareServices "start"

#### P2Partisan
gfnP2pArtisanStartStop

exit 0
