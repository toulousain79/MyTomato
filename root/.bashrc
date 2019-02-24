# shellcheck shell=bash

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTFILESIZE=4096
HISTSIZE=4096

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'
else
    PS1='\u@\h:\w\$ '
fi
unset color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
    xterm* | rxvt*)
        PS1="\[\e]0;\u@\h: \w\a\]$PS1"
        ;;
    *) ;;

esac

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

#### MyTomato
# shellcheck source=root/SCRIPTs/inc/vars
[ -f /opt/MyTomato/root/SCRIPTs/inc/vars ] && . /opt/MyTomato/root/SCRIPTs/inc/vars

# PATH
export PATH=/opt/bin:/opt/sbin:/opt/usr/bin:/opt/usr/sbin:/bin:/sbin:/mmc/bin:/mmc/sbin:/mmc/usr/bin:/mmc/usr/sbin:/usr/bin:/usr/sbin:/home/root:/opt/etc/init.d/:${gsDirScripts}

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
# shellcheck source=root/.bash_aliases
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# Define localization
export LANG="${gsLocales}.UTF-8"
export LC_ALL="${gsLocales}.UTF-8"

# .bash_aliases custom
# shellcheck source=root/.bash_aliases
[ -f "${gsDirOverLoad}/.bash_aliases" ] && . "${gsDirOverLoad}/.bash_aliases"

# .bashrc custom
# shellcheck source=root/.bash_aliases
[ -f "${gsDirOverLoad}/.bashrc" ] && . "${gsDirOverLoad}/.bashrc"

/usr/sbin/mymotd
