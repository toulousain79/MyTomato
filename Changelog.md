# Changelog

## v1.0.9 - 2019/03/04

- funcs, bug fix

## v1.0.8 - 2019/02/24

- code review of ci/31-check_bash.sh
- remove all variable declaration
- add Youtube to DNScrypt whitelist
- update P2Partisan blacklists _(block more countries)_

## v1.0.7 - _2019/01/31_

- mount /tmp to /opt/tmp to avoid overloading NVRAM
- increase /tmp to 256MB
- update DNScrypt-proxy blacklists.txt
- P2Partisan disable upgrade & autorun functions
- P2Partisan disable tutor on firewall script, add it to custom schedule 1 at 05:00
- bug fix Install_From_Scratch.sh
- code review for .autorun script
- add lock file for USB_AfterMounting.sh & USB_BeforeUnmounting.sh
- P2Partisan update blocklists

## v1.0.6 - _2019/01/29_

- add .autorun to /opt _(permit to restore last NVRAM config file after a reset)_
- add more NVRAM save _(after mounting, before unmounting, during upgrade)_
- add Python 2 & 3 packages
- update DNScrypt-proxy blacklists.txt from [Public Blacklists](https://github.com/jedisct1/dnscrypt-proxy/wiki/Public-blacklists)
- add [DNScrypt-proxy utils](https://github.com/jedisct1/dnscrypt-proxy/tree/master/utils/generate-domains-blacklists)
- included DNScrypt-proxy repo update _(get latest DNScrypt-proxy utils)_
- add comment in README about DNScrypt-proxy utils
- add loading custom config files directly into S09dnscrypt-proxy2.tmpl
- P2Partisan, remove native autorun
- disable Upgrade.sh after USB mounting

## v1.0.5 - _2019/01/28_

- p2partisan.sh
  - dynamic addition of all ports of system services _(nvram show 2>/dev/null | grep 'port=')_
  - add gsP2Partisan_UdpPorts & gsP2Partisan_TcpPorts to vars files
  - update blocklists

## v1.0.4 - _2019/01/26_

- remove Orange ISP patch
- change the location of custom configuration files for DNScrypt-proxy and P2Partisan
- p2partisan.sh version code review
- DNScrypt-proxy detect AIO firmware

## v1.0.3 - _2019/01/25_

- remove backup of DNScrypt-config.toml by date
- add auto restore NVRAM configuration file after mount /opt
- change the location of custom configuration files for DNScrypt-proxy and P2Partisan
- bug fix for Orange_ISP.sh
  - create method for /sbin/udhcpc
  - nvram set script_init
  - orange_ack_script_fire.sh
  - variables backslashes
  - some mistakes - p2partisan.sh, correct some shellcheck errors codes _(SC2164, SC2034, SC2046, SC2154, SC2181, SC2162, SC2116, SC2016)_

## v1.0.2 - _2019/01/22_

- disable DNScrypt v2 install for AIO firmware version _(nvram get os_version)_
- add port 52 to p2partisan whitelist
- update README
- add chmod after an Upgrade for p2partisan.sh

## v1.0.1 - _2019/01/22_

- add /opt/etc/init.d/ to .bashrc
- add p2partisan.sh alias to .bash_aliases
- code review for gfnP2pArtisanStartStop function to add/remove start on boot
- add whiteports_tcp=43,80,443 and whiteports_udp=53,123,1194:1196 to p2partisan.sh

## v1.0.0 - _2019/01/19_

- First release
