#!/bin/bash
######################################################################
# https://github.com/koalaman/shellcheck/wiki/Recursiveness
##################### FIRST LINE #####################################

if [ -z "${vars}" ] || [ "${vars}" -eq 0 ]; then
    # shellcheck source=ci/scripts/00-load_vars.sh
    . "/builds/${CI_PROJECT_PATH}/ci/scripts/00-libs.sh"
else
    nReturn=${nReturn}
fi

gfnCopyProject

sFilesListSh="$(grep -IRl "\(#\!/bin/\|shell\=\)sh" --exclude-dir ".git" --exclude-dir ".vscode" --exclude "funcs_*" "${sDirToScan}/")"
if [ -n "${sFilesListSh}" ]; then
    echo && echo -e "${CBLUE}*** Check Syntax with Shellcheck (sh) ***${CEND}"
    for sFile in ${sFilesListSh}; do
        if ! shellcheck -s sh -f tty -S error -S warning -e SC2154 "${sFile}"; then
            echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
            nReturn=$((nReturn + 1))
        else
            echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
        fi
    done
fi

sFilesListBash="$(grep -IRl "\(#\!/bin/\|shell\=\)bash" --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir ".vscode" "${sDirToScan}/")"
if [ -n "${sFilesListBash}" ]; then
    echo && echo -e "${CBLUE}*** Check Syntax with Shellcheck (bash) ***${CEND}"
    for sFile in ${sFilesListBash}; do
        if ! shellcheck -s bash -f tty -S error -S warning -e SC2154 "${sFile}"; then
            echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
            nReturn=$((nReturn + 1))
        else
            echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
        fi
    done
fi

sFuncsList="$(grep -R -h -E "^[A-Za-z]+[A-Za-z0-9]*(\(\)\ \{)" "${sDirToScan}/root/SCRIPTs/inc/" | cut -d '(' -f 1 | sort)"
if [ -n "${sFuncsList}" ]; then
    echo && echo -e "${CBLUE}*** Check for orphan functions ***${CEND}"
    for func in ${sFuncsList}; do
        nCount=$(grep -R "${func}" "${sDirToScan}/" | wc -l)
        case "${nCount}" in
            1)
                echo -e "${CYELLOW}${func}:${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
                ;;
            *)
                echo -e "${CYELLOW}${func}:${CEND} ${CGREEN}Passed${CEND}"
                ;;
        esac
    done
fi

sFilesListSh="$(grep -IRl "\(#\!/bin/\|shell\=\)sh" --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir "ci" "${sDirToScan}/")"
sFilesListBash="$(grep -IRl "\(#\!/bin/\|shell\=\)bash" --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir "ci" "${sDirToScan}/")"
sFilesList="${sFilesListSh} ${sFilesListBash}"
if [ -n "${sFilesList}" ]; then
    echo && echo -e "${CBLUE}*** Check scripts with 'set -n' ***${CEND}"
    for file in ${sFilesList}; do
        sed -i '/includes_before/d' "${file}"
        sed -i '/includes_after/d' "${file}"
        sed -i '/#!\/bin\/bash/d' "${file}"
        sed -i '1iset -n' "${file}"
        echo "set +n" >>"${file}"
        dos2unix "${file}" &>/dev/null
        if (bash "${file}"); then
            echo -e "${CYELLOW}${file}:${CEND} ${CGREEN}Passed${CEND}"
        else
            echo -e "${CYELLOW}${file}:${CEND} ${CRED}Failed${CEND}"
            nReturn=$((nReturn + 1))
        fi
    done
fi
