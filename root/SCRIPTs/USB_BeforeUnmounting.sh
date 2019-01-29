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

#### NVRAM settings
gfnNvramUpdate 'dns_wan1' 'get'

#### Stop all services
bash "${gsDirScripts}/Services_Stop.sh"

#### Keep date time
fake-hwclock save

#### NVRAM save
gfnNvramSave

#### Kill bash sessions
for sPid in $(pidof bash); do kill -9 "${sPid}"; done

#### Umount if possible
# /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -v /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -vf /tmp/var/log
(/opt/bin/mount -l | grep -q '/tmp/var/log') && /opt/bin/umount -vl /tmp/var/log
# /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -v /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -vf /tmp/home/root
(/opt/bin/mount -l | grep -q '/tmp/home/root') && /opt/bin/umount -vl /tmp/home/root
# /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -v /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -vf /opt
(/opt/bin/mount -l | grep -q '/opt') && /opt/bin/umount -vl /opt

##############################
