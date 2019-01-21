#!/bin/bash

if [ -z "$gbLoaded" ] || [ "$gbLoaded" -eq 0 ]; then
	# shellcheck source=ci/scripts/00-load_vars.sh
	. "$(dirname "$0")/00-load_vars.sh"
fi

if [ -n "$nReturn" ]; then
	if [[ -f /.dockerenv ]]; then
		exit $nReturn
	else
		return $nReturn
	fi
fi
