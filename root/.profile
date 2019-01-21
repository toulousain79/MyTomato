# shellcheck shell=bash
# shellcheck disable=SC1091

[ -f /opt/etc/profile ] && . /opt/etc/profile
BASH_VERSION="$(bash --version 2>/dev/null | head -n 1)"

export BASH_VERSION
export TERM=xterm-color

if [ -n "$BASH_VERSION" ]; then
	bash
fi

exit
