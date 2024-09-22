#!/usr/bin/env bash

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[[ -f ${gsDirOverLoad}/vars ]] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs

##############################

#### OPKG
opkg update
opkg upgrade

logger -p user.notice "| ${gsScriptName} | EntWare generate pakages installed list"
gsOpkgPackagesList="${gsDirLogs}/opkg_list-installed_${gdDateTime}.txt"
opkg list-installed | awk '{ print $1 }' >"${gsOpkgPackagesList}"

if [[ -f ${gsOpkgPackagesList} ]]; then
    while read -r line; do
        sPackage="$(echo "${line}" | awk '{ print $1 }')"
        ! opkg list-installed | grep -q "${sPackage}" && opkg install "${sPackage}" \
            logger -p user.notice "| ${gsScriptName} | EntWare install package '${sPackage}'"
    done <"${gsOpkgPackagesList}"
fi

#### MyTomato repo
if [[ ${gbRepoUpgrade_Enable:-0} -eq 1 ]]; then
    [[ -d /opt/MyTomato ]] && cd "/opt/MyTomato" || exit 1
    logger -p user.notice "| ${gsScriptName} | Update /opt/MyTomato via GitHub"
    git fetch origin
    git reset --hard origin/master
    git config pull.rebase false
    git pull origin master
fi

#### DNScrypt-proxy v2
if [[ ! -d /opt/usr/local/dnscrypt-proxy ]]; then
    logger -p user.notice "| ${gsScriptName} | Git clone git@github.com:DNSCrypt/dnscrypt-proxy.git"
    git clone git@github.com:DNSCrypt/dnscrypt-proxy.git "${gsDirDnscrypt:?}"
else
    cd "${gsDirDnscrypt:?}" || exit 1
    logger -p user.notice "| ${gsScriptName} | Update ${gsDirDnscrypt} via GitHub"
    git fetch origin
    git reset --hard origin/master
    # git pull origin master
    [[ -f ${gsDirDnscryptGen}/generate-domains-blocklist.py ]] && {
        mkdir -p "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklist
        cp -v "${gsDirDnscryptGen}"/generate-domains-blocklist.py "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklist/generate-domains-blocklist.py
        chmod +x "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklist/generate-domains-blocklist.py
    }
fi
if [[ -f ${gsDirOverLoad}/dnscrypt/generate-domains-blocklist/generate-domains-blocklist.py && -f ${gsDirOverLoad}/dnscrypt/generate-domains-blocklist/domains-blocklist.conf ]]; then
    cd "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklist/ || exit 1
    logger -p user.notice "| ${gsScriptName} | Generate 'blacklists.txt' with 'generate-domains-blocklist.py'"
    python generate-domains-blocklist.py --output-file list.txt.tmp \
        --config "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklist/domains-blocklist.conf \
        --time-restricted "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklis/domains-time-restricted.txt \
        --allowlist "${gsDirOverLoad}"/dnscrypt/generate-domains-blocklis/domains-allowlist.txt &&
        mv -f list.txt.tmp blacklists.txt
fi

#### SCRIPTs
logger -p user.notice "| ${gsScriptName} | Chmod +x to ${gsDirScripts}/*"
chmod +x "${gsDirScripts}"/*
logger -p user.notice "| ${gsScriptName} | Chmod +x to /opt/MyTomato/P2Partisan/p2partisan.sh"
[[ -f /opt/MyTomato/P2Partisan/p2partisan.sh ]] && chmod +x /opt/MyTomato/P2Partisan/p2partisan.sh

#### NVRAM save
gfnNvramSave

exit 0
