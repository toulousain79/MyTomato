#!/bin/bash

#### 0 - Base
sPwd=$(pwd)
nReturn=0
[ -n "${CI_PROJECT_PATH}" ] && sProjectDir="/builds/${CI_PROJECT_PATH}" || sProjectDir="$(pwd)"
sDirToScan="/tmp/shellcheck_scan"

#### 1 - Colors
CEND="\033[0m"
CRED="\033[1;31m"
CGREEN="\033[1;32m"
CYELLOW="\033[1;33m"
CBLUE="\033[1;34m"

#### 2 - Functions
function gfnCopyProject() {
    [ -d "${sDirToScan}" ] && rm -rf "${sDirToScan}"

    if [ -n "${sProjectDir}" ] && [ -d "${sProjectDir}" ]; then
        rsync -a --exclude '.git' "${sProjectDir}/" "${sDirToScan}/"
    else
        echo -e "${CYELLOW}You are not in 'project_validation' images:${CEND} ${CRED}Failed${CEND}"
        exit 1
    fi
}

#### Export
export gbLoaded sPwd nReturn CEND CRED CGREEN CYELLOW CBLUE
