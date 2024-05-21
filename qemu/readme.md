# VM with GPU passthrough without reboots
Works even with one GPU in the system. Just hit `Crtl+ALt+F` two times if you have issues with mouse in guest (toggle input grab)</br>
You may also need to passtrhough usb input devices 
##### Add to Linux host Kernel args
```bash
# Prevent guest BSOD kvm.ignore_msrs=1 (pcmark, cpuz) 
cat /proc/cmdline
rd.driver.pre=vfio_pci rd.driver.pre=vfio-pciwq iommu=pt intel_iommu=on kvm.ignore_msrs=1 
```
##### Add `vfio-pci` to `initramfs` 
##### Start QEMU VM
```bash
#!/bin/bash
# as root
gpu="0000:06:00.0"
aud="0000:06:00.1"
gpu_vd="$(cat /sys/bus/pci/devices/$gpu/vendor) $(cat /sys/bus/pci/devices/$gpu/device)"
aud_vd="$(cat /sys/bus/pci/devices/$aud/vendor) $(cat /sys/bus/pci/devices/$aud/device)"

# Passthrough without reboot
# https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-pci
function bind_vfio {
  echo "$gpu" > "/sys/bus/pci/devices/$gpu/driver/unbind"
  echo "$aud" > "/sys/bus/pci/devices/$aud/driver/unbind"
  echo "$gpu_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
  echo "$aud_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
}

function unbind_vfio {
  echo "$gpu_vd" > "/sys/bus/pci/drivers/vfio-pci/remove_id"
  echo "$aud_vd" > "/sys/bus/pci/drivers/vfio-pci/remove_id"
  echo 1 > "/sys/bus/pci/devices/$gpu/remove"
  echo 1 > "/sys/bus/pci/devices/$aud/remove"
  echo 1 > "/sys/bus/pci/rescan"
}

# Tested on QEMU emulator version 8.2.2 (qemu-8.2.2-1.fc40) and AMD GPU
NETWORK_DEVICE="virtio-net"
MAC_ADDRESS="00:16:cb:00:21:19"
# 0x28 - Raptor Lake fix. https://github.com/tianocore/edk2/discussions/4662
CPU="host,host-phys-bits-limit=0x28"
CORES=32
RAM="16G"

args=(
-display gtk,grab-on-hover=on,full-screen=on
-machine q35
-accel kvm
-cpu $CPU
-m $RAM
-overcommit mem-lock=off
-smp $CORES,sockets=1,dies=1,clusters=1,cores=$CORES,threads=1
-no-user-config
-nodefaults
-rtc base=localtime,driftfix=slew
-global kvm-pit.lost_tick_policy=delay
-global ICH9-LPC.disable_s3=1
-global ICH9-LPC.disable_s4=1
-boot menu=off,strict=on
-device qemu-xhci,id=xhci
# VFIO 
# PLEASE NOTE: Attaching to the root PCI bus causes issues in a guest
# We create a separate PCI root port (pcie.6) and attach the devices to that root port instead of the root PCI bus
-device '{"driver":"pcie-root-port","port":6,"chassis":1,"id":"pcie.6","bus":"pcie.0","multifunction":true,"addr":"0x6"}'
-device '{"driver":"vfio-pci","host":"0000:06:00.0","id":"gpu","bus":"pcie.6","multifunction":true,"addr":"0x0"}'
-device '{"driver":"vfio-pci","host":"0000:06:00.1","id":"hdmiaudio","bus":"pcie.6","addr":"0x0.0x1"}'
# USB_DEV_PASSTHROUGH
#-device usb-host,vendorid=$vendorid_mouse,productid=$product_mouse
#-device usb-host,vendorid=$vendorid_kbd,productid=$product_kbd
#
-drive id=HDD,if=virtio,file="$HDD",format=qcow2
# Network
-netdev user,id=net0
-device "$NETWORK_DEVICE",netdev=net0,id=net0,mac="$MAC_ADDRESS"
#
-device virtio-serial-pci
-usb
-device usb-kbd
-device usb-tablet
-monitor stdio
# Audio
-audiodev   pa,id=aud1,server="/run/user/1000/pulse/native"
-device ich9-intel-hda
-device hda-duplex,audiodev=aud1
#
-device qxl-vga,vgamem_mb=128,vram_size_mb=128
-device virtio-balloon-pci
)

bind_vfio
qemu-system-x86_64 "${args[@]}"
unbind_vfio
```


