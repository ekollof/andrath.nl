.so macros.ms
.MS
.TL
vm_manager, a script to manage openbsd VMs with vmm
.AU
Emiel Kollof
.DA
April 02, 2025 08:17:11
.PP
Yes, OpenBSD vmm is limited, but you can still do a lot with it. I've been
using it for a while now, and I've written a script to manage VMs with it. It's
called vm_manager, and it's available on my GitHub page. In this post, I'll
explain how to use it and what it can do.
.SH
What problem am I solving here?
.PP
By default, OpenBSD vmm is not set up. You have to enable stuff, create config
files and start and manage VMs manually. This can be a bit of a hassle, so I
created vm_manager to automate the setup op vmm itself, and the creation and
management of VMs.
.PP
It's available on my Youtube scripts page here:
.URL "https://github.com/ekollof/youtube-openbsd/tree/master/vmmanager" "Github - vmmanager"
.PP
I've showcased this script on my youtube channel and demonstrated it's use, but
I think it's worthwhile to write a blog post about it as well. You can find the
video here:
.URL https://youtube.com/live/snDYh9IGsM0 "YouTube - vmm hypervisor and vm_manager.sh"
.SH
What does it do?
.PP
It does a couple of things when it starts up for the first time:
.ULS
.LI
It will set up the vmm environment for you, including things like dhcpd
.LI
It will generate and maintain a vmd.conf
.LI
It will download an installation ISO (the latest one by default, for several
Linux distributions). OpenBSD snapshots will never be cached. Using custom ISOs
is being developed.
.LI
When creating a VM, it will start the VM with an installation ISO mounted and
it will boot from that.
.LI
You can archive/delete/start/stop and clone VMs. You can also import existing
qcow2 files (e.g. from other machines)
.LI
And probably more in the future.
.ULE
.PP
.SH
How does it work?
.PP
Well, I hate to be the guy that says RTFM, but the README supplied with this
script will tell you all that you need. If you have any issues with it, please
create an issue on github and I'll look into it. Patches welcome too.
.PP
.SH
TODO
.PP
.ULS
.LI
Custom ISO support - boot/install from custom ISO
.LI
IPv6 - Should be optional, but it should support it if it's used
.ULE
