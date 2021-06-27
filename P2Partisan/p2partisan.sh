#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2002,SC2003,SC2009,SC2012,SC2126
#
# p2partisan v6.10 (2021/06/27)
#
# Official page - http://www.linksysinfo.org/index.php?posts/235301/
#
# <CONFIGURATION> ###########################################
# Adjust location where the files are kept
P2Partisandir=/opt/MyTomato/P2Partisan
#
# Enable logging? Use only for troubleshooting. 0=off 1=on
syslogs=1
# Maximum number of logs to be recorded in a given 60 min
# Consider set this very low (like 3 or 6) once your are
# happy with the installation. To troubleshoot blocked
# connection close all the secondary traffic e.g. p2p
# and try a connection to the blocked site/port you should
# find a reference in the logs.
maxloghour=1
#
# Ports to be whitelisted. Whitelisted ports will never be
# blocked no matter what the source/destination IP is.
# This is very important if you're running a service like
# e.g. SMTP/HTTP/IMAP/else. Separate value in the list below
# with commas - NOTE: It is suggested to leave the following ports
# always on as a minimum:
# tcp:43,80,443
# udp:53,123,1194:1196
# you might want to append remote admin and VPN ports, and
# anything else you think it's relevant.
# Standard iptables syntax, individual ports divided by "," and ":" to
# define a range e.g. 80,443,2100:2130. Do not whitelist you P2P client!
whiteports_tcp=43,80,443
whiteports_udp=53,123
#
# Greyports are port/s you absolutely want to filter against lists.
# Think of an Internet host that has its P2P client set on port 53 UDP.
# If you have the DNS port is in the whiteports_udp then P2Partisan would
# be completely bypassed. Internet-client:53 -> your-client:"P2Pport""
# greyport is in a nutshell a list of port/s used by your LAN P2Pclient/s.
# It's suggested you disable random port on your P2Pclient and add the
# client port/s here. NOTE:
# Accepted syntax: single port, multiple ports and ranges e.g.
# greyports=22008,6789
# the above would grey list 22008 and 6789. Don't know your client port?
# try ./p2partisan.sh detective
greyports_tcp=
greyports_udp=
#
# Greyline is the limit of connections per given "IP:port" above which
# Detective becomes suspicious. NOTE: This counts 1/2 of the sessions the
# router actually reports on because of the NAT implication. So this number
# represents the session as seen on the LAN client. Affects detective only.
greyline=100
#
# Schedule defines the allowed hours when P2Partisan tutor can update lists
# Use the syntax from 0 to 23. e.g. 1,6 allows updates from 1 to 6 am
scheduleupdates="1,6"
#
# Defines how many lists can be loaded concurrently at any given time. Default 2
maxconcurrentlistload=2
#
# IP for testing Internet connectivity
testip=google.com
# </CONFIGURATION> ###########################################

#### Includes
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
# shellcheck source=root/SCRIPTs/inc/vars
[ -f "${gsDirOverLoad}/vars" ] && . "${gsDirOverLoad}/vars"

sDNS="$(echo "${gsWan1_DNS}" | awk '{print $1}')"
[ -z "${sDNS}" ] && sDNS="9.9.9.9"

# DNScrypt-proxy
if [ "$(nvram get dnscrypt2_enable)" == "1" ]; then
    whiteports_tcp=${whiteports_tcp},52
    whiteports_udp=${whiteports_udp},52
fi
# Get all others ports in NVRAM
for result in $(nvram show 2>/dev/null | grep 'port='); do
    service=$(echo "${result}" | cut -f1 -d '=')
    port=$(echo "${result}" | cut -f2 -d '=')
    [ "${port}" -eq 0 ] && continue

    if (echo "${service}" | grep -q -e 'radius' -e 'snmp' -e 'log' -e 'udpxy'); then
        whiteports_udp=${whiteports_udp},${port}
    elif (echo "${service}" | grep -q -e 'wan' -e 'lan' -e 'ssh' -e 'ftp' -e 'telnet'); then
        whiteports_tcp=${whiteports_tcp},${port}
    elif (echo "${service}" | grep -q 'vpn_client'); then
        if (nvram get vpn_client_eas | grep -q "${service//[^0-9]/}"); then
            case "$(nvram get "${service//_port/_proto}")" in
                'udp') whiteports_udp=${whiteports_udp},${port} ;;
                'tcp') whiteports_tcp=${whiteports_tcp},${port} ;;
            esac
        fi
    elif (echo "${service}" | grep -q 'vpn_server'); then
        if (nvram get vpn_server_eas | grep -q "${service//[^0-9]/}"); then
            case "$(nvram get "${service//_port/_proto}")" in
                'udp') whiteports_udp=${whiteports_udp},${port} ;;
                'tcp') whiteports_tcp=${whiteports_tcp},${port} ;;
            esac
        fi
    fi
done
# Sort results
whiteports_udp=$(echo "${whiteports_udp},${gsP2Partisan_UdpPorts}" | tr "," "\n" | sort -nu | tr "\n" "," | sed 's/,$//g;')
whiteports_tcp=$(echo "${whiteports_tcp},${gsP2Partisan_TcpPorts}" | tr "," "\n" | sort -nu | tr "\n" "," | sed 's/,$//g;')

ipsetversion=$(ipset -V | grep ipset | awk '{print $2}' | cut -c2) #4=old 6=new
if [[ ${ipsetversion} -ne 6 ]]; then
    echo -e "\033[1;31mipset not compatible with this P2Partisan release.
ipset available: ${ipsetversion}
ipset supported: 6.x\033[0;40m"
    exit
fi

# Wait until Internet is available
max=5
while :; do
    if [[ ${count} -ge ${max} ]]; then
        echo -e "\033[1;31 $testip is not responding, exiting...\033[0;40m"
        exit
    fi
    if (ping -c 3 $testip >/dev/null 2>&1); then
        break
    fi
    sleep 5
    count=$((count + 1))
done

pidfile="/var/run/p2partisan.pid"
logfile=$(nvram get log_file_path) || logfile=$(/var/log/messages)
[ -n "${P2Partisandir}" ] && cd ${P2Partisandir} || exit 1
[ ! -d ./cidr/ ] && mkdir -p ./cidr/
version=$(grep 'p2partisan v' ./p2partisan.sh | head -1 | awk '{print $3}')
shopt -s expand_aliases
alias ipset='/bin/nice -n10 /usr/sbin/ipset'
alias sed='/bin/sed'
alias iptables='/usr/sbin/iptables'
alias service='/sbin/service'
alias killall='/usr/bin/killall'
alias plog='logger "| P2PARTISAN | "'
alias deaggregate='/bin/nice -n10 /tmp/deaggregate.sh'
service ntpc restart >/dev/null
now=$(date +%s)
rm=1
wanif=$(nvram get wan_ifname) && rm=0 || wanif=$(nvram get wan_ifnames) #RMerlin work around
#lanif=$(nvram get lan_ifname)
vpnif=$(route | grep -E '^default.*.tun..$|^default.*.ppp.$' | awk '{print $8}')

# DHCP hardcoded patch
p1=$(echo "${whiteports_udp}" | grep -Eo '^67[,|:]|[,|:]67[,|:]|,67$' | wc -l)
p2=$(echo "${whiteports_udp}" | grep -Eo '^68[,|:]|[,|:]68[,|:]|,68$' | wc -l)
if [[ $p1 -eq 0 ]]; then
    whiteports_udp="${whiteports_udp},67"
fi
if [[ $p2 -eq 0 ]]; then
    whiteports_udp="${whiteports_udp},68"
fi

[ -f /tmp/deaggregate.sh ] ||
    {
        # Encrypt command: cat /tmp/deaggregate.sh | gzip | openssl enc -base64
        b64="openssl enc -base64 -d"
        [[ "$(echo WQ== | $b64)" != "Y" ]] && b64="b64"

        {
            cat <<'ENDF' | $b64 | gunzip >/tmp/deaggregate.sh
H4sIAAAAAAAAA+1VXW/bNhR916+4ob1GqiXLUpamTaoAXbINAbomWArswU0HRaJt
IjKlknTsNdF/372i5q+kWzAM3UvlB4vkuffcj3Opzk54LWSoJ04H9IQXRTbh2Q3k
QqfXBU8uT+JB9MK/PIkGryLH6eADZzIrZjnXmxa6nKmMJ6osTXh58uvZxXsdCpmF
t6nSTh/CsjLhL3+8L6epKcPHUU/3N4RgBKx7N9anQp3fcvW2TPO6OWNwBc+eQf9L
x46jT99dJqzr8mxSWtRvqYx+x92awT2k8xvYvauUkAa6Ub3rMaL7TEhtMQ2B9fKq
3/zQa87T8VjxcWq468GdA/g0pZUi4xDIaGA9O6OZzIwoJYgqRg5XVBY+KhW4iptk
4MtEV4WgIz/12Yc+8/xFEh0tXifyaNHreUCwUrmFnoiRISP/peenw8WVh45wOVOS
/pzaWaOTJhYV+ST8wpKSo1TmtBvv75O1qBJl3eLeS88G5iL33tEWmPUZedoy8CnA
owdh/PDjz2fvkPJaGJ0MFqP2cX7CIg6DK0YYCug61TxpK9ONiJ7LfLkR08Z8IgoO
LiHhdULnNhdteAUJDFYQwMgJ5kNbqchvUJ4HO0lDZS3FaB3bZuNSqD64e1FgbdDq
mNjAGl0rnt5QonXL3eu1C6udtt4NCwuZuxdbP22SYAOA3nZsjZPa2YUOcZWjRjY6
U6JqCinTKUf13kU1cwqhscYFLWNcljNTzQyt9nBVqQb3Pb7qeVrR+z7Z4CjQ+wt8
v4gvUmVw1GUuFG0e1CuxW29/yb31PVgek5+tQ7wgdMGxCZFjGzBEoDsSmEZoplUI
wTRd5LwyE4hwIjAR2H3ef3v+5nQX4uMw57ehnBUFzuA8g6DwGARjvs51BHnZDJal
2XfyUnLHwfYNYRkwBPwTxAQ2Ey4buJ1GepqZj+GYNQFVcdXm3+/eUTx1Ew1bwkWl
uYFgB1WsTalwjkeUF4a0UbqahZnIVchaL6xPy6UXNYUn8NXrNXB48UhW0UZWTS7R
k3KZjymNcwiaalrVYEE3iz6eyc+igvtl3HidVRDcAvs4HB7qKs344dXV886H+411
l62ZZDPkyQ+xTvHa7trdiDyrbliV4BzlECigmi07vNWBNxB8oj4sK0xvZFCvmtWI
YcvuFIL0gZ29xrehj1JsQ/GisHAaqS0o7tTMW2vQJoFOb/kK989KsrhNJfFC879x
3Qbzr0Q6EqsmTqZlDgcHB/+b0AcPhT74JvSvKfT/TFdfVUwoYvs1CCTS4ReQbQip
KrVJum5O7el9p71mU82kEfhN7bounaN00M7zVsrrtggU4BcyaAFE/yf+y+ssUAsA
AA==
ENDF
        }
        chmod 777 /tmp/deaggregate.sh
    }

function psoftstop() {
    [ -f /tmp/p2partisan.loading ] && echo "P2Partisan is still loading. Can't stop right now Exiting..." && exit
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                   _______ __
|                  |     __|  |_.-----.-----.
|                  |__     |   _|  _  |  _  |
|            Soft  |_______|____|_____|   __|
|                                     |__|
|
+---------------------------------------------------------------+"
    echo -e "| Stopping P2Partisan..."
    ./iptables-del 2>/dev/null
    plog "Stopping P2Partisan..."
    [ -f ${pidfile} ] && rm -f "${pidfile}" 2>/dev/null
    [ -f iptables-add ] && rm -f "iptables-add" 2>/dev/null
    [ -f iptables-del ] && rm -f "iptables-del" 2>/dev/null
    ptutorunset
    echo -e "+---------------------------------------------------------------+ \033[0;39m"
}

function pforcestop() {
    if [ -n "$1" ]; then
        if [ "$1" != fix ]; then
            name=$1
            echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|  _____   __         __                         __         __
| |     |_|__|.-----.|  |_ ______.--.--.-----.--|  |.---.-.|  |_.-----.
| |       |  ||__ --||   _|______|  |  |  _  |  _  ||  _  ||   _|  -__|
| |_______|__||_____||____|      |_____|   __|_____||___._||____|_____|
|                                     |__|
|
+---------------------------------------------------------------+
|			background updating list: \033[1;35m$1\033[0;40m
+---------------------------------------------------------------+\033[0;39m"

            grep -Ev "^$" ./blacklists | tr -d "\r" | grep -E "^#( .*|)${name} http*." >/dev/null 2>&1 && {
                echo -e "\033[0;40m| Warning: \033[1;33mthe list reference exists but is currently disabled in the blacklists\033[0;40m
+---------------------------------------------------------------+\033[0;39m"
                exit
            } 2>/dev/null
            {
                grep -Ev "^#|^$" ./blacklists | tr -d "\r" | grep "${name}" >/dev/null 2>&1 || {
                    echo -e "\033[0;40m| Error: \033[1;31mit appears like the list ${name} is not a valid reference.\033[0;40m Typo?
+---------------------------------------------------------------+\033[0;39m"
                    exit
                } 2>/dev/null
            }

            url=$(grep -Ev "^#|^$" ./blacklists | tr -d "\r" | grep "${name}" | awk '{print $2}')

            if [ -n "$url" ]; then
                ps | grep -E ".*deaggregate.sh ${name}" | grep -v grep | cut -c1-6 | while read -r line; do kill "${line}" >/dev/null; done
                rm "/tmp/p2partisan.${name}.LOAD" 2>/dev/null
                if [ "$(ipset --swap "${name}.bro" "${name}.bro" 2>&1 | grep 'does not exist')" != "" ]; then
                    ipset -N "${name}.bro" hash:net hashsize 1024 --resize 5 maxelem 4096000
                fi

                statusaaa=$(ipset -T "${name}".bro ${sDNS} 2>/dev/null && echo "1" || echo "0")
                statusaa=$(ipset -L "${name}" 2>/dev/null | head -8 | tail -1 | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).*" >/dev/null && echo "1" || echo "0")
                if [[ $statusaa -eq 0 ]]; then
                    if [[ $statusaaa -eq 1 ]]; then
                        {
                            ipset swap "${name}" "${name}".bro
                            ipset -F "${name}".bro
                            ipset -X "${name}".bro
                            ipset -N "${name}".bro hash:net hashsize 1024 --resize 5 maxelem 4096000
                            deaggregate "${name}".bro "$url" 1 "" "${name}" $maxconcurrentlistload ${P2Partisandir} &
                        } 2>/dev/null
                    elif [[ $statusaaa -eq 0 ]]; then
                        {
                            ipset -F "${name}"
                            ipset -N "${name}" hash:net hashsize 1024 --resize 5 maxelem 4096000
                            deaggregate "${name}" "$url" 1 "" "" $maxconcurrentlistload ${P2Partisandir} &
                        } 2>/dev/null
                    fi
                elif [[ $statusaa -eq 1 ]]; then
                    {
                        ipset -F "${name}".bro
                        ipset -X "${name}".bro
                        ipset -N "${name}".bro hash:net hashsize 1024 --resize 5 maxelem 4096000
                        deaggregate "${name}".bro "$url" 1 "" "${name}" $maxconcurrentlistload ${P2Partisandir} &
                    } 2>/dev/null
                fi
            else
                echo -e "|					\033[1;31mError: list not found\033[0;40m
+---------------------------------------------------------------+\033[0;39m"
            fi
            exit
        elif [ "$1" == "fix" ]; then
            rm ./cidr/*.cidr 2>/dev/null
        fi
    fi
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                   _______ __
|                  |     __|  |_.-----.-----.
|                  |__     |   _|  _  |  _  |
|            Hard  |_______|____|_____|   __|
|                                     |__|
|
+---------------------------------------------------------------+"
    {
        counter=0
        killall "deaggregate.sh" >/dev/null
        while iptables -L wanin | grep P2PARTISAN-IN; do
            iptables -D wanin -i "$wanif" -m state --state NEW -j P2PARTISAN-IN
        done
        while iptables -L wanout | grep P2PARTISAN-OUT; do
            iptables -D wanout -o "$wanif" -m state --state NEW -j P2PARTISAN-OUT
        done
        while iptables -L INPUT | grep P2PARTISAN-IN; do
            iptables -D INPUT -i "$wanif" -m state --state NEW -j P2PARTISAN-IN
        done
        while iptables -L OUTPUT | grep P2PARTISAN-OUT; do
            iptables -D OUTPUT -o "$wanif" -m state --state NEW -j P2PARTISAN-OUT
        done
        iptables -D INPUT -o "$vpnif" -m state --state NEW -j P2PARTISAN-IN
        iptables -D OUTPUT -i "$vpnif" -m state --state NEW -j P2PARTISAN-IN
        iptables -D FORWARD -o "$vpnif" -m state --state NEW -j P2PARTISAN-IN
        iptables -F P2PARTISAN-DROP-IN
        iptables -F P2PARTISAN-DROP-OUT
        iptables -F P2PARTISAN-LISTS-IN
        iptables -F P2PARTISAN-LISTS-OUT
        iptables -F P2PARTISAN-IN
        iptables -F P2PARTISAN-OUT
        iptables -X P2PARTISAN-DROP-IN
        iptables -X P2PARTISAN-DROP-OUT
        iptables -X P2PARTISAN-LISTS-IN
        iptables -X P2PARTISAN-LISTS-OUT
        iptables -X P2PARTISAN-IN
        iptables -X P2PARTISAN-OUT
        ipset -F
        for i in $(ipset --list | grep Name | cut -f2 -d ":"); do
            ipset -X "$i"
        done
        chmod 777 ./*.gz
        [ -f iptables-add ] && rm iptables-add
        [ -f iptables-del ] && rm iptables-del
        [ -f ipset-del ] && rm ipset-del
        [ -f ${pidfile} ] && rm -f "${pidfile}"
        [ -f runtime ] && rm -f "runtime"
        [ -f /tmp/p2partisan.loading ] && rm -r /tmp/p2partisan.loading
        plog "Unloading ipset modules"
        lsmod | grep "xt_set" && sleep 2
        rmmod -f xt_set
        lsmod | grep "ip_set_hash_net" && sleep 2
        rmmod -f ip_set_hash_net
        lsmod | grep "ip_set" && sleep 2
        rmmod -f ip_set
        plog "Removing the list files"
        grep -Ev "^#|^$" ./blacklists | tr -d "\r" |
            (
                while read -r line; do
                    counter=$(expr ${counter} + 1)
                    counter=$(printf "%02d" "${counter}")
                    name=$(echo "${line}" | awk '{print $1}')
                    echo -e "| Removing Blacklist_${counter} --> \033[1;37m***${name}***\033[0;40m"
                    [ -f ./"${name}".gz ] && rm -f ./"${name}".gz
                done
            )
        rm /tmp/*.LOAD
    } >/dev/null 2>&1
    ptutorunset
    plog "P2Partisan stopped"
    echo -e "+---------------------------------------------------------------+\033[0;39m"
}

function pstatus() {
    if [ -n "$1" ]; then
        name=$1
        echo -e "\033[0;40m

+------------------------- P2Partisan --------------------------+
|  _____   __         __          _______ __          __
| |     |_|__|.-----.|  |_ ______|     __|  |_.---.-.|  |_.--.--.-----.
| |       |  ||__ --||   _|______|__     |   _|  _  ||   _|  |  |__ --|
| |_______|__||_____||____|      |_______|____|___._||____|_____|_____|
|
+---------------------------------------------------------------+
|					list name: \033[1;33m$1\033[0;40m
+---------------------------------------------------------------+"

        grep -Ev "^$" ./blacklists | tr -d "\r" | grep -E "^#( .*|)${name} http*." >/dev/null 2>&1 && {
            echo -e "| Warning: \033[1;33mthe list reference exists but is currently disabled in the blacklists\033[0;40m
+---------------------------------------------------------------+"
            exit
        } 2>/dev/null
        {
            grep -Ev "^#|^$" ./blacklists | tr -d "\r" | grep -o "${name} " >/dev/null 2>&1 || {
                echo -e "| Error: \033[1;31mit appears like the list ${name} is not a valid reference.\033[0;40m Typo?
+---------------------------------------------------------------+"
                exit
            } 2>/dev/null
        }
        statusa=$(cat /tmp/p2partisan."${name}".LOAD 2>/dev/null || echo 5)
        statusb=$(cat /tmp/p2partisan."${name}".bro.LOAD 2>/dev/null || echo 5)
        statusap=$(ps w | grep "${name}" | grep -v grep | wc -l)
        statusbp=$(ps w | grep "${name}".bro | grep -v grep | wc -l)
        statusaa=$(ipset -L "${name}" 2>/dev/null | head -8 | tail -1 | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).*" >/dev/null && echo 1 || echo 0)
        statusbb=$(ipset -L "${name}".bro 2>/dev/null | head -8 | tail -1 | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).*" >/dev/null && echo 1 || echo 0)
        statusaaa=$(ipset -T "${name}" ${sDNS} 2>/dev/null && echo 1 || echo 0)
        statusbbb=$(ipset -T "${name}".bro ${sDNS} 2>/dev/null && echo 1 || echo 0)
        sizeb=$(ipset -L "${name}" 2>/dev/null | head -5 | tail -1 | awk '{print $4}' || echo 0)
        sizebb=$(ipset -L "${name}".bro 2>/dev/null | head -5 | tail -1 | awk '{print $4}' || echo 0)
        sizem=$((sizeb / 1024))
        sizemm=$((sizebb / 1024))
        age=$([ -e ./cidr/"${name}".cidr ] && echo $(($(date +%s) - $(date -r ./cidr/"${name}".cidr +%s))) || echo 0)
        if [[ $statusaaa -eq 0 ]]; then
            if [[ $statusaa -eq 1 ]]; then
                if [[ $statusa -gt 2 ]]; then
                    a="\033[1;33mPartially loaded\033[0;40m"
                elif [[ $statusa -le 2 ]]; then
                    a="\033[1;35mLoading\033[0;40m"
                fi
            else
                if [[ $statusap -eq 1 ]]; then
                    a="\033[1;36mQueued\033[0;40m"
                else
                    a="\033[1;31mEmpty\033[0;40m"
                fi
            fi
        elif [[ $statusaaa -eq 1 ]]; then
            a="\033[1;32mFully loaded\033[0;40m"
        fi

        if [[ $statusbbb -eq 0 ]]; then
            if [[ $statusbb -eq 1 ]]; then
                if [[ $statusb -gt 2 ]]; then
                    b="\033[1;37mPartially loaded\033[0;40m"
                elif [[ $statusb -le 2 ]]; then
                    b="\033[1;35mLoading\033[0;40m"
                fi
            else
                if [[ $statusbp -eq 1 ]]; then
                    b="\033[1;36mQueued\033[0;40m"
                else
                    b="\033[1;37mEmpty\033[0;40m"
                fi
            fi
        elif [[ $statusbbb -eq 1 ]]; then
            b="\033[1;37mFully loaded\033[0;40m"
        fi

        if [ -f ./cidr/"${name}".cidr ]; then
            cat ./cidr/"${name}".cidr 2>/dev/null | cut -d" " -f3 | grep -E "^${sDNS}$" >/dev/null && c="\033[1;37mFully loaded\033[0;40m" || c="\033[1;37mPartially loaded\033[0;40m"
        else
            c="\033[1;37mEmpty\033[0;40m"
        fi

        d=$((age / 86400))
        h=$(((age / 3600) % 24))
        m=$(((age / 60) % 60))
        s=$((age % 60))
        age=$(printf "$d - %02d:%02d:%02d\n" $h $m $s)
        ipta=$(grep -c "${name}" ./iptables-add)
        iptb=$(iptables -L | grep -c "${name}")
        if [ "$((ipta + iptb))" -eq 4 ]; then
            d="\033[1;32mFully loaded\033[0;40m"
        elif [ "$((ipta + iptb))" -eq 0 ]; then
            d="\033[1;37mEmpty\033[0;40m"
        else
            "\033[1;33mPartially loaded\033[0;40m"
        fi
        echo -e "| Primary lists and iptables are used for filtering, they are both
| expected to be Fully Loaded while P2Partisan operates.
| Secondary lists are used for updates only, so empty when unused
| cidr file are created after a list update and allow quick startup
+---------------------------------------------------------------+
|		   Name: ${name}
|			URL: $(grep -Ev "^#|^$" ./blacklists | tr -d "\r" | grep "${name}" | awk '{print $2}')
+---------------------------------------------------------------+
|  ipset primary: $a
|		  items: $(ipset -L "${name}" 2>/dev/null | tail -n +8 | wc -l || echo 0)
|	size in RAM: $sizem KB
+---------------------------------------------------------------+
| ipset seconday: $b
|		  items: $(ipset -L "${name}".bro 2>/dev/null | tail -n +8 | wc -l || echo 0)
|	size in RAM: $sizemm KB
+---------------------------------------------------------------+
|	  cidr file: $c
|		  items: $(cat ./cidr/"${name}".cidr 2>/dev/null | tail -n +2 | wc -l || echo 0)
|   size on disk: $(ls -lh ./cidr/"${name}".cidr 2>/dev/null | awk '{print $5}' || echo 0)
|   Last updated: $(date -r ./cidr/"${name}".cidr '+%H:%M:%S %d/%b/%y' 2>/dev/null) | \033[1;37m$age\033[0;40m ago
+---------------------------------------------------------------+
|	   iptables: $d
$(grep "${name}" ./iptables-add)
$(iptables -L | grep "${name}")
+---------------------------------------------------------------+\033[0;39m
"

        exit
    fi

    counter=0
    running3=$(iptables -L | grep -v Chain | grep -c 'P2PARTISAN-IN\|P2PARTISAN-OUT' 2>/dev/null)
    running4=$([ -f ${pidfile} ] && echo 1 || echo 0)
    running7=$(tail -200 "$logfile" | grep Dropped | tail -1 | awk '{printf "| %s %s %s ",$1,$2,$3;for (i=4;i<=NF;i++) if ($i~/(IN|OUT|SRC|DST|PROTO|SPT|DPT)=/) printf "%s ",$i;print ""}' | sed -e 's/PROTO=//g' -e 's/IN=/I=/g' -e 's/OUT=/O=/g' -e 's/SPT=/S=/g' -e 's/DPT=/D=/g' -e 's/SRC=/S=/g' -e 's/DST=/D=/g')
    running7a=$(tail -200 "$logfile" | grep Rejected | tail -1 | awk '{printf "| %s %s %s ",$1,$2,$3;for (i=4;i<=NF;i++) if ($i~/(IN|OUT|SRC|DST|PROTO|SPT|DPT)=/) printf "%s ",$i;print ""}' | sed -e 's/PROTO=//g' -e 's/IN=/I=/g' -e 's/OUT=/O=/g' -e 's/SPT=/S=/g' -e 's/DPT=/D=/g' -e 's/SRC=/S=/g' -e 's/DST=/D=/g')
    running9=$(nvram get script_fire | grep "P2Partisan-tutor" >/dev/null && echo "\033[1;32mYes\033[0;40m" || echo "\033[1;31mNo\033[0;40m")
    logwin=$((now - 86400))
    tail -1500 "$logfile" | grep -i "P2Partisan tutor had" >/tmp/tutor.tmp
    [ -f /tmp/tutor.temp ] && {
        while read -r line; do
            logtime=$(echo "${line}" | awk '{print $3}')
            if [[ $(date -d"$logtime" +%s) -gt $logwin ]]; then
                echo "${line}" >>/tmp/tutor.temp
            fi
        done </tmp/tutor.tmp
    }
    runningB=$(wc -l /tmp/tutor.temp 2>/dev/null | awk '{print $1}')
    [ -f /tmp/tutor.tmp ] && rm /tmp/tutor.tmp
    [ -f /tmp/tutor.temp ] && rm /tmp/tutor.temp || runningB=0
    runningD=$([ -f ./runtime ] && cat ./runtime)
    runningF=$(iptables -L P2PARTISAN-DROP-IN 2>/dev/null | grep -c DEBUG)
    from=$([ -f ./iptables-add ] && head -1 ./iptables-add 2>/dev/null | awk '{print $2}' || echo "$now")
    runtime=$((now - from))
    d=$((runtime / 86400))
    d=$(printf "%02d" "${d}")
    h=$(((runtime / 3600) % 24))
    h=$(printf "%02d" "${h}")
    m=$(((runtime / 60) % 60))
    m=$(printf "%02d" "${m}")
    s=$((runtime % 60))
    s=$(printf "%02d" "${s}")
    runtime="${d}d - ${h}:${m}:${s}"
    drop_packet_count_in=$(iptables -vL P2PARTISAN-DROP-IN 2>/dev/null | grep " DROP " | awk '{print $1}')
    drop_packet_count_out=$(iptables -vL P2PARTISAN-DROP-OUT 2>/dev/null | grep " REJECT " | awk '{print $1}')
    if [ -e ./iptables-debug-del ]; then
        dfrom=$([ -f ./iptables-debug ] && head -1 ./iptables-debug 2>/dev/null | awk '{print $2}')
        druntime=$((now - dfrom))
        h=$(((druntime / 3600) % 24))
        m=$(((druntime / 60) % 60))
        s=$((druntime % 60))
        druntime=$(printf "%02d:%02d:%02d\n" $h $m $s)
        dendtime=$([ -f ./iptables-debug-del ] && head -2 ./iptables-debug-del | tail -n 1 | awk '{print $2}')
        ttime=$((dendtime / 60))
        ttime=$((dfrom + dendtime))
        leftime=$((ttime - now))
        m=$(((leftime / 60) % 60))
        s=$((leftime % 60))
        leftime=$(printf "%02d:%02d:%02d\n" $h $m $s)
        zzztime=$((dendtime / 60))
    fi

    if [[ $running3 -eq 0 ]] && [[ $running4 -eq 0 ]]; then
        running8="\033[1;31mNo\033[0;40m"
    elif [[ $running3 -eq 0 ]] && [[ $running4 -eq 1 ]]; then
        running8="\033[1;35mLoading...\033[0;40m"
    elif [[ $running3 -lt 4 ]] && [[ $running4 -eq 0 ]]; then
        running8="\033[1;31mNot quite... try to run \"p2partisan.sh update\"\033[0;40m"
    elif [[ $running3 -eq 4 ]] && [[ $running4 -eq 1 ]]; then
        running8="\033[1;32mYes\033[0;40m"
    fi

    if [[ $runningF -eq 1 ]]; then
        runningF="\033[1;35mOn\033[0;40m IP \033[1;33m$(iptables -L P2PARTISAN-DROP-IN 2>/dev/null | grep DEBUG | awk '{print $5}') \033[1;33m$f\033[0;40mrunning for \033[1;33m$druntime\033[0;40m /\033[1;33m$zzztime\033[0;40m min (\033[1;33m$leftime\033[0;40m left)"
    elif [[ $runningF -gt 1 ]]; then
        runningF="\033[1;35mOn - reverse \033[0;40m(entire LAN except port \033[1;33m$(iptables -L P2PARTISAN-DROP-IN 2>/dev/null | grep DEBUG | head -1 | awk '{print $7}' | cut -f2 -d!)) \033[1;33m$f\033[0;40mrunning for \033[1;33m$druntime\033[0;40m /\033[1;33m$zzztime\033[0;40m min (\033[1;33m$leftime\033[0;40m left)"
    else
        runningF="Off"
    fi

    whiteip=$(ipset -L whitelist 2>/dev/null | grep -c -E "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])")
    whiteextra=$(ipset -L whitelist 2>/dev/null | grep -c -E '(^10\.|(^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.)|^192\.168\.)')

    if [[ $whiteextra == "0" ]]; then
        whiteextra=" "
    else
        whiteextra="/ $whiteextra LAN IP ref defined"
    fi
    blackip=$(ipset -L blacklist-custom 2>/dev/null | grep -c -E "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])")
    greyip=$(ipset -L greylist 2>/dev/null | grep -c -E "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])")

    echo -e "\e[40m
+------------------------- P2Partisan --------------------------+
|            _______ __          __
|           |     __|  |_.---.-.|  |_.--.--.-----.
|           |__     |   _|  _  ||   _|  |  |__ --|
|           |_______|____|___._||____|_____|_____|
|
|    Release version:  \033[1;40m$version\033[0;40m
+---------------------------------------------------------------+
|            Running:  $running8
|              Tutor:  $running9 / \033[1;37m$runningB\033[0;40m problems in the last 24h
|           Debugger:  $runningF
|    Partisan uptime:  \033[1;37m$runtime\033[0;40m
|       Startup time:  \033[1;37m$runningD\033[0;40m seconds
|         Dropped in:  \033[1;37m$drop_packet_count_in\033[0;40m
|       Rejected out:  \033[1;37m$drop_packet_count_out\033[0;40m
+---------------------------------------------------------------+"
    echo -e "|          Black IPs:  \033[1;37m$blackip\033[0;40m"
    echo -e "|           Grey IPs:  \033[1;37m$greyip\033[0;40m"
    echo -e "|          White IPs:  \033[1;37m$whiteip $whiteextra\033[0;40m"
    transmissionenable=$(nvram get bt_enable)
    if [[ -z $transmissionenable ]]; then
        echo "|     TransmissionBT:  Not available"
    elif [[ $transmissionenable -eq 0 ]]; then
        echo "|     TransmissionBT:  Off"
    else
        echo -e "|     TransmissionBT:  \033[1;32mOn\033[0;40m"
        transmissionport=$(nvram get bt_port 2>/dev/null)
        greyports_tcp="${greyports_tcp},$transmissionport"
        greyports_udp="${greyports_udp},$transmissionport"
    fi
    echo "${greyports_tcp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
        echo -e "|     Grey ports TCP:  \033[1;37m$w\033[0;40m"
    done
    echo "${greyports_udp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
        echo -e "|     Grey ports UDP:  \033[1;37m$w\033[0;40m"
    done
    echo "${whiteports_tcp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
        echo -e "|    White ports TCP:  \033[1;37m$w\033[0;40m"
    done
    echo "${whiteports_udp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
        ColorOff='\\\e[0;40m'
        ColorOn='\\\e[1;37m'
        BWhite='\\\e[100m'
        p1=$(head -70 ./p2partisan.sh | grep -E ^whiteports_udp= | grep -Eo '[,|:|=]67[,|:]|,67$' | wc -l)
        p2=$(head -70 ./p2partisan.sh | grep -E ^whiteports_udp= | grep -Eo '[,|:|=]68[,|:]|,68$' | wc -l)
        if [[ $p1 -eq 0 ]]; then
            w=$(echo -e "$w" | sed -e "s/^67,/${BWhite}67${ColorOn},/g" | sed -e "s/,67,/,${BWhite}67${ColorOff}${ColorOn},/g" | sed -e "s/,67$/,${BWhite}67/g")
        fi
        if [[ $p2 -eq 0 ]]; then
            w=$(echo -e "$w" | sed -e "s/^68,/${BWhite}68${ColorOn},/g" | sed -e "s/,68,/,${BWhite}68${ColorOff}${ColorOn},/g" | sed -e "s/,68$/,${BWhite}68/g")
        fi
        echo -e "|    White ports UDP:  \033[1;37m$w\033[0;40m"
    done
    grep -Ev "^#|^$" ./blacklists | tr -d "\r" |
        (
            while read -r line; do
                counter=$(expr ${counter} + 1)
                counter=$(printf "%02d" "${counter}")
                name=$(echo "${line}" | awk '{print $1}')
                statusa=$(cat /tmp/p2partisan."${name}".LOAD 2>/dev/null || echo 5)
                statusb=$(cat /tmp/p2partisan."${name}".bro.LOAD 2>/dev/null || echo 5)
                statusap=$(ps w | grep "${name}" | grep -v grep | wc -l)
                statusbp=$(ps w | grep "${name}".bro | grep -v grep | wc -l)
                statusaa=$(ipset -L "${name}" 2>/dev/null | head -8 | tail -1 | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).*" >/dev/null && echo 1 || echo 0)
                statusbb=$(ipset -L "${name}".bro 2>/dev/null | head -8 | tail -1 | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).*" >/dev/null && echo 1 || echo 0)
                statusaaa=$(ipset -T "${name}" ${sDNS} 2>/dev/null && echo 1 || echo 0)
                statusbbb=$(ipset -T "${name}".bro ${sDNS} 2>/dev/null && echo 1 || echo 0)
                sizeb=$(ipset -L "${name}" 2>/dev/null | head -5 | tail -1 | awk '{print $4}' || echo 0)
                sizebb=$(ipset -L "${name}".bro 2>/dev/null | head -5 | tail -1 | awk '{print $4}' || echo 0)
                sizem=$((sizeb / 1024))
                sizem=$(printf "%04s" $sizem)
                sizemm=$((sizebb / 1024))
                lin=$(iptables -L P2PARTISAN-LISTS-IN 2>/dev/null | grep -c "${name}")
                lout=$(iptables -L P2PARTISAN-LISTS-OUT 2>/dev/null | grep -c "${name}")
                ipt=$((lin + lout))
                if [ $ipt -eq 2 ]; then
                    i="\033[1;32mo\033[0;40m"
                elif [ $ipt -eq 1 ]; then
                    i="\033[1;33mp\033[0;40m"
                else
                    i="\033[1;31me\033[0;40m"
                fi

                if [[ $statusaaa -eq 0 ]]; then
                    if [[ $statusaa -eq 1 ]]; then
                        if [[ $statusa -gt 2 ]]; then
                            a="\033[1;33mp\033[0;40m"
                        elif [[ $statusa -le 2 ]]; then
                            a="\033[1;35ml\033[0;40m"
                        fi
                    else
                        if [[ $statusap -eq 1 ]]; then
                            a="\033[1;36mq\033[0;40m"
                        else
                            a="\033[1;31me\033[0;40m"
                        fi
                    fi
                elif [[ $statusaaa -eq 1 ]]; then
                    a="\033[1;32mo\033[0;40m"
                fi

                if [[ $statusbbb -eq 0 ]]; then
                    if [[ $statusbb -eq 1 ]]; then
                        if [[ $statusb -gt 2 ]]; then
                            b="\033[1;37mp\033[0;40m"
                        elif [[ $statusb -le 2 ]]; then
                            b="\033[1;35ml\033[0;40m"
                        fi
                    else
                        if [[ $statusbp -eq 1 ]]; then
                            b="\033[1;36mq\033[0;40m"
                        else
                            b="\033[1;37me\033[0;40m"
                        fi
                    fi
                elif [[ $statusbbb -eq 1 ]]; then
                    b="\033[1;37mo\033[0;40m"
                fi

                if [ -f ./cidr/"${name}".cidr ]; then
                    cat ./cidr/"${name}".cidr | cut -d" " -f3 | grep -E "^${sDNS}$" >/dev/null &&
                        {
                            age=$([ -e ./cidr/"${name}".cidr ] && echo $(($(date +%s) - $(date -r ./cidr/"${name}".cidr +%s))) || echo 0)
                            d=$((age / 86400))
                            if [[ $d -eq 7 ]]; then
                                c="\033[1;33mo\033[0;40m"
                            elif [[ $d -ge 8 ]]; then
                                c="\033[1;31mo\033[0;40m"
                            else
                                c="\033[1;37mo\033[0;40m"
                            fi
                        } || c="\033[1;37mp\033[0;40m"
                else
                    c="\033[1;37me\033[0;40m"
                fi

                echo -e "|       Blacklist_${counter}:  [$a] [$b] [$c] [$i] - $sizem KB - \033[1;37m${name}\033[0;40m"

                sizeram=$((sizeram + sizeb + sizebb))
            done
            sizeram=$((sizeram / 1024))
            echo "|                       ^   ^   ^   ^"
            echo -e "|            Maxload: \033[1;37m$maxconcurrentlistload\033[0;40m - \e[1;37;100mpri sec cid ipt\033[0;40m - [\033[1;37me\033[0;40m]mpty [\033[1;37ml\033[0;40m]oading l[\033[1;37mo\033[0;40m]aded [\033[1;37mp\033[0;40m]artial [\033[1;37mq\033[0;40m]ueued"
            echo -e "|       Consumed RAM:  \033[1;37m$sizeram\033[0;40m KB"
        )

    echo -e "+----------------------- Logs max($maxloghour/hour) ----------------------+
$running7
$running7a
+---------------------------------------------------------------+\033[0;39m"
}

function pdetective() {
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|         __         __               __   __
|     .--|  |.-----.|  |_.-----.----.|  |_|__|.--.--.-----.
|     |  _  ||  -__||   _|  -__|  __||   _|  ||  |  |  -__|
|     |_____||_____||____|_____|____||____|__| \___/|_____| BETA
|
+---------------------------------------------------------------+
| After an investigation it appears that the following socket/s
| should be considered a greyports candidates. Consider re-run the
| command multiple times to reduce the number of false positive. Once
| identified the port/s can be added under greyports_tcp & greyports_udp.
+---------------------------------------------------------------+"
    cat /proc/net/ip_conntrack | awk '{for (i=1;i<=NF;i++) if ($i~/(src|dst|sport|dport)=/) printf "%s ",$i;print "\n"}' | grep -vE '^$' | sed s/\ src=/'\n'/ | awk '{print $1" "$3" "$2" "$4}' | sed s/\ dst=/'\n'/ | sed s/sport=// | sed s/dport=// | grep -E '(^10\.|(^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.)|^192\.168\.)' | grep -v "$(nvram get lan_ipaddr)$" | grep -v "$(nvram get lan1_ipaddr)$" | awk '/[0-9]/ {cnt[$1" "$2]++}END{for(k in cnt) print cnt[k],k}' | sort -nr | while read -r socket; do echo "$socket" | if [ "$(cut -f1 -d" ")" -gt $greyline ]; then echo "$socket" | awk '{print "| "$2" "$3" - "$1" Sessions"}'; fi; done
    echo -e "+---------------------------------------------------------------+\033[0;39m"
}

function ptutor() {
    h=$(date +%H)
    pwhitelist
    pgreylist
    pblacklistcustom
    running3=$(iptables -L | grep -v Chain | grep -c 'P2PARTISAN-IN\|P2PARTISAN-OUT' 2>/dev/null)
    running4=$([ -f ${pidfile} ] && echo 1 || echo 0)
    runningE=$(iptables -L wanin | grep -c P2PARTISAN-IN 2>/dev/null)
    schfrom=$(echo $scheduleupdates | cut -d, -f1)
    schto=$(echo $scheduleupdates | cut -d, -f2)

    grep -Ev "^#|^$" ./blacklists | tr -d "\r" |
        (
            while read -r line; do
                name=$(echo "${line}" | awk '{print $1}')
                statusbbb=$(ipset -T "${name}".bro ${sDNS} 2>/dev/null && echo 1 || echo 0)
                iptables -L P2PARTISAN-LISTS-IN | grep "${name}" >/dev/null || {
                    plog "P2Partisan tutor had to reinstall the iptables due to: P2PARTISAN-LIST-IN ${name} instruction missing"
                    ./iptables-del
                    ./iptables-add
                    exit
                }
                iptables -L P2PARTISAN-LISTS-OUT | grep "${name}" >/dev/null || {
                    plog "P2Partisan tutor had to reinstall the iptables due to: P2PARTISAN-LIST-OUT ${name} instruction missing"
                    ./iptables-del
                    ./iptables-add
                    exit
                }
                age=$(($(date +%s) - $(date -r ./cidr/"${name}".cidr +%s)))
                if [[ $age -gt "604800" ]] && [[ $h -ge $schfrom ]] && [[ $h -le $schto ]]; then
                    plog "P2Partisan is updating list ${name}"
                    pforcestop "${name}"
                    exit
                fi
                if [[ $age -gt "300" ]] && [[ $statusbbb -eq 1 ]]; then
                    plog "P2Partisan is clearing the ${name} secondary list"
                    ipset -F "${name}".bro
                fi
            done
        )
    if [[ $runningE -gt 1 ]]; then
        pforcestop
        plog "P2Partisan tutor had to restart due to: iptables redundant rules found"
        pstart
    elif [[ $running3 -eq 4 ]] && [[ $running4 -eq 0 ]]; then
        plog "P2Partisan tutor had to restart due to: pid file missing"
        pforcestop
        pstart
        # elif [[ $running3 -eq 0 ]] && [[ $running4 -eq 1 ]]; then
        # plog "P2Partisan tutor had to restart due to: iptables instructions missing"
        # pforcestop
        # pstart
    elif [[ $running3 -ne 4 ]] && [[ $running4 -eq 1 ]]; then
        plog "P2Partisan might be loading, I'll wait 10 seconds..."
        sleep 10
        if [[ $running3 -ne 4 ]] && [[ $running4 -eq 1 ]]; then
            plog "P2Partisan tutor had to restart due to iptables instruction missing"
            pforcestop
            pstart
        fi
    else
        echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                _______         __
|               |_     _|.--.--.|  |_.-----.----.
|                 |   |  |  |  ||   _|  _  |   _|
|                 |___|  |_____||____|_____|__|
|
+---------------------------------------------------------------+
| P2Partisan up and running. The tutor is happy
+---------------------------------------------------------------+\033[0;39m"
    fi
}

function ptutorset() {
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                _______         __
|               |_     _|.--.--.|  |_.-----.----.
|                 |   |  |  |  ||   _|  _  |   _|
|                 |___|  |_____||____|_____|__|
|
+-------------------------- Scheduler --------------------------+"
    cru d P2Partisan-tutor
    p=$(nvram get sch_c1_cmd | grep -c "${P2Partisandir}/p2partisan.sh tutor")
    if [[ $p -eq 0 ]]; then
        t=$(nvram get sch_c1_cmd)
        t=$(printf "%s\n%s\n" "$t" "bash ${P2Partisandir}/p2partisan.sh tutor")
        nvram set "sch_c1_cmd=$t"
    fi

    plog "P2Partisan tutor is ON"
    echo -e "+---------------------------------------------------------------+\033[0;39m"
    nvram commit
}

function ptutorunset() {
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                _______         __
|               |_     _|.--.--.|  |_.-----.----.
|                 |   |  |  |  ||   _|  _  |   _|
|                 |___|  |_____||____|_____|__|
|
+-------------------------- Scheduler --------------------------+"
    cru d P2Partisan-tutor
    p=$(nvram get sch_c1_cmd | grep -c "${P2Partisandir}/p2partisan.sh tutor")
    if [[ $p -eq 1 ]]; then
        t=$(nvram get sch_c1_cmd)
        t=$(printf "%s\n%s\n" "$t" "bash ${P2Partisandir}/p2partisan.sh tutor" | grep -v "p2partisan.sh tutor")
        nvram set "sch_c1_cmd=$t"
    fi
    plog "P2Partisan tutor is OFF"
    echo -e "+---------------------------------------------------------------+\033[0;39m"
    nvram commit
}

function ptest() {
    checklist="blacklist-custom greylist whitelist $(grep -Ev "^#|^$" ./blacklists | tr -d "\r" | awk '{print $1}')"
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                  _______               __
|                 |_     _|.-----.-----.|  |_
|                   |   |  |  -__|__ --||   _|
|                   |___|  |_____|_____||____|
|
+----------- Lists are sorted in order of precedence -----------+"
    if [[ -z $1 ]]; then
        echo "+---------------------------------------------------------------+
| Invalid input. Please specify a valid IP address.
+---------------------------------------------------------------+"
    else
        test=$1
        echo "$test" | grep -E "(^[2][5][0-5].|^[2][0-4][0-9].|^[1][0-9][0-9].|^[0-9][0-9].|^[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9])$" >/dev/null 2>&1 && test=1 || test=0
        if [[ $test -eq 1 ]]; then
            echo "$checklist" | tr " " "\n" |
                (
                    while read -r LIST; do
                        ipset -T "$LIST" "$1" >/dev/null 2>&1 && if [ "$LIST" == "whitelist" ]; then echo -e "| \033[1;32m$1 found in		$LIST\033[0;40m"; else echo -e "| \033[1;31m$1 found in		$LIST\033[0;40m"; fi || echo -e "| $1 not found in	$LIST"
                    done
                )
            echo -e "+---------------------------------------------------------------+
|		in case of multiple match the first prevails
+---------------------------------------------------------------+\033[0;39m"
        elif [[ $test -eq 0 ]]; then
            echo -e "| Invalid input. Please specify a valid IP address.
+---------------------------------------------------------------+\033[0;39m"
        fi
    fi
}

function pdebug() {
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                _____         __
|               |     \.-----.|  |--.--.--.-----.
|               |  --  |  -__||  _  |  |  |  _  |
|               |_____/|_____||_____|_____|___  |
|                                         |_____|
|
+--------------------------- Guide -----------------------------+
| Debug allows to fully log the P2Partisan interventions given a LAN IP
| Maximum 1 debug at the time / Debug automatically times out or can be forced off manually
+---------------------------------------------------------------+
| p2partisan.sh debug <LAN IP> <minutes>	Syntax
| p2partisan.sh debug					   Displays debug status and this help text
| p2partisan.sh debug 192.168.0.3 <1-120>   Enables debug for the given LAN IP for N min (15 default)
| p2partisan.sh debug 192.168.0.3 9		 Enables debug for the given LAN IP for 9 min
| p2partisan.sh debug reverse <1-120>	   Enables debug for all the LAN IPs excluding greyports_tcp/udp
| p2partisan.sh debug off				   Disable debug without waiting for the timer to timeout
| p2partisan.sh debug-display <in|out>	  Display logs Syntax
| p2partisan.sh debug-display			   Displays in&out debug logs + guide
| p2partisan.sh debug-display out		   Same as above but displays outbound records only
+-------------------------- Activity ---------------------------+"
    echo "$1" | grep -Eo "([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9])" >/dev/null 2>&1 && q=0 || q=1
    echo "$1" | grep "reverse" >/dev/null 2>&1 && q=2
    echo "$1" | grep "off" >/dev/null 2>&1 && off=1 || off=0

    if [ -e ./iptables-debug-del ]; then
        dfrom=$(head -1 ./iptables-debug 2>/dev/null | awk '{print $2}')
        druntime=$((now - dfrom))
        h=$(((druntime / 3600) % 24))
        m=$(((druntime / 60) % 60))
        s=$((druntime % 60))
        druntime=$(printf "%02d:%02d:%02d\n" $h $m $s)
        dendtime=$(head -2 ./iptables-debug-del | tail -n 1 | awk '{print $2}')
        ttime=$((dendtime / 60))
        ttime=$((dfrom + dendtime))
        leftime=$((ttime - now))
        m=$(((leftime / 60) % 60))
        s=$((leftime % 60))
        leftime=$(printf "%02d:%02d:%02d\n" $h $m $s)
        zzztime=$((dendtime / 60))
    fi

    if [[ $off -eq 1 ]]; then
        f=$(iptables -L P2PARTISAN-DROP-IN | grep DEBUG)
        fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
        if [[ $fc -ge 1 ]]; then
            kill "$(ps | grep -E "sleep $dendtime$" | awk '{print $1}')" >/dev/null
            plog "All DEBUG activities have stopped"
            {
                while iptables -L P2PARTISAN-DROP-IN | grep DEBUG; do
                    iptables -D P2PARTISAN-DROP-IN 1
                done
                while iptables -L P2PARTISAN-DROP-OUT | grep DEBUG; do
                    iptables -D P2PARTISAN-DROP-OUT 1
                done
            } >/dev/null 2>&1
            echo -e "| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show debug information, if any.
+---------------------------------------------------------------+\033[0;39m"
            exit
        else
            echo -e "| Debug is currently off and not collecting any information.
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show existing debug information, if any.
+---------------------------------------------------------------+\033[0;39m"
            exit
        fi
    fi

    if [[ -z $1 ]]; then
        f=$(iptables -L P2PARTISAN-DROP-IN | grep DEBUG | awk '{print $5}' | head -1)
        fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
        if [[ $fc -gt 1 ]]; then
            echo -e "| P2partisan is currently debugging IP \033[1;33m$f\033[0;40m for \033[1;33m$druntime\033[0;40m /\033[1;33m$zzztime\033[0;40m min (\033[1;33m$leftime\033[0;40m left)
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show debug information
+---------------------------------------------------------------+\033[0;39m"
            exit
        elif [[ $fc -eq 0 ]]; then
            echo -e "| Debug is currently off and not collecting any information.
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show existing debug information, if any.
+---------------------------------------------------------------+\033[0;39m"
            exit
        fi
    elif [[ $q -eq 1 ]]; then
        echo -e "| The input \033[1;31m$1\033[0;40m doesn't appear to be a valid IP
+---------------------------------------------------------------+\033[0;39m"
        exit
    fi

    f=$(iptables -L P2PARTISAN-DROP-IN | grep DEBUG | awk '{print $5}' | head -1)
    fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
    if [[ $fc -gt 1 ]]; then
        echo -e "| P2partisan is currently debugging IP \033[1;33m$f\033[0;40m for \033[1;33m$druntime\033[0;40m /\033[1;33m$zzztime\033[0;40m min (\033[1;33m$leftime\033[0;40m left)
| NOTE: Only one debug at the time is possible! Command ignored.
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show the debug information
+---------------------------------------------------------------+\033[0;39m"
        exit
    fi

    if [[ -z $2 ]]; then
        minutes=15
        time=900
    elif [[ $2 -gt 120 ]] || [[ $2 -eq 0 ]]; then
        echo -e "| Please specify an acceptable time: 1 to 60 (min). If omitted 15 will be used
| Debug NOT enabled. Exiting...
+---------------------------------------------------------------+\033[0;39m"
        exit
    else
        minutes=$2
        time=$(($2 * 60))
    fi
    if [[ $q -eq 2 ]]; then
        if [[ -z ${greyports_tcp} ]] || [[ -z ${greyports_udp} ]]; then
            echo -e "| It appears like you have no greyport set. This function due to the potential amount
| of logging involved requires the both greyports_tcp and greyports_udp to be set
| if unsure on what ports to use, try to run \033[1;33m./p2partisan.sh detective\033[0;40m
+---------------------------------------------------------------+"
            exit
        fi
        echo "# $now
iptables -I P2PARTISAN-DROP-IN 1 -p tcp --sport ${greyports_tcp} -j DROP
iptables -I P2PARTISAN-DROP-IN 1 -p udp --sport ${greyports_udp} -j DROP
iptables -I P2PARTISAN-DROP-IN 1 -p tcp --dport ${greyports_tcp} -j DROP
iptables -I P2PARTISAN-DROP-IN 1 -p udp --dport ${greyports_udp} -j DROP
iptables -I P2PARTISAN-DROP-OUT 1 -p tcp --sport ${greyports_tcp} -j DROP
iptables -I P2PARTISAN-DROP-OUT 1 -p udp --sport ${greyports_udp} -j DROP
iptables -I P2PARTISAN-DROP-OUT 1 -p tcp --dport ${greyports_tcp} -j DROP
iptables -I P2PARTISAN-DROP-OUT 1 -p udp --dport ${greyports_udp} -j DROP
iptables -I P2PARTISAN-DROP-IN 5 -j LOG --log-prefix 'P2Partisan-DEBUG-IN->> ' --log-level 1
iptables -I P2PARTISAN-DROP-OUT 5 -j LOG --log-prefix 'P2Partisan-DEBUG-OUT->> ' --log-level 1" >./iptables-debug
        chmod 777 ./iptables-debug >/dev/null 2>&1
        plog "Reverse Debug started for for $minutes minute"
        ./iptables-debug 1>/dev/null &
        echo -e "| Enabled full debug logging for all the LAN IPs for \033[1;32m$minutes\033[0;40m minutes
| This excludes the greyports_tcp ${greyports_tcp} and greyports_udp ${greyports_udp}
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show the debug information
+---------------------------------------------------------------+"

        echo "# $now
sleep $time
iptables -D P2PARTISAN-DROP-IN -p tcp -m tcp --sport ${greyports_tcp} -j DROP
iptables -D P2PARTISAN-DROP-IN -p udp -m udp --sport ${greyports_udp} -j DROP
iptables -D P2PARTISAN-DROP-IN -p tcp -m tcp --dport ${greyports_tcp} -j DROP
iptables -D P2PARTISAN-DROP-IN -p udp -m udp --dport ${greyports_udp} -j DROP
iptables -D P2PARTISAN-DROP-OUT -p tcp -m tcp --sport ${greyports_tcp} -j DROP
iptables -D P2PARTISAN-DROP-OUT -p udp -m udp --sport ${greyports_udp} -j DROP
iptables -D P2PARTISAN-DROP-OUT -p tcp -m tcp --dport ${greyports_tcp} -j DROP
iptables -D P2PARTISAN-DROP-OUT -p udp -m udp --dport ${greyports_udp} -j DROP
iptables -D P2PARTISAN-DROP-IN -j LOG --log-prefix 'P2Partisan-DEBUG-IN->> ' --log-level 1
iptables -D P2PARTISAN-DROP-OUT -j LOG --log-prefix 'P2Partisan-DEBUG-OUT->> ' --log-level 1" >./iptables-debug-del
        chmod 777 ./iptables-debug-del 2>/dev/null
        ./iptables-debug-del 1>/dev/null &
    else
        echo "# $now
iptables -I P2PARTISAN-DROP-IN 1 -d $1 -j LOG --log-prefix \"P2Partisan-DEBUG-IN->> \" --log-level 1 > /dev/null 2>&1
iptables -I P2PARTISAN-DROP-OUT 1 -s $1 -j LOG --log-prefix \"P2Partisan-DEBUG-OUT->> \" --log-level 1 > /dev/null 2>&1" >./iptables-debug
        chmod 777 ./iptables-debug >/dev/null 2>&1
        plog "Debug started for IP $1 for $minutes minute"
        ./iptables-debug 1>/dev/null &
        echo -e "| Enabled full debug logging for LAN IP \033[1;32m$1\033[0;40m for \033[1;32m$minutes\033[0;40m minutes
| Use \033[1;33m./p2partisan.sh debug-display\033[0;40m to show the debug information
+---------------------------------------------------------------+"

        echo "# $now
sleep $time
iptables -D P2PARTISAN-DROP-IN -d $1 -j LOG --log-prefix \"P2Partisan-DEBUG-IN->> \" --log-level 1  > /dev/null 2>&1
iptables -D P2PARTISAN-DROP-OUT -s $1 -j LOG --log-prefix \"P2Partisan-DEBUG-OUT->> \" --log-level 1 > /dev/null 2>&1" >./iptables-debug-del
        chmod 777 ./iptables-debug-del 2>/dev/null
        ./iptables-debug-del 1>/dev/null &
    fi
}

function pdebugdisplay() {
    echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
_____         __                          __ __               __
|     \.-----.|  |--.--.--.-----.______.--|  |__|.-----.-----.|  |.---.-.--.--.
|  --  |  -__||  _  |  |  |  _  |______|  _  |  ||__ --|  _  ||  ||  _  |  |  |
|_____/|_____||_____|_____|___  |      |_____|__||_____|   __||__||___._|___  |
                         |_____|                      |__|             |_____|

+---------------------------------------------------------------+
| p2partisan.sh debug-display			   Displays in & outbound debug logs
| p2partisan.sh debug-display in			Displays inbound debug logs only
| p2partisan.sh debug-display out		   Displays outbound debug logs only
+-------------------------- Drop Logs --------------------------+"

    dfrom=$(head -1 ./iptables-debug 2>/dev/null | awk '{print $2}')
    druntime=$((now - dfrom))
    h=$(((druntime / 3600) % 24))
    m=$(((druntime / 60) % 60))
    s=$((druntime % 60))
    druntime=$(printf "%02d:%02d:%02d\n" $h $m $s)
    dendtime=$(head -2 ./iptables-debug-del | tail -n 1 | awk '{print $2}')
    ttime=$((dendtime / 60))
    ttime=$((dfrom + dendtime))
    leftime=$((ttime - now))
    m=$(((leftime / 60) % 60))
    s=$((leftime % 60))
    leftime=$(printf "%02d:%02d:%02d\n" $h $m $s)
    zzztime=$((dendtime / 60))

    c=0
    rm ./debug.rev >/dev/null 2>&1
    tail -800 "$logfile" | grep -i "P2Partisan" >./debug.log
    cat ./debug.log | sed '1!G;h;$!d' |
        (
            while read -r line; do
                testo=$(echo "${line}" | grep -c "Debug started for IP")
                if [[ $testo -ge 1 ]]; then
                    echo "${line}" >>./debug.rev
                    cat ./debug.rev | sed '1!G;h;$!d' >./debug.log
                    rm ./debug.rev >/dev/null 2>&1
                    exit
                else
                    echo "${line}" >>./debug.rev
                fi
            done
        )

    if [[ -z $1 ]]; then
        echo -e "\033[48;5;89m+----------------------- INPUT & OUTPUT ------------------------+\033[40m"
        head -1 ./debug.log
        while read -r line; do
            [ $((c % 2)) -eq 1 ] && printf "\e[100m"
            printf "%s\033[0m\n" "${line}"
            c=$((c + 1))
        done < <(grep "DEBUG-" ./debug.log | awk '{printf "%s %s %s ",$1,$2,$3;for (i=4;i<=NF;i++) if ($i~/(IN|OUT|SRC|DST|PROTO|SPT|DPT)=/) printf "%s ",$i;print ""}' | sed -e 's/PROTO=//g' -e 's/IN=/I=/g' -e 's/OUT=/O=/g' -e 's/SPT=/S=/g' -e 's/DPT=/D=/g' -e 's/SRC=/S=/g' -e 's/DST=/D=/g')

        fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
        if [[ $fc -ge 1 ]]; then
            echo -e "\e[93mNOTE: debugging is active for $druntime /$zzztime min ($leftime left). Run this command again to update the report\033[0m"
        fi
        echo -e "\033[48;5;89m+----------------------- INPUT & OUTPUT ------------------------+\033[40m"
    elif [[ $1 == "in" ]]; then
        echo -e "\033[48;5;89m+--------------------------- INPUT -----------------------------+\033[40m"
        head -1 ./debug.log
        while read -r line; do
            [ $((c % 2)) -eq 1 ] && printf "\e[100m"
            printf "%s\033[0m\n" "${line}"
            c=$((c + 1))
        done < <(grep "DEBUG-IN" ./debug.log | awk '{printf "%s %s %s ",$1,$2,$3;for (i=4;i<=NF;i++) if ($i~/(IN|OUT|SRC|DST|PROTO|SPT|DPT)=/) printf "%s ",$i;print ""}' | sed -e 's/PROTO=//g' -e 's/IN=/I=/g' -e 's/OUT=/O=/g' -e 's/SPT=/S=/g' -e 's/DPT=/D=/g' -e 's/SRC=/S=/g' -e 's/DST=/D=/g')
        fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
        if [[ $fc -ge 1 ]]; then
            echo -e "\e[93mNOTE: debugging is active for $druntime /$zzztime min ($leftime left). Run this command again to update the report\033[0m"
        fi
        echo -e "\033[48;5;89m+--------------------------- INPUT -----------------------------+\033[40m"
    elif [[ $1 == "out" ]]; then
        echo -e "\033[48;5;89m+--------------------------- OUTPUT ----------------------------+\033[40m"
        head -1 ./debug.log
        grep "DEBUG-OUT" ./debug.log | awk '{printf "%s %s %s ",$1,$2,$3;for (i=4;i<=NF;i++) if ($i~/(IN|OUT|SRC|DST|PROTO|SPT|DPT)=/) printf "%s ",$i;print ""}' | sed -e 's/PROTO=//g' -e 's/IN=/I=/g' -e 's/OUT=/O=/g' -e 's/SPT=/S=/g' -e 's/DPT=/D=/g' -e 's/SRC=/S=/g' -e 's/DST=/D=/g' | while read -r line; do
            [ $((c % 2)) -eq 1 ] && printf "\e[100m"
            printf "%s\033[0m\n" "${line}"
            c=$((c + 1))
        done
        fc=$(iptables -L P2PARTISAN-DROP-IN | grep -c DEBUG)
        if [[ $fc -ge 1 ]]; then
            echo -e "\e[93mNOTE: debugging is active for $druntime /$zzztime min ($leftime left). Run this command again to update the report\033[0m"
        fi
        echo -e "\033[48;5;89m+--------------------------- OUTPUT ----------------------------+\033[40m"
    fi
    echo -e "+---------------------------------------------------------------+\033[0;39m"
}

function pwhitelist() {
    ipset -F whitelist

    # VPN - Tinc hosts are IP whitelisted
    if [ "$(nvram get tinc_wanup)" == "1" ]; then
        for IP in $(nvram get tinc_hosts | grep -Eo '\w*[a-z]\w*(\.\w*[a-z]\w*)+'); do
            echo "$IP" | grep -E "(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])" >/dev/null 2>&1 && nslookup "$IP" ${sDNS} | grep "Address [0-9]*:" | grep -v 127.0.0.1 | grep -v "\:\:" | grep -Eo "([0-9\.]{7,15})" | {
                while read -r IPO; do
                    ipset -A whitelist "${IPO%*/32}" 2>/dev/null
                done
            }
            echo "$IP" | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$" >/dev/null 2>&1 && ipset -A whitelist "$IP" 2>/dev/null
        done
    fi
    #/ VPN - Tinc hosts are IP whitelisted

    [ -f ./whitelist ] && cat ./whitelist | grep -Ev "^#|^$" | tr -d "\r" |
        (
            while read -r IP; do
                q=100
                echo "$IP" | grep -E "(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])" >/dev/null 2>&1 && q=1
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9]-.*)" >/dev/null 2>&1 && q=0
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9])$" >/dev/null 2>&1 && q=2
                echo "$IP" | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$" >/dev/null 2>&1 && q=3
                echo "$IP" | awk '{print $2}' | grep -E '^(http)' >/dev/null 2>&1 && q=4
                if [[ $q -eq 0 ]]; then
                    echo "$IP" | pdeaggregate | {
                        while read -r cidr; do
                            ipset -A whitelist "$cidr" 2>/dev/null
                        done
                    }
                elif [[ $q -eq 1 ]]; then
                    nslookup "$IP" ${sDNS} | grep "Address [0-9]*:" | grep -v 127.0.0.1 | grep -v "\:\:" | grep -Eo "([0-9\.]{7,15})" |
                        while read -r IPO; do
                            ipset -A whitelist "${IPO%*/32}" 2>/dev/null
                        done
                elif [[ $q -eq 2 ]]; then
                    ipset -A whitelist "${IP%*/32}" 2>/dev/null
                elif [[ $q -eq 3 ]]; then
                    ipset -A whitelist "$IP" 2>/dev/null
                elif [[ $q -eq 4 ]]; then
                    # SORT OUT
                    url=$(echo "$IP" | awk '{print $2}')
                    # deaggregate whitelist "$url" 3 &
                fi
            done
        )
}

function pgreylist() {
    ipset -F greylist
    [ -f ./greylist ] && cat ./greylist | grep -Ev "^#|^$" | tr -d "\r" |
        (
            while read -r IP; do
                q=100
                echo "$IP" | grep -E "(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])" >/dev/null 2>&1 && q=1
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9]-.*)" >/dev/null 2>&1 && q=0
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9])$" >/dev/null 2>&1 && q=2
                echo "$IP" | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$" >/dev/null 2>&1 && q=3
                echo "$IP" | awk '{print $2}' | grep -E '^(http)' >/dev/null 2>&1 && q=4
                if [[ $q -eq 0 ]]; then
                    echo "$IP" | pdeaggregate | {
                        while read -r cidr; do
                            ipset -A greylist "$cidr" 2>/dev/null
                        done
                    }
                elif [[ $q -eq 1 ]]; then
                    nslookup "$IP" ${sDNS} | grep "Address [0-9]*:" | grep -v 127.0.0.1 | grep -v "\:\:" | grep -Eo "([0-9\.]{7,15})" |
                        while read -r IPO; do
                            ipset -A greylist "${IPO%*/32}" 2>/dev/null
                        done
                elif [[ $q -eq 2 ]]; then
                    ipset -A greylist "${IP%*/32}" 2>/dev/null
                elif [[ $q -eq 3 ]]; then
                    ipset -A greylist "$IP" 2>/dev/null
                elif [[ $q -eq 4 ]]; then
                    # SORT OUT
                    url=$(echo "$IP" | awk '{print $2}')
                    # deaggregate whitelist "$url" 3 &
                fi
            done
        )
}

function pblacklistcustom() {
    ipset -F blacklist-custom
    [ -f ./blacklist-custom ] && cat ./blacklist-custom | grep -Ev "^#|^$" | tr -d "\r" |
        (
            while read -r IP; do
                q=100
                echo "$IP" | grep -E "(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])" >/dev/null 2>&1 && q=1
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9]-.*)" >/dev/null 2>&1 && q=0
                echo "$IP" | grep -Eo "^([2][5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5].|[2][0-4][0-9].|[1][0-9][0-9].|[0-9][0-9].|[0-9].)([2][0-5][0-5]|[2][0-4][0-9]|[1][0-9][0-9]|[0-9][0-9]|[0-9])$" >/dev/null 2>&1 && q=2
                echo "$IP" | grep -Eo "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$" >/dev/null 2>&1 && q=3
                if [[ $q -eq 0 ]]; then
                    echo "$IP" | pdeaggregate | {
                        while read -r cidr; do
                            ipset -A whitelist "$cidr" 2>/dev/null
                        done
                    }
                elif [[ $q -eq 1 ]]; then
                    nslookup "$IP" ${sDNS} | grep "Address [0-9]*:" | grep -v 127.0.0.1 | grep -v "\:\:" | grep -Eo "([0-9\.]{7,15})" |
                        while read -r IPO; do
                            ipset -A blacklist-custom "${IPO%*/32}" 2>/dev/null
                        done
                elif [[ $q -eq 2 ]]; then
                    ipset -A blacklist-custom "${IP%*/32}" 2>/dev/null
                elif [[ $q -eq 3 ]]; then
                    ipset -A blacklist-custom "$IP" 2>/dev/null
                fi
            done
        )
}

function pstart() {
    running4=$([ -f ${pidfile} ] && echo 1 || echo 0)
    if [[ $running4 -eq 0 ]]; then
        [ -f /tmp/p2partisan.loading ] && echo "P2Partisan is still loading. Exiting..." && exit
        touch /tmp/p2partisan.loading
        pre=$(date +%s)
        echo $$ >${pidfile}

        [ -e iptables-add ] && rm iptables-add
        [ -e iptables-del ] && rm iptables-del
        [ -e ipset-del ] && rm ipset-del

        echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                 _______ __               __
|                |     __|  |_.---.-.----.|  |_
|                |__     |   _|  _  |   _||   _|
|                |_______|____|___._|__|  |____|
|
+---------------------------------------------------------------+
+--------- PREPARATION --------"
        echo "| Loading the ipset modules"
        {
            lsmod | awk '{print $1}' | grep -we "^ip_set" || insmod ip_set
            lsmod | awk '{print $1}' | grep -we "^xt_set" || insmod xt_set
            lsmod | awk '{print $1}' | grep -we "^ip_set_hash_net" || insmod ip_set_hash_net
        } >/dev/null 2>&1
        counter=0
        pos=1
        counter=$(printf "%02d" ${counter})
        echo "+---- CUSTOM IP BLACKLIST -----
| preparing blacklist-custom ..."
        echo -e "| Loading Blacklist_${counter} data ---> \033[1;37m***Custom IP blacklist***\033[0;40m"
        if [ "$(ipset --swap blacklist-custom blacklist-custom 2>&1 | grep 'does not exist')" != "" ]; then
            ipset --create blacklist-custom hash:net hashsize 1024 --resize 5 maxelem 1024000 2>/dev/null
        fi

        pblacklistcustom

        [ -e /tmp/iptables-add.tmp ] && rm /tmp/iptables-add.tmp >/dev/null 2>&1

        echo "+--------- GREYPORTs ----------"
        echo "${greyports_tcp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
            echo -e "| Loading grey TCP ports:  \033[1;37m$w\033[0;40m"
            echo "iptables -A P2PARTISAN-IN -i $wanif -p tcp --match multiport --dports $w -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -o $wanif -p tcp --match multiport --sports $w -g P2PARTISAN-LISTS-OUT" >>/tmp/iptables-add.tmp
        done
        echo "${greyports_udp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
            echo -e "| Loading grey UDP ports:  \033[1;37m$w\033[0;40m"
            echo "iptables -A P2PARTISAN-IN -i $wanif -p udp --match multiport --dports $w -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -o $wanif -p udp --match multiport --sports $w -g P2PARTISAN-LISTS-OUT" >>/tmp/iptables-add.tmp
        done
        # Get transmission port for greylisting if enabled
        transmissionenable=$(nvram get bt_enable)
        if [[ -z $transmissionenable ]]; then
            echo "|  TransmissionBT:  Not available"
        elif [[ $transmissionenable -eq 0 ]]; then
            echo "|  TransmissionBT:  Off"
        else
            echo -e "|  TransmissionBT:  \033[1;32mOn\033[0;40m"
            transmissionport=$(nvram get bt_port 2>/dev/null)
            wanip=$(nvram get wan_ipaddr)
            p3=$(echo "${greyports_tcp}" | grep -Eo "$transmissionport" | wc -l)
            p4=$(echo "${greyports_udp}" | grep -Eo "$transmissionport" | wc -l)
            if [[ $p3 -eq 0 ]]; then
                echo "iptables -A P2PARTISAN-IN -i $wanif -p tcp -d $wanip --dport $transmissionport -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -o $wanif -p tcp -s $wanip --sport $transmissionport -g P2PARTISAN-LISTS-OUT
iptables -A P2PARTISAN-OUT -o $wanif -p tcp -s $wanip --sport 49152:65535 -g P2PARTISAN-LISTS-OUT" >>/tmp/iptables-add.tmp
            fi
            if [[ $p4 -eq 0 ]]; then
                echo "iptables -A P2PARTISAN-IN -i $wanif -p udp -d $wanip --dport $transmissionport -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -o $wanif -p udp -s $wanip --sport $transmissionport -g P2PARTISAN-LISTS-OUT
iptables -A P2PARTISAN-OUT -o $wanif -p udp -s $wanip --sport 49152:65535 -g P2PARTISAN-LISTS-OUT" >>/tmp/iptables-add.tmp
            fi
        fi

        echo "+--------- WHITEPORTs ---------"
        echo "${whiteports_tcp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
            echo -e "| Loading white TCP ports \033[1;37m$w\033[0;40m"
            echo "iptables -A P2PARTISAN-IN -i $wanif -p tcp --match multiport --sports $w -j RETURN
iptables -A P2PARTISAN-IN -i $wanif -p tcp --match multiport --dports $w -j RETURN
iptables -A P2PARTISAN-OUT -o $wanif -p tcp --match multiport --sports $w -j RETURN
iptables -A P2PARTISAN-OUT -o $wanif -p tcp --match multiport --dports $w -j RETURN" >>/tmp/iptables-add.tmp
        done
        echo "${whiteports_udp}" | awk -v RS=',' -F : '{ gsub(/\n$/, "") } NF > 1 { r=(r ? r "," : "") $0; if (r ~ /([^,]*,){6}/) { print r; r=""; } next } { s=(s ? s "," : "") $0; if (s ~ /([^,]*,){14}/) { print s; s=""; } }  END { if (r && s) { p = r "," s; if (p !~ /([^,:]*[:,]){15}/) { print p; r=s="" } } if (r) print r ; if (s) print s }' | while read -r w; do
            echo -e "| Loading white UDP ports \033[1;37m$w\033[0;40m"
            echo "iptables -A P2PARTISAN-IN -i $wanif -p udp --match multiport --sports $w -j RETURN
iptables -A P2PARTISAN-IN -i $wanif -p udp --match multiport --dports $w -j RETURN
iptables -A P2PARTISAN-OUT -o $wanif -p udp --match multiport --sports $w -j RETURN
iptables -A P2PARTISAN-OUT -o $wanif -p udp --match multiport --dports $w -j RETURN" >>/tmp/iptables-add.tmp
        done
        echo "iptables -A P2PARTISAN-IN -j P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -j P2PARTISAN-LISTS-OUT" >>/tmp/iptables-add.tmp

        echo "# $now
iptables -N P2PARTISAN-IN
iptables -N P2PARTISAN-OUT
iptables -N P2PARTISAN-LISTS-IN
iptables -N P2PARTISAN-LISTS-OUT
iptables -N P2PARTISAN-DROP-IN
iptables -N P2PARTISAN-DROP-OUT
iptables -F P2PARTISAN-IN
iptables -F P2PARTISAN-OUT
iptables -F P2PARTISAN-LISTS-IN
iptables -F P2PARTISAN-LISTS-OUT
iptables -F P2PARTISAN-DROP-IN
iptables -F P2PARTISAN-DROP-OUT
iptables -A P2PARTISAN-IN -m set  --match-set blacklist-custom src -j P2PARTISAN-DROP-IN
iptables -A P2PARTISAN-OUT -m set  --match-set blacklist-custom dst -j P2PARTISAN-DROP-OUT" >iptables-add

        #Add winin/wanout for RMerlin compatibility only
        if [ $rm -eq 1 ]; then
            echo "iptables -N wanin
iptables -I FORWARD 1 -i $wanif -j wanin
iptables -N wanout
iptables -I FORWARD 2 -o $wanif -j wanout" >>./iptables-add
        fi
        #
        echo "# $now" >>iptables-del
        [ -f ./custom-script-del ] && cat ./custom-script-add >>iptables-del
        [ -n "$vpnif" ] && echo "iptables -D INPUT -o $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-del
        [ -n "$vpnif" ] && echo "iptables -D OUTPUT -i $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-add
        [ -n "$vpnif" ] && echo "iptables -D FORWARD -o $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-del
        echo "iptables -D wanin -i $wanif -m state --state NEW -j P2PARTISAN-IN
iptables -D wanout -o $wanif -m state --state NEW -j P2PARTISAN-OUT
iptables -D INPUT -i $wanif -m state --state NEW -j P2PARTISAN-IN
iptables -D OUTPUT -o $wanif -m state --state NEW -j P2PARTISAN-OUT
iptables -F P2PARTISAN-DROP-IN
iptables -F P2PARTISAN-DROP-OUT
iptables -F P2PARTISAN-LISTS-IN
iptables -F P2PARTISAN-LISTS-OUT
iptables -F P2PARTISAN-IN
iptables -F P2PARTISAN-OUT
iptables -X P2PARTISAN-IN
iptables -X P2PARTISAN-OUT
iptables -X P2PARTISAN-LISTS-IN
iptables -X P2PARTISAN-LISTS-OUT
iptables -X P2PARTISAN-DROP-IN
iptables -X P2PARTISAN-DROP-OUT" >>iptables-del

        echo "+--------- GREY IPs ---------"
        echo "| preparing IP greylist ..."
        #Load the whitelist
        if [ "$(ipset --swap greylist greylist 2>&1 | grep 'does not exist')" != "" ]; then
            ipset --create greylist hash:net hashsize 16 --resize 5 maxelem 255 >/dev/null 2>&1
        fi
        pgreylist
        echo -e "| Loading IP greylist data ---> \033[1;37m***IP greylist***\033[0;40m"
        echo "iptables -A P2PARTISAN-IN -m set  --match-set greylist src -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-IN -m set  --match-set greylist dst -g P2PARTISAN-LISTS-IN
iptables -A P2PARTISAN-OUT -m set  --match-set greylist src -g P2PARTISAN-LISTS-OUT
iptables -A P2PARTISAN-OUT -m set  --match-set greylist dst -g P2PARTISAN-LISTS-OUT" >>iptables-add

        echo "+--------- WHITE IPs ---------"
        echo "| preparing IP whitelist ..."
        #Load the whitelist
        if [ "$(ipset --swap whitelist whitelist 2>&1 | grep 'does not exist')" != "" ]; then
            ipset --create whitelist hash:net hashsize 1024 --resize 5 maxelem 1024000 >/dev/null 2>&1
        fi
        pwhitelist

        echo "# $now
ipset -F
ipset -X blacklist-custom
ipset -X greylist
ipset -X whitelist" >ipset-del

        echo -e "| Loading IP whitelist data ---> \033[1;37m***IP Whitelist***\033[0;40m"
        echo "iptables -A P2PARTISAN-IN -m set  --match-set whitelist src -j RETURN
iptables -A P2PARTISAN-IN -m set  --match-set whitelist dst -j RETURN
iptables -A P2PARTISAN-OUT -m set  --match-set whitelist src -j RETURN
iptables -A P2PARTISAN-OUT -m set  --match-set whitelist dst -j RETURN" >>iptables-add

        cat /tmp/iptables-add.tmp >>./iptables-add
        rm /tmp/iptables-add.tmp >/dev/null 2>&1

        if [ $syslogs -eq 1 ]; then
            echo "iptables -A P2PARTISAN-DROP-IN -m limit --limit $maxloghour/hour --limit-burst 1 -j LOG --log-prefix 'P2Partisan Dropped IN - ' --log-level 1
iptables -A P2PARTISAN-DROP-OUT -m limit --limit $maxloghour/hour  --limit-burst 1 -j LOG --log-prefix 'P2Partisan Rejected OUT - ' --log-level 1" >>iptables-add
        fi
        echo "iptables -A P2PARTISAN-DROP-IN -j DROP
iptables -A P2PARTISAN-DROP-OUT -j REJECT --reject-with icmp-admin-prohibited" >>iptables-add

        echo "+------- IP BLACKLISTs -------"

        grep -Ev "^#|^$" ./blacklists | tr -d "\r" |
            (
                while read -r line; do
                    counter=$(expr "${counter}" + 1)
                    counter=$(printf "%02d" "${counter}")
                    name=$(echo "${line}" | awk '{print $1}')
                    url=$(echo "${line}" | awk '{print $2}')

                    if [ "$(ipset swap "${name}.bro" "${name}.bro" 2>&1 | grep 'does not exist')" != "" ]; then
                        ipset --create "${name}.bro" hash:net hashsize 1024 --resize 5 maxelem 4096000 >/dev/null
                    fi
                    if [ "$(ipset swap "${name}" "${name}" 2>&1 | grep 'does not exist')" != "" ]; then
                        [ -f ./cidr/"${name}".cidr ] && cat ./cidr/"${name}".cidr | cut -d" " -f3 | grep -E "^${sDNS}$" >/dev/null && complete=1 || complete=0
                        if [ $complete -eq 1 ]; then #.cidr exists and populated, using it
                            echo -e "| Async loading [cached] Blacklist_${counter} --> \033[1;37m***${name}***\033[0;40m"
                            {
                                ipset -F "${name}"
                                ipset -X "${name}"
                                ipset --create "${name}" hash:net hashsize 1024 --resize 5 maxelem 4096000
                                deaggregate "${name}" "" 2 "$pre" "" $maxconcurrentlistload ${P2Partisandir} &
                            } 2>/dev/null
                        else #fresh load/first run
                            echo -e "| Async loading [convert] Blacklist_${counter} --> \033[1;37m***${name}***\033[0;40m"
                            {
                                ipset -F "${name}"
                                ipset -X "${name}"
                                ipset --create "${name}" hash:net hashsize 1024 --resize 5 maxelem 4096000
                                deaggregate "${name}" "$url" 0 "$pre" "" $maxconcurrentlistload ${P2Partisandir} &
                                # 4 = On the fly record by record STOUT output
                                # 3 = add from public whitelist sIP-dIP to ipset only
                                # 2 = add from .cidr to ipset only
                                # 1 = convert + add live + create .cidr file (very slow)
                                # 0 = convert + add live + create ipset dump
                                # different = convert + add to ipset + create .cidr file
                            } 2>/dev/null
                        fi
                    fi

                    echo "ipset -X ${name} " >>ipset-del
                    echo "iptables -A P2PARTISAN-LISTS-IN -m set  --match-set ${name} src -j P2PARTISAN-DROP-IN
iptables -A P2PARTISAN-LISTS-OUT -m set  --match-set ${name} dst -j P2PARTISAN-DROP-OUT" >>iptables-add
                done
            )

        echo "iptables -I INPUT $pos -i $wanif -m state --state NEW -j P2PARTISAN-IN
iptables -I OUTPUT $pos -o $wanif -m state --state NEW -j P2PARTISAN-OUT
iptables -I wanin $pos -i $wanif -m state --state NEW -j P2PARTISAN-IN
iptables -I wanout $pos -o $wanif -m state --state NEW -j P2PARTISAN-OUT" >>iptables-add

        [ -n "$vpnif" ] && echo "iptables -I INPUT $pos -o $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-add
        [ -n "$vpnif" ] && echo "iptables -I OUTPUT $pos -i $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-add
        [ -n "$vpnif" ] && echo "iptables -I FORWARD $pos -o $vpnif -m state --state NEW -j P2PARTISAN-IN" >>iptables-add

        #Add winin/wanout for RMerlin compatibility only
        if [ $rm -eq 1 ]; then
            echo "iptables -F wanin
iptables -X wanin
iptables -D FORWARD -i $wanif -j wanin
iptables -F wanout
iptables -X wanout
iptables -D FORWARD -o $wanif -j wanout" >>iptables-del
        fi
        #

        [ -f ./custom-script-add ] && cat ./custom-script-add >>iptables-add

        chmod 777 ./iptables-*
        chmod 777 ./ipset-*
        ./iptables-del 2>/dev/null #cleaning
        ./iptables-add 2>/dev/null #protecting

        plog "... P2Partisan started"
        echo "+------------------------- Controls ----------------------------+"

        p=$(nvram get dnsmasq_custom | grep -c 'log-async')
        if [[ $p -eq 1 ]]; then
            plog "log-async found under dnsmasq -> OK"
            echo "+---------------------------------------------------------------+"
        else
            plog "
| It appears like you don't have a log-async parameter in your dnsmasq
| config. This is strongly suggested due to the amount of logs involved,
| especially while debugging to consider adding the following command
| under Advanced/DHCP/DNS/Dnsmasq Custom configuration:
|
| log-async=20
|
+---------------------------------------------------------------+\033[0;39m"
        fi
        p=$(nvram get script_fire | grep -c "cru a P2Partisan-tutor")
        if [[ $p -eq 0 ]]; then
            ptutorset
        fi

        [ -f /tmp/p2partisan.loading ] && rm -r "/tmp/p2partisan.loading" >/dev/null 2>&1
    else
        echo -e "\033[0;40m
+------------------------- P2Partisan --------------------------+
|                 _______ __               __
|                |     __|  |_.---.-.----.|  |_
|                |__     |   _|  _  |   _||   _|
|        already |_______|____|___._|__|  |____| ed
|
+---------------------------------------------------------------+
| It appears like P2Partisan is already running. Skipping...
|
| Is this is not what you expected? Try:
| \033[1;33m./p2partisan.sh update\033[0;40m
+---------------------------------------------------------------+
				\033[0;39m"
    fi
}

function b64() {
    awk 'BEGIN{b64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"}
{for(i=1;i<=length($0);i++){c=index(b64,substr($0,i,1));if(c--)
for(b=0;b<6;b++){o=o*2+int(c/32);c=(c*2)%64;if(++obc==8){if(o)
{printf"%c",o}else{system("echo -en \"\\0\"")}obc=o=0}}}}'
}

function pdeaggregate() {
    awk '
function ip2int(ip) {
 for (ret=0,n=split(ip,a,"\."),x=1;x<=n;x++) ret=or(lshift(ret,8),a[x])
 return ret
}

function int2ip(ip,ret,x) {
 ret=and(ip,255)
 ip=rshift(ip,8)
 for(;x<3;ret=and(ip,255)"."ret,ip=rshift(ip,8),x++);
 return ret
}

BEGIN {
bits=0xffffffff
FS="[-]"
}

{
 base=ip2int($1)
 end=ip2int($2)
 while (base <= end) {
 step = 0
 while ( or(base, lshift(1, step)) != base) {
 if ( or(base, rshift((bits, (31-step)))) > end ) {
 break;
 }
 step++
 }
 print int2ip(base)"/"(32-step)
 base = base + lshift(1, step)
 }
}

' #end of awk script
}

for p in $1; do
    case "$p" in
        "start")
            pstart
            exit
            ;;
        "stop")
            pforcestop
            exit
            ;;
        "restart")
            psoftstop
            ;;
        "status")
            pstatus "$2"
            exit
            ;;
        "pause")
            psoftstop
            exit
            ;;
        "detective")
            pdetective
            exit
            ;;
        "test")
            ptest "$2"
            exit
            ;;
        "debug")
            pdebug "$2" "$3"
            exit
            ;;
        "debug-display")
            pdebugdisplay "$2"
            exit
            ;;
        "tutor")
            ptutor
            exit
            ;;
        "help")

            echo -e "\033[48;5;89m
      ______ ______ ______              __   __
     |   __ \__    |   __ \.---.-.----.|  |_|__|.-----.---.-.-----.
     |    __/    __|    __/|  _  |   _||   _|  ||__ --|  _  |     |
     |___|  |______|___|   |___._|__|  |____|__||_____|___._|__|__| $version
\e[39m\e[49m\033[0;40m

	   help					Display this text
	   \e[97mstart				   Starts the process (this runs also if no option is provided)
	   stop					Stops P2Partisan
	   restart				 Soft restart, updates whiteports & whitelist only
	   pause				   Soft stop P2Partisan allowing for quick start
	   update				  Hard restart, slow removes p2partisan, updates
							   the lists and does a fresh start
	   update <list|fix>	   Updated the selected list only | remove cidr a start from scratch\e[39m
	   status				  Display P2Partisan running status + extra information
	   status <list>		   Display P2Partisan detailed list information
	   \e[93mtest <IP>			   Verify existence of the given IP against lists
	   debug				   Shows a guide on how to operate debug
	   debug-display <in|out>  Shows all the logs relevant to the last debug only
	   detective			   Determines highest impact IPs:ports (number of sessions)
\033[0;39m"
            exit
            ;;
        *)
            echo -e "\033[0;40mparameter not valid. please run:

	   p2partisan.sh help
	   \033[0;39m"
            exit
            ;;

    esac
done

pstart

exit
