# MyTomato _(ARMv7 only)_

TomatoUSB environment for Shibby or FreshTomato **ARM v7** firmwares VPN version _(kernel v2.6.36)_.

<p align="center">
  <a href="https://img.shields.io/gitlab/pipeline/toulousain79/MyTomato/master.svg?label=master%20pipeline%20status">
    <img alt="master pipeline status" src="https://img.shields.io/gitlab/pipeline/toulousain79/MyTomato/master.svg?label=master%20pipeline%20status" /></a>
  <a href="https://img.shields.io/gitlab/pipeline/toulousain79/MyTomato/develop.svg?label=develop%20pipeline%20status">
    <img alt="develop pipeline status" src="https://img.shields.io/gitlab/pipeline/toulousain79/MyTomato/develop.svg?label=develop%20pipeline%20status" /></a>
</p>

<p align="center">
    <a href="https://github.com/toulousain79/MyTomato/blob/master/LICENCE.md"><img src="https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square" /></a>
</p>

<p align="center">
  <a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4ZZDD9NJVGL4N">
    <img alt="PayPal donate" src="https://img.shields.io/badge/Paypal-Donate-blue.svg?style=plastic&logo=paypal" /></a>
  <a href="https://www.blockchain.com/btc/payment_request?address=1HtuGsnSsGoUz7DmRbDLCFnRc41jYEY2FE">
    <img alt="Bitcoins doante" src="https://img.shields.io/badge/BitCoin-Donate-orange.svg?style=plastic&logo=bitcoin" /></a>
</p>

## Features

- Install latest [Entware](https://github.com/Entware/Entware) version _(Merge of Entware-ng-3x and Entware-ng)_
- Use of [standard](https://github.com/Entware/Entware/wiki/Alternative-install-vs-standard) installation version _(generic for kernel v2.6.36)_
- Prepare an environment for root user
  - bash _(prompt, locale, colors, readline, bash on login, ...)_
  - aliases for all Entware binaries installed _(dynamically)_
  - admin tools
  - PATH updated to prioritize binaries in /opt
  - code review of rc.unslung
  - add locales & timezone
  - auto restore the last NVRAM config saved on /opt
- Project auto upgrade _(Entware & GitHub)_
  - get patch
  - new features
  - ARM-Extras modules downloaded automatically
- [P2Partisan v6.08](https://www.linksysinfo.org/index.php?threads/p2partisan-v5-14-v6-08-mass-ip-blocking-peerblock-peerguardian-for-tomato.69128/)
  - countries blocklists
  - usual blocklists
  - known addresses of TMG
  - code review
- [DNScrypt-proxy v2](https://github.com/jedisct1/dnscrypt-proxy/blob/master/README.md) _(no DoH)_ _(disabled for AIO firmwares)_
  - DNS query monitoring, with separate log files for regular and suspicious queries
  - Filtering: **block ads**, **malware**, and other unwanted content. Compatible with all DNS services
  - Time-based filtering, with a flexible weekly schedule
  - Compatible with DNSSEC
  - ...
- NVram sets
  - init script
  - shutdown script
  - USB mount/unmount for /opt
  - ...

### Test on

- Netgear R7000 _(FreshTomato)_

## Install

### Prepare your USB disk _(mine is a 60Go SSD on USB 3.0)_

You must create partitions before _(fdisk /dev/xxx ?)_ ;-)

Replace **/dev/xxxx** by your device _(ex: /dev/sda2)_

For an USB key, you can use _ext2_, because this filesystem limits disk access in read and write _(Journaling & Directory Indexing)_.

Seas personally, I prefer to use _ext4_, as long as I disable the journaling.

This allows faster read/write access, and increases the life of your USB device ;-)

1. Prepare your SWAP and ext4 partitions

2. Format the **SWAP** partition with the label **SWAP** _(for size, 128M is sufficient)_

    ```bash
    mkswap -L SWAP /dev/xxxx
    ```

3. Format **/opt** partition as EXT4 with the label **ENTWARE** _(minimum of 4Go)_

    ```bash
    mkfs.ext4 -L ENTWARE /dev/xxxx
    ```

4. Tuning the Ext4 filesystem _(disable Journal, disable Directory Indexing, reduce 5% to 2% Reserved Blocks)_

    ```bash
    tune2fs -o ^journal_data_writeback -O ^has_journal,dir_index /dev/xxxx
    tune2fs -m 2 /dev/xxxx
    e2fsck -Df /dev/xxxx
    ```

### Install MyTomato

**It is best to before perform an _Erase all data in NVRAM memory thorough_.**

1. Plug your disk on router

2. Login in SSH

3. Make sure you have a working Internet connection on your router

4. Execute the installation

    Where FILESYSTEM can be **ext2**, **ext3** or **ext4** _(default)_

    ```bash
    export FILESYSTEM="ext4"
    wget -O - https://raw.githubusercontent.com/toulousain79/MyTomato/master/Install_From_Scratch.sh | sh
    ```

5. At the end, you will get the following message:

    ```bash
    Please, adapt '/opt/MyTomato/root/ConfigOverload/vars' as you want...

    And, reboot your router...
    The reboot can take a while, so please be patient.

    Maybe adapt your LAN IP address... ;-)
    ```

    _**NB:** Default IP address is **192.168.1.1**_

6. It's time to fill in your variables

    ```bash
    vim /opt/MyTomato/root/ConfigOverload/vars
    ```

7. Reboot

## Availables commands

All the scripts present in /opt/MyTomato/root/SCRIPTs/ are accessible directly via the PATH.

- **USB_AfterMounting.sh**
  - executed after USB /opt mounting
- **Services_Start.sh**
  - executed by USB_AfterMounting.sh
  - start all services using _/opt/etc/init.d/rc.unslung_ script
- **USB_BeforeUnmounting.sh**
  - executed after USB /opt UNmounting
- **Services_Stop.sh**
  - executed by USB_BeforeUnmounting.sh
  - stop all services using _/opt/etc/init.d/rc.unslung_ script
- **Upgrade.sh**
  - executed periodically every day
  - upgrade /opt/MyTomato/ via GitHub
  - update & upgrade OPKG packages

## Personalization

To allow the update of MyTomato, some files _(ex: config)_, are overchargeable.

If you modify the original files, you will **lose** your changes during an update of MyTomato.

Editable files are:

- System
  - /opt/MyTomato/root/ConfigOverload/vars
  - /opt/MyTomato/root/ConfigOverload/.bash_aliases
  - /opt/MyTomato/root/ConfigOverload/.bashrc

- DNScrypt-proxy v2 _(default files)_
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/dnscrypt-proxy.toml _(DNScrypt config file)_
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/blacklists.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/ip_blacklist.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/whitelist.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/cloaking-rules.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/forwarding-rules.txt

- DNScrypt-proxy v2 _(generate-domains-blacklists)_
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/domains-blacklist.conf
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/domains-blacklist-local-additions.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/domains-time-restricted.txt
  - /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/domains-whitelist.txt

- P2Partisan
  - /opt/MyTomato/root/ConfigOverload/p2partisan/blacklists
  - /opt/MyTomato/root/ConfigOverload/p2partisan/blacklists-custom
  - /opt/MyTomato/root/ConfigOverload/p2partisan/greylist
  - /opt/MyTomato/root/ConfigOverload/p2partisan/whitelist

## Additional services

### P2Partisan _(mass IP blocking like peerblock/peerguardian for tomato)_

All ports of system services are dynamicly added to whitelist. _(nvram show 2>/dev/null | grep 'port=')_

And you can add more into **/opt/MyTomato/root/ConfigOverload/vars**.

#### P2Partisan - Config file

```bash
vim /opt/MyTomato/P2Partisan/p2partisan.sh
```

_**NB:** Default values are acceptable_

#### Blocklists

- /opt/MyTomato/root/ConfigOverload/p2partisan/whitelist
- /opt/MyTomato/root/ConfigOverload/p2partisan/greylist
- /opt/MyTomato/root/ConfigOverload/p2partisan/blacklists
- /opt/MyTomato/root/ConfigOverload/p2partisan/blacklist-custom

_**NB:** Default values are acceptable_

### DNScrypt-proxy v2

#### DNScrypt-proxy - Config file

```bash
vim /opt/MyTomato/root/ConfigOverload/dnscrypt/dnscrypt-proxy.toml
```

You can generate your own **blacklist.txt** with in **/opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/**.

Please, check [Public Blacklists](https://github.com/jedisct1/dnscrypt-proxy/wiki/Public-blacklists)

Edit following files like you want to generate your final **blocklist.txt**:

- /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/**domains-blacklist.conf**
- /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/**domains-whitelist.txt**
- /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/**domains-time-restricted.txt**
- /opt/MyTomato/root/ConfigOverload/dnscrypt/generate-domains-blacklists/**domains-blacklist-local-additions.txt**

And, simply execute this:

```bash
Upgrade.sh
. /opt/MyTomato/root/SCRIPTs/inc/vars
cp -f "${gsDirOverLoad}/dnscrypt/generate-domains-blacklists/blacklists.txt" "${gsDirOverLoad}/dnscrypt/blacklists.txt"
/opt/etc/init.d/S09dnscrypt-proxy2 restart
```

_**NB:** Default values are acceptable_

## Links

- [FreshTomato](http://freshtomato.org/) _(active development from Shibby work)_
- [Tomato by Shibby](http://tomato.groov.pl/)
- [Entware - WiKi](https://github.com/Entware/Entware/wiki)
- [DNScrypt - WiKi](https://github.com/jedisct1/dnscrypt-proxy/wiki)
- [DNScrypt - Public Blacklists](https://github.com/jedisct1/dnscrypt-proxy/wiki/Public-blacklists)
- [P2Partisan](https://www.linksysinfo.org/index.php?threads/p2partisan-v5-14-v6-08-mass-ip-blocking-peerblock-peerguardian-for-tomato.69128/)
- [armv7sf-k3.2 - installer](http://bin.entware.net/armv7sf-k3.2/installer/)
