#!/bin/bash

nReturn=${nReturn}

echo && echo -e "${CBLUE}*** Current branch ***${CEND}"
if [ -n "${CI_COMMIT_REF_NAME}" ]; then
    echo "${CI_COMMIT_REF_NAME}"
else
    git branch | grep "^* "
fi

echo && echo -e "${CBLUE}*** Check bash version ***${CEND}"
if (! bash --version); then
    echo -e "${CYELLOW}bash version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check shellcheck version ***${CEND}"
if (! shellcheck --version); then
    echo -e "${CYELLOW}shellcheck version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check dos2unix version ***${CEND}"
if (! dos2unix --version); then
    echo -e "${CYELLOW}dos2unix version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check xz version ***${CEND}"
if (! xz --version); then
    echo -e "${CYELLOW}xz version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check rsync version ***${CEND}"
if (! rsync --version); then
    echo -e "${CYELLOW}rsync version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check pylint version ***${CEND}"
if (! pylint --version); then
    echo -e "${CYELLOW}pylint version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

echo && echo -e "${CBLUE}*** Check pylint3 version ***${CEND}"
if (! pylint3 --version); then
    echo -e "${CYELLOW}pylint3 version:${CEND} ${CRED}Failed${CEND}"
    nReturn=$((nReturn + 1))
fi

export nReturn
