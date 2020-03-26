#!/bin/bash

if [ -z "${vars}" ] || [ "${vars}" -eq 0 ]; then
    # shellcheck source=ci/scripts/00-load_vars.sh
    . "/builds/${CI_PROJECT_PATH}/ci/scripts/00-libs.sh"
else
    nReturn=${nReturn}
fi

# sFilesList="$(grep -IRl "\(#\!/usr/bin/env\) python2" --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir "ci" "${sDirToScan}/")"
# if [ -n "${sFilesList}" ]; then
#     echo && echo -e "${CBLUE}*** Check Python2 Syntax ***${CEND}"
#     for file in ${sFilesList}; do
#         if (! pylint --disable=len-as-condition,too-few-public-methods,consider-using-ternary "${file}"); then
#             echo -e "${CYELLOW}${file}:${CEND} ${CRED}Failed${CEND}"
#             nReturn=$((nReturn + 1))
#         else
#             echo -e "${CYELLOW}${file}:${CEND} ${CGREEN}Passed${CEND}"
#         fi
#     done
# fi

sFilesList="$(grep -IRl "\(#\!/usr/bin/env\) python3" --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir "ci" "${sDirToScan}/")"
if [ -n "${sFilesList}" ]; then
    echo && echo -e "${CBLUE}*** Check Python3 Syntax ***${CEND}"
    for file in ${sFilesList}; do
        if (! pylint3 "${file}"); then
            echo -e "${CYELLOW}${file}:${CEND} ${CRED}Failed${CEND}"
            nReturn=$((nReturn + 1))
        else
            echo -e "${CYELLOW}${file}:${CEND} ${CGREEN}Passed${CEND}"
        fi
    done
fi

export nReturn

##################### LAST LINE ######################################
