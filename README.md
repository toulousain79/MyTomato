# MyTomato _(ARMv7 only)_

MyTomato environment for Shibby or FreshTomato **ARM v7** firmwares _(kernel v2.6.36)_.

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg?style=for-the-badge)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4ZZDD9NJVGL4N)

### Features

  * Install latest [Entware](https://github.com/Entware/Entware) version _(Merge of Entware-ng-3x and Entware-ng)_
    * Use of [standard](https://github.com/Entware/Entware/wiki/Alternative-install-vs-standard) installation version _(generic for kernel v2.6.36)_
  * Prepare an environment for root user
	  * bash _(prompt, locale, colors, readline, bash on login, ...)_
	  * aliases for all Entware binaries installed _(dynamically)_
	  * admin tools
    * add locales & timezone
  * Project auto upgrade _(Entware & GitHub)_
	  * get patch
	  * new features
	  * ARM-Extras modules downloaded automatically
  * [P2Partisan v6.08](https://www.linksysinfo.org/index.php?threads/p2partisan-v5-14-v6-08-mass-ip-blocking-peerblock-peerguardian-for-tomato.69128/)
	  * Countries blocklists
	  * Usual blocklists
	  * known addresses of TMG
  * [DNScrypt-proxy v2](https://github.com/jedisct1/dnscrypt-proxy/blob/master/README.md) _(no DoH)_
	  * DNS query monitoring, with separate log files for regular and suspicious queries
	  * Filtering: **block ads**, **malware**, and other unwanted content. Compatible with all DNS services
	  * Time-based filtering, with a flexible weekly schedule
	  * Compatible with DNSSEC
	  * ...
  * NVram sets
	  * init script
	  * shutdown script
	  * USB mount/unmount for /opt
	  * ...
  * [Orange FAI patch](https://lafibre.info/remplacer-livebox/tuto-mode-dhcp-sur-firmware-tomato/12/
) _(WAN DHCP, get full speed)_

### Test on

  * Netgear R7000 _(FreshTomato)_


# Install

## Prepare your USB disk _(mine is a 60Go SSD on USB 3.0)_

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

## Install MyTomato

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

# Personalization

To allow the update of MyTomato, some files _(ex: config)_, are overchargeable.

If you modify the original files, you will **lose** your changes during an update of MyTomato.

Editable files are:

  * /opt/MyTomato/root/ConfigOverload/vars
  * /opt/MyTomato/root/ConfigOverload/.bash_aliases
  * /opt/MyTomato/root/ConfigOverload/.bashrc
  * /opt/MyTomato/root/ConfigOverload/dnscrypt-proxy.toml _(DNScrypt config file)_
  * /opt/MyTomato/root/ConfigOverload/dnscrypt.blacklists.txt
  * /opt/MyTomato/root/ConfigOverload/dnscrypt.ip_blacklist.txt
  * /opt/MyTomato/root/ConfigOverload/dnscrypt.whitelist.txt
  * /opt/MyTomato/root/ConfigOverload/dnscrypt.cloaking-rules.txt
  * /opt/MyTomato/root/ConfigOverload/dnscrypt.forwarding-rules.txt
  * /opt/MyTomato/root/ConfigOverload/p2partisan.blacklists
  * /opt/MyTomato/root/ConfigOverload/p2partisan.blacklists-custom
  * /opt/MyTomato/root/ConfigOverload/p2partisan.greylist
  * /opt/MyTomato/root/ConfigOverload/p2partisan.whitelist

# Additional services

## P2Partisan _(mass IP blocking - peerblock/peerguardian for tomato)_

### Config file

```bash
vim /opt/MyTomato/P2Partisan/p2partisan.sh
```

_**NB:** Default values are acceptable_

#### Blocklists

  * /opt/MyTomato/root/ConfigOverload/p2partisan.whitelist
  * /opt/MyTomato/root/ConfigOverload/p2partisan.greylist
  * /opt/MyTomato/root/ConfigOverload/p2partisan.blacklists
  * /opt/MyTomato/root/ConfigOverload/p2partisan.blacklist-custom

_**NB:** Default values are acceptable_

## DNScrypt-proxy v2

### Config file

```bash
vim /opt/MyTomato/root/ConfigOverload/dnscrypt-proxy.toml
```

_**NB:** Default values are acceptable_

## Orange ISP patch

If you have a fiber connection and no longer use your Livebox, you will need to use an Optical Network Termination _(ONT)_.

You pass your IP address directly to your router.

But it is likely that your downstream flow is limited _(100MB instead of 300?)_.

Some have found the solution to remedy this problem.

To apply the patch:

1. add your Orange login _(fti/xxxxx)_ in **/opt/MyTomato/root/ConfigOverload/var**s _(gsOrange_FTI)_
2. Login in SSH
3. Run the Orange_ISP.sh script
4. Reboot ;-)

```bash
vim /opt/MyTomato/root/ConfigOverload/var
bash /opt/MyTomato/root/PATCHs/Orange_ISP.sh
reboot
```

# Links

  * [FreshTomato](http://freshtomato.org/) _(active development from Shibby work)_
  * [Tomato by Shibby](http://tomato.groov.pl/)
  * [Entware - WiKi](https://github.com/Entware/Entware/wiki)
  * [DNScrypt - WiKi](https://github.com/jedisct1/dnscrypt-proxy/wiki)
  * [P2Partisan](https://www.linksysinfo.org/index.php?threads/p2partisan-v5-14-v6-08-mass-ip-blocking-peerblock-peerguardian-for-tomato.69128/)
  * [armv7sf-k3.2 - installer](http://bin.entware.net/armv7sf-k3.2/installer/)