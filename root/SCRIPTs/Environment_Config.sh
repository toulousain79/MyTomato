#!/opt/bin/bash

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

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
if (! /opt/bin/mount -l | grep -q '/opt/tmp'); then
    mount -t tmpfs -o size=256M,mode=0755 tmpfs /opt/tmp/
    cp -af /tmp/* /opt/tmp/
    rm -rRf /tmp/* && rm -rRf /tmp/.??*
    /opt/bin/mount --bind /opt/tmp /tmp
fi

# /opt/var/log
if (! /opt/bin/mount -l | grep -q '/tmp/var/log'); then
    if [ -f /tmp/var/log/messages ]; then
        gfnStartStopSyslogd 'stop'
        echo "$(/bin/date '+%a %b %d %T %Y') $(nvram get lan_hostname) user.notice | ${gsScriptName} | Copy /tmp/var/log/messages to /opt/var/log/messages" >>/opt/var/log/messages
        cat /tmp/var/log/messages >>/opt/var/log/messages
        if [ ! -f /tmp/var/log/.uuid ]; then
            echo "$(/bin/date '+%a %b %d %T %Y') $(nvram get lan_hostname) user.notice | ${gsScriptName} | Clean /tmp/var/log/" >>/opt/var/log/messages
            rm -rRf /tmp/var/log/* && rm -rRf /tmp/var/log/.??*
        fi
        echo "$(/bin/date '+%a %b %d %T %Y') $(nvram get lan_hostname) user.notice | ${gsScriptName} | Mount /opt/var/log to /tmp/var/log" >>/opt/var/log/messages
        /opt/bin/mount --bind /opt/var/log /tmp/var/log
        gfnStartStopSyslogd 'start'
    fi
fi

# /opt/root
if (! /opt/bin/mount -l | grep -q '/tmp/home/root'); then
    if [ ! -f /tmp/home/root/.uuid ]; then
        logger -p user.notice "| ${gsScriptName} | Clean /tmp/home/root/"
        rm -rRf /tmp/home/root/* && rm -rRf /tmp/home/root/.??*
    fi
    if [ ! -f /opt/root/.uuid ]; then
        logger -p user.notice "| ${gsScriptName} | Clean /opt/root/"
        rm -rRf /opt/root/* && rm -rRf /opt/root/.??*
    fi
    logger -p user.notice "| ${gsScriptName} | Mount /opt/MyTomato/root to /tmp/home/root"
    /opt/bin/mount --bind /opt/MyTomato/root /tmp/home/root
fi

#### Create /opt/.autorun script
cp -v "${gsDirTemplates}"/.autorun.tmpl /opt/.autorun
chmod +x /opt/.autorun

#### rc.unslung / rc.func
# Create a backup of original files
{ [ -f /opt/etc/init.d/rc.unslung ] && [ ! -f "${gsDirBackups}/rc.unslung.original" ]; } &&
    cp /opt/etc/init.d/rc.unslung "${gsDirBackups}/rc.unslung.original"
{ [ -f /opt/etc/init.d/rc.func ] && [ ! -f "${gsDirBackups}/rc.func.original" ]; } &&
    cp /opt/etc/init.d/rc.func "${gsDirBackups}/rc.func.original"
# Replace original scripts by the templates
[ -f "${gsDirTemplates}/init/rc.unslung.tmpl" ] && cp "${gsDirTemplates}/init/rc.unslung.tmpl" /opt/etc/init.d/rc.unslung
[ -f "${gsDirTemplates}/init/rc.func.tmpl" ] && cp "${gsDirTemplates}/init/rc.func.tmpl" /opt/etc/init.d/rc.func
chmod +x /opt/etc/init.d/*

#### Replace binaries with aliases
if [ -d /opt/bin/ ]; then
    # Create an empty file if needed
    [ ! -f "${gsDirOverLoad}/.bash_aliases" ] && touch "${gsDirOverLoad}/.bash_aliases"

    # Add some aliases manualy
    (! grep -q 'vi=' "${gsDirOverLoad}/.bash_aliases") &&
        {
            echo "alias vi='/opt/bin/vim'"
        } >"${gsDirOverLoad}/.bash_aliases"

    # Generate aliases list
    for bin in $(/opt/bin/find /opt/bin/ /opt/sbin/ -type f ! -type d -perm '-u+x' | grep -v '[0-9*]\.' | sort); do
        # Ignore links
        [ -h "${bin}" ] && continue
        [ "$(whereis "${bin}" | awk '{ print $2 }')" == "${bin}" ] || continue

        (! grep -q "${bin}" "${gsDirOverLoad}/.bash_aliases") &&
            echo "alias $(echo "${bin}" | cut -d '/' -f 4)='${bin}'" >>"${gsDirOverLoad}/.bash_aliases"
    done
    cat "${gsDirOverLoad}/.bash_aliases" >>/tmp/to_syslog
fi

#### Add bash to shells
(! grep -q '/bin/bash' /opt/etc/shells) && echo "/bin/bash" >>/opt/etc/shells
(! grep -q '/opt/bin/bash' /opt/etc/shells) && echo "/opt/bin/bash" >>/opt/etc/shells
cat /opt/etc/shells >>/tmp/to_syslog

#### /etc/group
[ ! -f /opt/etc/group ] && cp -fv /etc/group /opt/etc/group
[ -f /opt/etc/group ] && (! grep -q 'mlocate' /opt/etc/group) && echo "mlocate:x:111:" >>/opt/etc/group
cat /opt/etc/group >>/tmp/to_syslog

#### Purge LOGs files (internal use)
[ -n "${gsDirLogs}" ] && /opt/bin/find "${gsDirLogs}/" -type f -mtime +30 -exec rm -vf {} \; >>/tmp/to_syslog
[ -n "${gsDirBackups}" ] && /opt/bin/find "${gsDirBackups}/" -type f -mtime +30 -exec rm -vf {} \; >>/tmp/to_syslog

#### Copy back local logs to Syslog
gfnCopyToSyslog

#### Locales
if [ -n "${gsLocales}" ]; then
    logger -p user.notice "| ${gsScriptName} |  Add locales '${gsLocales}'"
    /opt/bin/localedef.new -c -f UTF-8 -i "${gsLocales}" "${gsLocales}.UTF-8"
fi
if [ -n "${gsTimezone}" ]; then
    logger -p user.notice "| ${gsScriptName} |  Add timezone '${gsTimezone}'"
    ln -sf /opt/share/zoneinfo/${gsTimezone} /opt/etc/localtime
fi

exit 0
