---
title: QEMU+KVM notes
description: >
  These are my notes about installing and running QEMU+KVM on Debian systems.
summary: >
  These are my notes about installing and running QEMU+KVM on Debian systems.
  They contain some useful information and serve as a quick reference on
  using KVM.
date: 2024-07-01
tags: ["qemu", "kvm", "vm", "virtualization", "linux", "windows"]
author: ["Marco Paganini"]
draft: false
---

# QEMU+KVM notes

## Assumptions

* We're running in a debian system.
* We're running in an AMD processor (not much to change if using Intel).
* We're using the default directories for VMs (`/usr/lib/libvirt/<IMAGE>/files...`)

## Debian pre-requisites

Make sure the CPU has virtualization capabilities:

```bash
grep -c '\(vmx\|svm\)' /proc/cpuinfo
```

Output should be > 0.

Install the required qemu and libvirt packages:

```bash
sudo apt-get install qemu-kvm qemu-system qemu-utils \
    libvirt-clients libvirt-daemon-system virtinst

```

Make sure libvirtd is running:

```bash
sudo systemctl status libvirtd.service
```

Make sure the `kvm` and `kvm_intel` or `kvm_amd` modules are loaded.

```bash
sudo virsh net-list --all
 Name      State      Autostart   Persistent
 ----------------------------------------------
  default   inactive   no          yes
```

Start the network and configure it to start on boot:

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

## VM Creation example (debian bookworm)

The example below may get outdated rapidly, as OS versions change all the time.
Please adjust the download version and image, as well as the `--os-variant` and
`--os-type` to match.

```bash
LIBVIRT_DIR="/var/lib/libvirt"

# Create directories for disk image and ISO
mkdir -p "${LIBVIRT_DIR?}"/{images,iso}/debian

# Fetch ISO file from debian
curl -L \
  https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.6.0-amd64-netinst.iso \
  >"${LIBVIRT_DIR?}"/iso/debian/debian.iso

# Create a VM called "debian" and open the console.
sudo virt-install \
  --name debian \
  --os-variant debianbookworm \
  --ram 2048 \
  --cpu host \
  --disk "${LIBVIRT_DIR?}"/images/debian/debian.qcow2,device=disk,bus=virtio,size=10,format=qcow2 \
  --graphics spice \
  --hvm \
  --cdrom "${LIBVIRT_DIR?}"/iso/debian/debian.iso \
  --boot cdrom,hd
```

Note: If you get an apparmor error, this could be explained by libvirt bug [#665531](https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/665531). To work around this bug, edit `/etc/libvirt/qemu.conf` and add
`security_driver=none` to the file.

This will open a graphical console to your newly created VM so you can finish
the OS installation.  If the machine in question does not have graphical
capabilities, add the `--noautoconsole` command-line option and open
`virt-viewer` from a remote machine.

## Basic VM commands

* `virsh list --all` - Show all VMs (running and stopped).
* `virsh start vm` - Start the VM.
* `virsh shutdown vm` - Shutdown the VM.
* `virsh destroy vm` - Forceful shutdown.
* `virsh undefine vm [--nvram] [--remove-all-storage]` - Undefine (deletes) the VM.
* `virsh console vm` - Serial console into the VM.
* `virsh autostart --domain domain` - Enable autostart for the domain (VM).
* `virsh domiflist domain` - List the network interfaces for the domain.

## Pool management

* `virsh pool-list` - List pools (a pool is a directory, mountpoint, device, etc and contains volumes).
* `virsh pool-destroy` - Destroy (stop) the pool.
* `virsh pool-delete` - Delete the ALL pool data (definition remains available).
* `virsh pool-undefine` - Delete the pool from the list of pools (definition).

## Volume management

* `virsh vol-list --pool pool_name` - List volumes.
* `virsh vol-delete --pool pool_name` - Delete a volume.

## Check the VM manager using VNC or `virt-viewer`

```
sudo virsh vncdisplay vmname
:0
vncviewer localhost:0
```
or

```bash
virt-viewer vmname
```

It's also possible to use `virt-viewer` and open a graphical console directly.

## CPU notes

By default, qemu will use the qemu64/qemu32 virtualized CPUs which perform poorly and should be avoided.
On the command-line, use `--cpu host` to pass use cpu-passthrough. This should improve guest performance
but will make migrations harder. It's also possible to use a named cpu model (E.g. `--cpu Opteron_G5` for
AMD hosts and `--cpu Skylake-Server` for intel.

For virsh (`virsh edit domain`), it's possible to use the following snippet to enable cpu-passthrough:

```bash
<cpu mode='host-passthrough' check='partial'/>
```

Don't forget to limit the number of CPUs in the guest with:

```bash
<vcpu placement='static'>2</vcpu>
```

It's also possible to edit these directly in `virt-manager`, but I didn't find
a way to enable `host-passthrough`, only `host-model`, which is safer for
migrations but slightly less performant. When specifying the CPU mode, pay
attention to the `check='partial'` flag. Without it, virt-manager could set it
to full which will cause failures as the guest does not have certain features
of the host enabled (like CPU virtualization).

More info:
https://www.berrange.com/posts/2018/06/29/cpu-model-configuration-for-qemu-kvm-on-x86-hosts/

## Pool management

A pool is a quantity of storage put aside for "volumes", which are then used by
VMs. Pools can be Network mountpoints, directories, filesystems, etc.

Viewing pools:

```bash
virsh list-pools --all
```

To completely delete a pool:

```bash
virsh pool-destroy poolname
virsh pool-delete poolname
virsh pool-undefine poolname
```

* `destroy` removes the pool from libvirt's control, but does not remove the
  data. The data can be later recovered with `pool-create`.

* `delete` deletes the resources (volumes) used by the pool. This operation is
  non-recoverable. The pool object will still exist after this command, ready
  for the creation of new volumes.

* `undefine` completely removes the configuration for an inactive pool.

## Allowing regular user access

If you prefer regular users to manage the VMs, add them to the `libvirt` and
`libvirt-qemu` unix groups:

```bash
sudo adduser $USER libvirt
sudo adduser $USER libvirt-qemu
```

Also set the `LIBVIRT_DEFAULT_URI` environment variable to point to the global scope:

```bash
export LIBVIRT_DEFAULT_URI="qemu:///system"
```

or use `--connect qemu:///system` on the `virsh` command-line.

## Resizing volume

* Use `sudo virsh dumpxml VM_NAME | grep "source file"` to locate the disk image.
* To get information on the file: `sudo qemu-img info IMAGE_FILE`
* Resize with: `sudo qemu-img resize IMAGE_FILE +xxG`

## Missing 2560x1440 on Linux

For some reason the native mode of 2560x1440 did not show on xrandr using the QXL driver.
The solution was to add it manually.

First, calculate the VESA modeline:

```bash
$ cvt 2560 1440
Modeline "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
```

Then create a xorg.conf snippet in `/usr/share/x11/xorg.conf/10-monitor.conf`:

```bash
section "Monitor"
    Identifier "Virtual-0 "
    Modeline "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
    Modeline "3840x2160_60.00"  712.75  3840 4160 4576 5312  2160 2163 2168 2237 -hsync +vsync
    Option "PreferredMode" "2560x1440_60.00"
EndSection
```

Note: The snippet above worked until an upgrade. It appears that newer versions
of X use "Virtual-1" instead of "Virtual-0" (there's also the issue of the
space). Another possibility (untested) is to force the name of the monitor on
the default screen:

```bash
Section "Screen"
    Identifier "Default screen"
    Monitor "default-monitor"
EndSection

section "Monitor"
    Identifier "default-monitor"
    Modeline "2560x1440_60.00"  312.25  2560 2752 3024 3488  1440 1443 1448 1493 -hsync +vsync
    Modeline "3840x2160_60.00"  712.75  3840 4160 4576 5312  2160 2163 2168 2237 -hsync +vsync
    Option "PreferredMode" "2560x1440_60.00"
EndSection
```

Further reading: https://stafwag.github.io/blog/blog/2018/04/22/high-screen-resolution-on-a-kvm-virtual-machine-with-qxl/

## Converting windows devices to VirtIO

The default SATA devices work well, but (supposedly) have worse performance
than the virtio devices. Those devices can be installed at boot time (by
passing the device path to Windows), or after installation with the steps
below:

Source: https://superuser.com/questions/1057959/windows-10-in-kvm-change-boot-disk-to-virtio/1095112

* Add both windows 10 DVD/CD ISO and virtio driver ISO to VM.
* The latest driver ISO can be pulled out of the RPMs found at
  https://fedorapeople.org/groups/virt/virtio-win/repo/latest/
* Boot off windows 10 DVD/CD and get into a command prompt from repair mode option.
  Load the driver via the CLI: `drvload d:\viostor\w10\amd64\viostor.inf`
    * In my case d: was where the virtio install ISO got assigned.
    * After loading the driver e: was where the windows install became mounted.
* Use the DISM command to inject the storage controller driver
    * E.g. `dism /image:f:\ /add-driver /driver:e:\viostor\w10\amd64\viostor.inf`

As above, change drive letter assignments according to your own environment.
Avoids needing to fiddle with making special windows boot CDs/Images and
'patches' the actual windows install image on the fly.

## Clipboard sharing

* Linux guests: `sudo apt-get install spice-vdagent`
* Windows guests: install https://www.spice-space.org/download/binaries/spice-guest-tools/

Note that display type must be set to Spice.

## Folder sharing

* Linux guests can use NFS and a shared filesystem (but this does not work for Windows guests).
* For Windows, that does not work and the alternative is to use SPICE:
  * In virt-manager in the details view click "Add Hardware" and select a "Channel" device.
  * Set the new device name to org.spice-spave.webdav.0, leave other fields as they are.
  * Start the guest machine and install [spice-webdav](https://www.spice-space.org/download/windows/spice-webdavd/)
    on the guest. After installation make sure the "Spice webdav proxy" service is running
    (via services.msc).
  * Run C:\Program File\SPICE webdavd\map-drive.bat to map the shared folder, which by
    default is `~/.Public`.
  * Errors like "System error 67 has occurred, the network name cannot be found" mean the webdav proxy
    is not running.
  * To change the shared folder, use virt-viewer instead of virt-manager and configure it under
    File->Preferences.

Source:
https://www.guyrutenberg.com/2018/10/25/sharing-a-folder-a-windows-guest-under-virt-manager/

Another option is to mount a NFS share with Windows:
https://graspingtech.com/mount-nfs-share-windows-10/

## Bridged networking

* Default networking mode is NAT. In this case, QEMU creates a 192.168.X.X/24 subnet and
  the required iptables on the host to route to that network.
* libvirt starts dnsmasq on each network to provide a range of DHCP addresses (subnetting?)
* Recommendation: [Use a bridge](https://jamielinux.com/docs/libvirt-networking-handbook/bridged-network.html) ([Archived version](https://archive.is/cnnOg))

## Converting VDI images to qcow2

You can convert your virtualbox images to qcow2 and run them under KVM:

```bash
qemu-img convert -f vdi -O qcow2 [VBOX-IMAGE.vdi] [KVM-IMAGE.qcow2]
```

## Shrinking qcow2 images

* Run `fstrim -av` on the guest.
* Shutdown the VM.
* Copy the qcow2 file to a backup (ex: foo-backup.qcow2)
* Convert the backup on top of the original:

```bash
qemu-img convert -o cluster_size=2M -O qcow2 foo-backup.qcow2 foo.qcow2
```

To use compression, add `-c` to the qemu-img command-line above. Note that compression does not
write new data compressed(?) according to http://archive.vn/6sF4b

## Windows 10 optimizations

Source:
https://scribe.rip/@leduccc/improving-the-performance-of-a-windows-10-guest-on-qemu-a5b3f54d9cf5

Run `virsh editxml` and change/add the following items:

* Change the disk driver to be virtio.
* Turn off write caching.
* Set features.
* Pin the CPUs.

```
<domain type='kvm' ...>
  ...
  <features>
  ...
    <iothreads>1</iothreads>
    <cputune>
      <vcpupin vcpu='0' cpuset='1'/>
      <vcpupin vcpu='1' cpuset='5'/>
      <vcpupin vcpu='2' cpuset='2'/>
      <vcpupin vcpu='3' cpuset='6'/>
      <vcpupin vcpu='4' cpuset='3'/>
      <vcpupin vcpu='5' cpuset='7'/>
      <emulatorpin cpuset='0,4'/>
      <iothreadpin iothread='1' cpuset='0,4'/>
    </cputune>

    <hyperv mode='custom'>
      ...
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <synic state='on'/>
      <stimer state='on'>
        <direct state='on'/>
      </stimer>
      <reset state='on'/>
      <frequencies state='on'/>
      <reenlightenment state='on'/>
      <tlbflush state='on'/>
      <ipi state='on'/>
    </hyperv>
  </features>

  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <clock offset='localtime'>
    <timer name='rtc' present='no' tickpolicy='catchup'/>
    <timer name='pit' present='no' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='kvmclock' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>

  <devices>
    ...
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='threads' discard='unmap' iothread='1' queues='6'/>
      ...
    </disk>
  </devices>
```

## Windows 10 only uses 2 CPUs.

From: http://www.openwebit.com/c/how-to-run-windows-vm-on-more-than-2-cores-under-kvm/

Windows guests do not recognize all of the available cores under KVM and will
usually detect only 2 cores. This happens since KVM exposes the available
virtual CPU cores as physical CPUs (sockets). So, if the physical host running
KVM has 2 CPUs with 4 cores each (a total of 8 cores), and the guest is
configured for 8 CPUs, Windows will see 8 physical CPUs and will run only on 2,
due to the hard coded limits in some of the editions of Windows Server.

To make Windows use all available cores, we need to configure the guest to
expose the CPUs as cores and not as physical CPUs (sockets):

In virt-manager:

Open the guest configuration screen:

* Select Processor options tab
* Expand the “Topology” setting
* Set the sockets to 2
* Set the cores to 4 (for the guest to have a total of 8 cores) or 3 (for the
  guest to have a total of 6 cores).
* You can also expand the “Configration” settings and click on “copy host CPU
  configuration” to make the guest fully use all of the physical host’s CPU
  capabilities.

Note: This worked with 6 host CPU cores (2 sockets, 3 cores)

## virt-manager fullscreen keyboard grabbing

* Use Ctrl+Alt to release the keyboard on fullscreen mode.

## Further reading and sources

* https://www.linuxtechi.com/install-configure-kvm-debian-10-buster/
* https://linuxhint.com/install_kvm_debian_10/
* A discussion of display devices in qemu:
  * https://www.kraxel.org/blog/2019/09/display-devices-in-qemu/

