
Hobby projects:

Ansible Action plugin: Python, Powershell, C#, Win32, COM, IaCA plugin to generate an unattend.xml answer file for automated Windows installation and driver installation. Example: auto-loading the system disk driver during winpe installer <br />
https://github.com/antnn/win-setup-action-ansible/blob/main/action_plugins/templates/main.cs

GPU passthrough to a virtual machine (KVM skills, sysfs-bus-pci). Without the need to permanently bind in kernel parameters, without host reboots: disconnecting the GPU from the host, connecting it to the guest, after the guest exits reconnecting it back to the host. Without virt-manager and libvirtd. If there is only one GPU, it's better to passthrough the keyboard and mouse.
<br />
https://github.com/antnn/gists/blob/main/qemu/readme.md

Notifications about changes in repos (polling).
<br />
https://github.com/antnn/git-notifier/blob/main/src/main.rs

Uncertainty calculator
<br />
https://stackblitz.com/edit/angularcalc2022?file=src%2Fapp%2Fmodel%2FInstrument.ts

E2E encrypted form (webcrypto, webworker, RSA-OAEP)
<br />
https://valishin.ru/script.js

Also developing a port of softethervpn for AndroidUsing cmake superproject/superbuild for dependency builds (cross compilation)
<br />
https://github.com/antnn/SimpleVirtualNetwork/blob/main/nativevpn/src/main/cpp/deps/build_deps.cmake

My COM C# 0x800706F4 issue
<br />
https://learn.microsoft.com/en-us/answers/questions/1467985/(answered)-inetwork-setcategory(-networkcategory-p
<br />
The solution is in this line without Reflection
<br />
https://github.com/antnn/win-setup-action-ansible/blob/main/action_plugins/templates/main.cs#L1273
