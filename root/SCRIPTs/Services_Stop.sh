#!/opt/bin/bash

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### EntWare Services
gfnEntwareServices "stop"

#### P2Partisan
[ -f /opt/MyTomato/P2Partisan/p2partisan.sh ] && /opt/MyTomato/P2Partisan/p2partisan.sh stop

#### SFTP
[ -n "$(pidof sftp-server)" ] && killall sftp-server >/dev/null

exit 0
