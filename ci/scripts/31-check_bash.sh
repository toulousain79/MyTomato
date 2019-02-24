#!/bin/bash
######################################################################
# https://github.com/koalaman/shellcheck/wiki/Recursiveness
##################### FIRST LINE #####################################

if [ -z "$gbLoaded" ] || [ "$gbLoaded" -eq 0 ]; then
    # shellcheck source=ci/scripts/00-load_vars.sh
    . "$(dirname "$0")/00-load_vars.sh"
fi

if [[ -n ${1} ]]; then
    rm -rf /tmp/shellcheck_scan
    if [[ -d ${1} ]]; then
        rsync -r --exclude '.git' "${1}" /tmp/shellcheck_scan
        sDirToScan="/tmp/shellcheck_scan"
    else
        echo -e "${CYELLOW}${1} not a valid directory:${CEND} ${CRED}Failed${CEND}"
        exit 1
    fi
else
    if [[ -f /.dockerenv ]]; then
        if [[ -n ${CI_PROJECT_PATH} ]]; then
            sDirToScan="/builds/${CI_PROJECT_PATH}"
        else
            echo -e "${CYELLOW}Secret Variable \$CI_PROJECT_PATH:${CEND} ${CRED}Failed${CEND}"
            exit 1
        fi
    else
        echo -e "${CYELLOW}You are not in 'project_check' images:${CEND} ${CRED}Failed${CEND}"
        exit 1
    fi
fi

echo && echo -e "${CBLUE}*** Check Syntax with Shellcheck (sh) ***${CEND}"

sFilesList="$(grep -IRl "\(#\!/opt/bin/\|#\!/bin/\|shell\=\)sh" --exclude-dir ".git" --exclude-dir ".vscode" --exclude "*.txt.tmpl" "${sDirToScan}/")"
for sFile in ${sFilesList}; do
    if ! shellcheck -s sh -f tty -S error -S warning -e SC2154 "${sFile}"; then
        echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
        nReturn=1
    else
        echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
    fi
done

echo && echo -e "${CBLUE}*** Check Syntax with Shellcheck (bash) ***${CEND}"

sFilesList="$(grep -IRl "\(#\!/opt/bin/\|#\!/bin/\|shell\=\)bash" --exclude-dir ".git" --exclude-dir ".vscode" --exclude "*.txt.tmpl" "${sDirToScan}/")"
for sFile in ${sFilesList}; do
    if ! shellcheck -s bash -f tty -S error -S warning -e SC2154 "${sFile}"; then
        echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
        nReturn=1
    else
        echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
    fi
done

sFuncsList="$(grep -R -h -E "^[A-Za-z]+[A-Za-z0-9]*(\(\)\ \{)" "${sDirToScan}/" | cut -d '(' -f 1 | sort)"
if [ -n "${sFuncsList}" ]; then
    echo && echo -e "${CBLUE}*** Check for orphan functions ***${CEND}"
    for func in ${sFuncsList}; do
        nCount=$(grep -R "${func}" "${sDirToScan}/" | wc -l)
        case "$nCount" in
            1)
                echo -e "${CYELLOW}${func}:${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
                ;;
            2)
                echo -e "${CYELLOW}${func}:${CEND} ${CGREEN}Use twice, can be optimized${CEND}"
                ;;
            *)
                echo -e "${CYELLOW}${func}:${CEND} ${CGREEN}Passed${CEND}"
                ;;
        esac
    done
fi
