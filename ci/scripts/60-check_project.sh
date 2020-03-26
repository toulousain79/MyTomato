#!/bin/bash

# 1/ lister tous les fichiers .tmpl
# 2/ pour chaque fichier trouvé, rechercher si il est appelé
#   SI trouvé ALORS OK
#   SI trouvé ET commenté ALORS WARNING
#   SINON KO

if [ -z "${vars}" ] || [ "${vars}" -eq 0 ]; then
    # shellcheck source=ci/scripts/00-load_vars.bsh
    source "$(dirname "$0")/00-libs.bsh"
else
    nReturn=${nReturn}
fi

gfnCopyProject

# Templates files used
sFilesListTmpl="$(find "${sDirToScan}"/root/TEMPLATEs/ -type f -name "*.tmpl" -printf "%f\n" | sort -z | xargs -r0)"
if [ -n "${sFilesListTmpl}" ]; then
    echo && echo -e "${CBLUE}*** Check for unused templates ***${CEND}"
    for sFile in ${sFilesListTmpl}; do
        if (grep -q 'etc.logrotate.d.' <<<"${sFile}"); then
            case "${sFile}" in
                'etc.logrotate.d.users.tmpl')
                    if (! grep -qR --exclude-dir=.git "${sFile}" "${sDirToScan}"/); then
                        echo -e "${CYELLOW}${sDirToScan}/${sFile}:${CEND} ${CRED}Failed${CEND}"
                        nReturn=$((nReturn + 1))
                    else
                        echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
                    fi
                    ;;
                *)
                    sString="$(echo "${sFile}" | cut -d '.' -f 4)"
                    if (! grep -qR --exclude-dir=.git "gfnLogRotate '${sString}'" "${sDirToScan}"/); then
                        echo -e "${CYELLOW}${sDirToScan}/${sFile}:${CEND} ${CRED}Failed${CEND}"
                        nReturn=$((nReturn + 1))
                    else
                        echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
                    fi
                    ;;
            esac
        else
            if (! grep -qR --exclude-dir=.git "${sFile}" "${sDirToScan}"/); then
                echo -e "${CYELLOW}${sDirToScan}/${sFile}:${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
            fi
        fi
    done
fi

# Templates files called
sLine="$(grep -rh --exclude-dir=ci --exclude-dir=.git '/TEMPLATEs/' "${sDirToScan}"/)"
if [ -n "${sLine}" ]; then
    echo && echo -e "${CBLUE}*** Check for missing templates ***${CEND}"
    for sColumn in ${sLine}; do
        sColumn="$(echo "${sColumn}" | sed "s/\"//g;s/'//g;s/)//g;s/;//g;")"
        if [ -n "${sColumn}" ]; then
            (grep -q '/TEMPLATEs/' <<<"${sColumn}") && {
                sTemplate="$(echo "${sColumn}" | cut -d '/' -f 4)"
                if [ -n "${sTemplate}" ]; then
                    sFile="$(find "${sDirToScan}"/root/TEMPLATEs/ -type f -name "${sTemplate}")"
                    if [ -n "${sFile}" ] && [ -f "${sFile}" ]; then
                        echo -e "${CYELLOW}${sTemplate}:${CEND} ${CGREEN}Passed${CEND}"
                    else
                        echo -e "${CYELLOW}${sTemplate}:${CEND} ${CRED}Failed${CEND}"
                        nReturn=$((nReturn + 1))
                    fi
                fi
            }
        fi
    done
fi

export nReturn
