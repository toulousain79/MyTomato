#!/usr/bin/env bash

# 1/ lister tous les fichiers .tmpl
# 2/ pour chaque fichier trouvé, rechercher si il est appelé
#   SI trouvé ALORS OK
#   SI trouvé ET commenté ALORS WARNING
#   SINON KO

if [ -z "${vars}" ] || [ "${vars}" -eq 0 ]; then
    # shellcheck source=/dev/null
    . "/builds/${CI_PROJECT_PATH}/ci/scripts/00-libs.sh"
else
    nReturn=$((nReturn + 1))
fi

gfnCopyProject

# Templates files used
sFilesListTmpl="$(find "${sDirToScan}"/root/TEMPLATEs/ -type f -name "*.tmpl" -printf "%f\n" | sort -z | xargs -r0)"
if [ -n "${sFilesListTmpl}" ]; then
    echo && echo -e "${CBLUE}*** Check for unused templates ***${CEND}"
    for sFile in ${sFilesListTmpl}; do
        case "${sFile}" in
            *fake-hwclock* | *rpcbind* | *samba* | *openvpn-client* | *openvpn-server* | *ntpd* | *rstats* | *syslog* | *dnsmasq* | *cstats* | *ip_blacklist* | *domains-* | *-rules*)
                continue
                ;;
            *)
                if (! grep -qR --exclude-dir=.git "${sFile}" "${sDirToScan}"/); then
                    echo -e "${CYELLOW}${sDirToScan}/${sFile}:${CEND} ${CRED}Failed${CEND}"
                    nReturn=$((nReturn + 1))
                else
                    echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
                fi
                ;;
        esac
    done
fi

# Templates files called
sLine="$(grep -rh --exclude-dir=ci --exclude-dir=.git "TEMPLATEs\|\${gsDirTemplates}" "${sDirToScan}"/ | grep -v 'shellcheck')"
if [ -n "${sLine}" ]; then
    echo && echo -e "${CBLUE}*** Check for missing templates ***${CEND}"
    for sColumn in ${sLine}; do
        sColumn="$(echo "${sColumn}" | sed "s/\"//g;s/'//g;s/)//g;s/;//g;")"
        if [ -n "${sColumn}" ]; then
            if (grep -q '.tmpl' <<<"${sColumn}"); then
                if (grep -q 'TEMPLATEs' <<<"${sColumn}"); then
                    sTemplate="$(echo "${sColumn}" | cut -d '/' -f 6)"
                    if [ -n "${sTemplate}" ]; then
                        sFile="$(find "${sDirToScan}"/root/TEMPLATEs/ -type f -name "${sTemplate}")"
                        for FILE in ${sFiles}; do
                            if [ -n "${FILE}" ] && [ -f "${FILE}" ]; then
                                echo -e "${CYELLOW}${sTemplate}:${CEND} ${CGREEN}Passed${CEND}"
                            else
                                echo -e "${CYELLOW}${sTemplate}:${CEND} ${CRED}Failed${CEND}"
                                nReturn=$((nReturn + 1))
                            fi
                        done
                    fi
                elif (grep -q "\${gsDirTemplates}" <<<"${sColumn}"); then
                    sTemplate="$(echo "${sColumn}" | cut -d '/' -f 3)"
                    if [ -n "${sTemplate}" ]; then
                        sFiles="$(find "${sDirToScan}"/root/TEMPLATEs/ -type f -name "${sTemplate}")"
                        for FILE in ${sFiles}; do
                            if [ -n "${FILE}" ] && [ -f "${FILE}" ]; then
                                echo -e "${CYELLOW}${sTemplate}:${CEND} ${CGREEN}Passed${CEND}"
                            else
                                echo -e "${CYELLOW}${sTemplate}:${CEND} ${CRED}Failed${CEND}"
                                nReturn=$((nReturn + 1))
                            fi
                        done
                    fi
                fi
            fi
        fi
    done
fi

export nReturn
