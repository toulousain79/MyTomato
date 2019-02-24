#!/opt/bin/bash

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
if [ "${gbRepoUpgrade_Enable:?}" -eq 1 ]; then
    [ -d "/opt/MyTomato" ] && cd "/opt/MyTomato" || exit 1
    logger -p user.notice "| ${gsScriptName} | Update /opt/MyTomato via GitHub"
    git fetch origin
    git reset --hard origin/master
    git pull origin master
fi

#### DNScrypt-proxy v2
if [ ! -d /opt/usr/local/dnscrypt-proxy ]; then
    logger -p user.notice "| ${gsScriptName} | Git clone https://github.com/jedisct1/dnscrypt-proxy.git"
    git clone git://github.com/jedisct1/dnscrypt-proxy.git "${gsDirDnscrypt:?}"
else
    cd "${gsDirDnscrypt:?}" || exit 1
    logger -p user.notice "| ${gsScriptName} | Update ${gsDirDnscrypt} via GitHub"
    # git fetch origin
    # git reset --hard origin/master
    git pull origin master
fi
if [ -f "${gsDirDnscryptGen:?}"/generate-domains-blacklist.py ]; then
    cd "${gsDirDnscryptGen}"/ || exit 1
    chmod +x generate-domains-blacklist.py
    logger -p user.notice "| ${gsScriptName} | Generate 'blacklists.txt' with 'generate-domains-blacklist.py'"
    python generate-domains-blacklist.py -c domains-blacklist.conf >list.txt.tmp && mv -f list.txt.tmp blacklists.txt
    [ -f "${gsDirTemplates}/init/S09dnscrypt-proxy2.tmpl" ] && cp "${gsDirTemplates}/init/S09dnscrypt-proxy2.tmpl" /opt/etc/init.d/S09dnscrypt-proxy2
    [ -f /opt/etc/init.d/S09dnscrypt-proxy2 ] && chmod +x /opt/etc/init.d/S09dnscrypt-proxy2
fi

#### SCRIPTs
logger -p user.notice "| ${gsScriptName} | Chmod +x to ${gsDirScripts}/*"
chmod +x ${gsDirScripts}/*
logger -p user.notice "| ${gsScriptName} | Chmod +x to /opt/MyTomato/P2Partisan/p2partisan.sh"
[ -f /opt/MyTomato/P2Partisan/p2partisan.sh ] && chmod +x /opt/MyTomato/P2Partisan/p2partisan.sh

#### NVRAM save
gfnNvramSave

exit 0
