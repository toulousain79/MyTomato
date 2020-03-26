#!/opt/bin/bash

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

if [ -n "${gsUrlArmExtras}" ]; then
    logger -p user.notice -t -s "| ${gsScriptName} |  Get ${gsUrlArmExtras}"
    ${binCurl} "${gsUrlArmExtras}" -o "/tmp/arm-extras.tar.gz"
fi

if [ -f "/tmp/arm-extras.tar.gz" ]; then
    logger -p user.notice -t -s "| ${gsScriptName} |  Untar /tmp/arm-extras.tar.gz"
    if [ -f "/tmp/arm-extras.tar.gz" ]; then
        sSubDir="$(tar -ztf "/tmp/arm-extras.tar.gz" | cut -d '/' -f 1 | head -n 1)"
        tar -zxf "/tmp/arm-extras.tar.gz" -C "/tmp/"
        rm -rf "${gsDirArmExtras}"
        mv "/tmp/${sSubDir}" "${gsDirArmExtras}"
        rm -f "/tmp/arm-extras.tar.gz"
    fi
fi

gfnLoadModules 'usb'
gfnLoadModules 'nfs'

exit 0
