# shellcheck shell=bash

#### MyTomato
# shellcheck source=root/SCRIPTs/inc/vars
[ -f /opt/MyTomato/root/SCRIPTs/inc/vars ] && . /opt/MyTomato/root/SCRIPTs/inc/vars

# enable color support of ls and also add handy aliases
if [ -x /opt/bin/dircolors ]; then
	if test -r ~/.dircolors; then
		eval "$(dircolors -b ~/.dircolors)"
	else
		eval "$(dircolors -b)"
	fi
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias vdir='vdir --color=auto'

	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# Commands
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias s='ssh -l root'

# P2Partisan
{ [ "${gbP2Partisan_Enable}" -eq 1 ]; [ -f /opt/MyTomato/P2Partisan/p2partisan.sh ]; } && alias p2partisan='/opt/MyTomato/P2Partisan/p2partisan.sh'
