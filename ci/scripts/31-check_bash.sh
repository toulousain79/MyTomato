#!/bin/bash
######################################################################
# https://github.com/koalaman/shellcheck/wiki/Recursiveness
##################### FIRST LINE #####################################

declare nReturn

if [ -z "$gbLoaded" ] || [ "$gbLoaded" -eq 0 ]; then
	# shellcheck source=ci/scripts/00-load_vars.sh
	. "$(dirname "$0")/00-load_vars.sh"
fi

if [[ -n ${1} ]]; then
	rm -rf /tmp/shellcheck_scan
	if [[ -d "${1}" ]]; then
		rsync -r --exclude '.git' "${1}" /tmp/shellcheck_scan
		sDirToScan="/tmp/shellcheck_scan"
	else
		echo -e "${CYELLOW}${1} not a valid directory:${CEND} ${CRED}Failed${CEND}"
		exit 1
	fi
else
	if [[ -f /.dockerenv ]]; then
		if [[ -n "${CI_PROJECT_PATH}" ]]; then
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
	if ! shellcheck -s sh -x -f tty "${sFile}"; then
		echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
		nReturn=1
	else
		echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
	fi
done

echo && echo -e "${CBLUE}*** Check Syntax with Shellcheck (bash) ***${CEND}"

sFilesList="$(grep -IRl "\(#\!/opt/bin/\|#\!/bin/\|shell\=\)bash" --exclude-dir ".git" --exclude-dir ".vscode" --exclude "*.txt.tmpl" "${sDirToScan}/")"
for sFile in ${sFilesList}; do
	if ! shellcheck -s bash -xa -f tty "${sFile}"; then
		echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
		nReturn=1
	else
		echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
	fi
done

echo && echo -e "${CBLUE}*** Check BASH Syntax ***${CEND}"

for file in ${sFilesList}; do
	sed -i '/includes_before/d' "${file}"
	sed -i '/includes_after/d' "${file}"
	sed -i '/#!\/bin\/bash/d' "${file}"
	sed -i '1iset -n' "${file}"
	if (! bash "${file}"); then
		echo -e "${CYELLOW}${file}:${CEND} ${CRED}Failed${CEND}"
		nReturn=1
	else
		echo -e "${CYELLOW}${file}:${CEND} ${CGREEN}Passed${CEND}"
	fi
done
