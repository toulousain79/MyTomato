**v1.0.3** - _(started at 2019/01/22)_
 - correct shellcheck codes: SC2039, SC2059, SC2236, SC2016, SC2004, SC2003, SC2116, SC2162, SC2006
 - add procps-ng-pgrep package

**v1.0.2** - _2019/01/22_
 - disable DNScrypt v2 install for AIO firmware version _(nvram get os_version)_
 - add port 52 to p2partisan whitelist
 - update README
 - add chmod after an Upgrade for p2partisan.sh

**v1.0.1** - _2019/01/22_
  - add /opt/etc/init.d/ to .bashrc
  - add p2partisan.sh alias to .bash_aliases
  - code review for gfnP2pArtisanStartStop function to add/remove start on boot
  - add whiteports_tcp=43,80,443 and whiteports_udp=53,123,1194:1196 to p2partisan.sh

**v1.0.0** - _2019/01/19_
  - First release
