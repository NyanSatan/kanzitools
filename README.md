# kanzitools

***It's a dangerous set of software, so be extremely careful when using this, no warranty given, you are on your own***

Previously known as **kanzictl**. Now it's a pack of 5 tools for interacting with **Kanzi**, its' derivatives (**Nova**/**Koba**) and in some cases other probes (**Chimp**, **Koko**, etc.), as well as their bootloaders

All of them are described below


## kblctl

A tool to interact with **KanziBoot** (**ChimpBoot**, **KokoBoot** - it's all the same protocol) - to dump, flash (*do not summon at all costs!*) or reboot your probe

***Gorilla and Kong use different bootloaders with mass storage based protocol and are not supported by this tool***

### Building

Using Xcode. This functionality no longer depends on **libAstrisAPI**

### Usage

Usage is simple:

```
noone@Mac-mini-noone ~ % kblctl     
usage: kblctl VERB [options]
where VERB is one of the following:
	flash <file>	flash firmware from a file
	dump <file>		dump firmware to a file
	reset			reset to normal mode
```

For obvious reasons, your probe must already be in bootloader mode. To enter it press a little button...:

* **Kanzi**/**Nova**/**Koba** - ...in the LED hole
* **Chimp** - ...in the non-LED hole (the furthest one from micro-USB port)
* **Koko** - ...near the ARM Cortex Debug connector and the green blinking LED

**UDT** doesn't have the button (or it's unreachable due to its' special enclosure), so **probeenterdfu** in conjuction with **astrisprobed_patcher** might be handy (next 2 sections)

Once the probe reaches bootloader mode, the tool can be finally used. Examples:

```
noone@Mac-mini-noone ~ % kblctl dump /tmp/koba.bin    # dumping
device: KanziBoot-B-REDACTED
dump request sent, reading...
successfully dumped to /tmp/koba.bin!

noone@Mac-mini-noone ~ % kblctl flash /tmp/koba.bin    # flashing
device: KanziBoot-B-REDACTED
this is a dumped firmware image
flash request sent, writing...
successfully flashed!

noone@Mac-mini-noone ~ % kblctl reset    # rebooting back to normal mode             
device: KanziBoot-B-REDACTED
reset request sent successfully!
```

If there're several devices available, it will show a menu:

```
noone@Mac-mini-noone ~ % kblctl reset              
a) KokoBoot-REDACTED
b) KanziBoot-B-REDACTED
c) ChimpBoot-3-REDACTED
Select one of the devices listed above: 
```

## kblcrcfix

***WARNING**: this is dangerous! Messing with firmware can break your priceless probe! Proceed only if you absolutely know what you are doing!*

A small tool that fixes CRC in **Kanzi** (and derivatives), **Chimp** (and derivatives) and **Koko** firmwares in case you patched them. If you don't fix CRC, probe's bootloader will not jump to the actual firmware and thus will open DFU instead

It also can be used to truncate dumped firmwares (1 MiB for **Kanzi**/**Chimp** and 128 KiB for **Koko**) to their original lengths

### Building

Using `make.sh`. This tool doesn't depend on **libAstrisAPI**

### Usage

Dead easy:

```
➜  kblcrcfix git:(master) ✗ ./kblcrcfix
./kblcrcfix <input> <output>
```

Output example:

```
➜  kblcrcfix git:(master) ✗ ./kblcrcfix firmware_0.90_Chimp_like_UDT.bin /dev/null
firmware length = 0x29ffc
final CRC = 0x0cb100bc
final CRC is NOT 0x0, fixing
current CRC = 0x967b004b
computed CRC = 0x6d637434
recomputed final CRC = 0x00000000
written output file
DONE!
➜  kblcrcfix git:(master) ✗
```

## probeenterdfu

A tiny tool you can use to send a probe to bootloader mode programmatically, i.e. without pressing any buttons

### Building

Using `make.sh`. This program does depend on **libAstrisAPI**, which must be installed at `/usr/local/lib` (comes with Astris since Tigris)

### Usage

```
noone@Mac-mini-noone ~ % probeenterdfu
 0) Koko-REDACTED
 1) KobaSWD-REDACTED
 2) ChimpSWD-REDACTED
Choose a device: 
1
choice: 1
the probe should reach bootloader now
```

***Warning**: this tool uses Astris API, thus it won't be able to detect Nova or UDT without patched `astrisprobed`*

## astrisprobed_patcher

***WARNING**: this tool hasn't been tested with modern versions of Astris and macOS, so be careful!*

Patches `astrisprobed` in memory to make it detect **Nova** as **Kanzi** or **UDT** as **Chimp** or both

### Building

Using Xcode. This functionality doesn't depend on **libAstrisAPI**

### Usage

```
noone@Mac-mini-noone ~ % sudo killall astrisprobed    # might be important to kill the daemon

noone@Mac-mini-noone ~ % astrisprobed_patcher
astrisprobed_patcher OPTIONS
where OPTIONS are the following:
	--daemon	run as daemon
	--nova		patch Kanzi's PID to Nova's
	--udt		patch Chimp's PID to UDT's

either --nova or --udt must be passed
noone@Mac-mini-noone ~ % 
```

*Daemon mode* means it will always wait for `astrisprobed`' spawn. Useful if you want it to run with system startup

You might need to kill `astrisprobed` (so it will respawn) before using this tool

***Warning**: as you can understand from its' usage description, this tool replaces PIDs, that means if you run it with `--nova`, for example, real Kanzi won't be detected anymore unless you restart `astrisprobed` (same for Chimp/UDT). For more elegant solution that allows using them simultaneously, look at SNRSpoofer (next section)*

### SIP notes

**SIP** (**S**ystem **I**ntegrity **P**rotection) is a security feature used since OS X 10.11. Along with many other things, it also disallows using `task_for_pid()` against Apple-signed executables. You can disable it by rebooting into recovery partition and exceuting the following command:

```
csrutil enable --without debug
```

This will leave you with **SIP** (mostly) enabled, except for disallowing certain debugging capatibilities

## SNRSpoofer

***Warning**: be extremely careful with this one*

A code-less kernel extension that changes **Nova**'s USB PID (0x1624) to **Kanzi**'s (0x1621) on the fly by using `AppleUSBMergeNub`. Thus, you can use both **Kanzi** and **Nova** at the same time with Astris, but lose the ability to use **Nova** with Serial Number Reader app (can be patched though)

### Installing

Copy the kext to `/Library/Extensions`:

```
sudo cp -a SNRSpoofer.kext /Library/Extensions
```

Fix ownerships:

```
sudo chown -R root:wheel /Library/Extensions/SNRSpoofer.kext
```

Try to load:

```
sudo kextload /Library/Extensions/SNRSpoofer.kext
```

If everything is fine, invalidate kext cache:

```
sudo kextcache -i /
```

On Big Sur you also need to reboot for changes to make effect:

```
sudo reboot
```


## kanzifraudctl

This one allows you to interact with **KFL** (**K**anzi **F**raud **L**ibrary) functionality of your **Kanzi**/**Nova** (**Koba** and **Chimp** support will come later). To learn more about the subject, please read [this](https://nyansatan.github.io/lightning-snr/)

### Building

Using Xcode. This tool does depend on **libAstrisAPI**, which must be installed at `/usr/local/lib` (comes with Astris since Tigris) 

### Usage

There're 2 options - generate signature using SHA-1 hash or dump a public certificate to a file:

```
noone@Mac-mini-noone ~ % kanzifraudctl
usage: kanzifraudctl <option> <arg>
where option is one of the following:
	-g <SHA-1>	generate signature from hash
	-c <path>	dump certificate
noone@Mac-mini-noone ~ %
```

Examples of an output:

```
noone@Mac-mini-noone ~ % kanzifraudctl -g ba66cb5bb5e6a04ead8d6506a919f6666bdf1978
signature length: 128
took 234746 microseconds
B64 SIGNATURE:
PgufF9nd2I3DHCLv9Aj1koKgjz+sQkygIcejf3SOFLWCy3MTLmNT07ipRtEewo7f4JRnCjMD
AkqAYqFg8ZAFrUd7OmF29hsm61V3DYf0vycdPGqS7wkWoIf18GPoPd4JsLbnFNKYJkABna4b
UBa2gidx51V1dsMpQZXSxf31Kl8=

noone@Mac-mini-noone ~ % kanzifraudctl -c /tmp/kanzi.der
certificate length: 908
reading at offset: 0
reading at offset: 128
reading at offset: 256
reading at offset: 384
reading at offset: 512
reading at offset: 640
reading at offset: 768
reading at offset: 896
written to /tmp/kanzi.der
noone@Mac-mini-noone ~ %
```

# Credits

Objective-See project for ProcInfo
