#!/opt/bin/bash

#### Variables declaration
declare gsDirOverLoad

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### Lock file
[ ! -f /tmp/${gsScriptName} ] && touch ${gsScriptName} || exit 0

#### NVRAM settings
gfnNvramUpdate 'dns_wan1' 'get'

#### Stop all services
bash "${gsDirScripts}/Services_Stop.sh"

#### Keep date time
fake-hwclock save

#### NVRAM save
gfnNvramSave

#### Umount if possible
# /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -v /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -vf /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -vl /tmp/var/log
# /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -v /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -vf /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -vl /tmp/home/root
# /opt/tmp
(/opt/bin/mount -l | grep -q '/tmp') && /opt/bin/umount -v /tmp
(/opt/bin/mount -l | grep -q '/tmp') && /opt/bin/umount -vf /tmp
(/opt/bin/mount -l | grep -q '/tmp') && /opt/bin/umount -vl /tmp
# /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -v /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -vf /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -vl /opt

#### Lock file
[ -f /tmp/${gsScriptName} ] && rm ${gsScriptName}

#### Kill bash sessions
for sPid in $(pidof bash); do kill -9 "${sPid}"; done

##############################
