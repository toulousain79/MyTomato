# Changelog

## v1.0.14 - _2021/06/27_

- fix `.gitignore`
- Shellcheck fix
- code format
- force scripts permissions
- remove unused empty log files
- fix `Upgrade.sh` about OPKG packages listing
- `p2partisan.sh`
  - nslookup DNS
  - Shellcheck review
  - `deaggregate.sh` review
  - clean
- force source of overloaded vars
- force Quad9 DNS for internal scripts
- fix shebang

## v1.0.13 - _2021/06/21_

- disable **Ext4 Metadata Checksums** for USB disk setup from documentation _(#2)_
- remove OPKG Python2 package to avoid `opkg_install_cmd: Cannot install package python` error

## v1.0.12 - _2020/03/26_

- typo fix
- CI review

## v1.0.11 - _2019/09/22_

- DNScrypt-proxy v2
  - add 'gsExternalDns' variable for use external DNS server like PiHole
- Minor code review

## v1.0.10 - _2019/04/13_

- DNScrypt-proxy v2
  - update dnscrypt-proxy.toml.tmpl
  - update generate-domains-blacklists/domains-blacklist.conf.tmpl
  - set doh_servers to false _(DoH is not available with OPKG binary)_
  - disable empty public DNS in inti script

## v1.0.9 - _2019/03/04_

- funcs, bug fix
- DNScrypt-proxy v2
  - active tls_cipher_suite for default config
  - clean blacklists.txt
  - update default entries for cloaking-rules.txt
  - update default entries for ip_blacklist.txt
  - activate and add default file for query.log _(Query logging)_
  - activate and add default file for nx.log _(Suspicious queries logging)_
  - add defaults generate-domains-blacklists config files

## v1.0.8 - _2019/02/24_

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
