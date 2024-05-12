# VM with GPU passthrough
#### [ROG-STRIX-RX560-4G-V2-GAMING](https://rog.asus.com/graphics-cards/graphics-cards/rog-strix/rog-strix-rx560-4g-v2-gaming-model/helpdesk_download/) 

##### Add to Linux host Kernel args
```bash
cat /proc/cmdline
rd.driver.pre=vfio_pci rd.driver.pre=vfio-pciwq iommu=pt intel_iommu=on kvm.ignore_msrs=1 

sudo rpm-ostree initramfs \
  --enable \
  --arg="--add-drivers" \
  --arg="vfio-pci" \
  --reboot
```
##### Start VM
```bash
# as Root
gpu="0000:06:00.0"
aud="0000:06:00.1"
gpu_vd="$(cat /sys/bus/pci/devices/$gpu/vendor) $(cat /sys/bus/pci/devices/$gpu/device)"
aud_vd="$(cat /sys/bus/pci/devices/$aud/vendor) $(cat /sys/bus/pci/devices/$aud/device)"

function bind_vfio {
  echo "$gpu" > "/sys/bus/pci/devices/$gpu/driver/unbind"
  echo "$aud" > "/sys/bus/pci/devices/$aud/driver/unbind"

# https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-pci
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

bind_vfio

#QEMU emulator version 8.2.2 (qemu-8.2.2-1.fc40)
NETWORK_DEVICE="virtio-net"
MAC_ADDRESS="00:16:cb:00:21:19"
# 0x28 - Raptor Lake fix. https://github.com/tianocore/edk2/discussions/4662
CPU="host,host-phys-bits-limit=0x28"
args=(
-display gtk,grab-on-hover=on,full-screen=on
-machine q35
-accel kvm
-cpu $CPU
-m size=17338368k
-overcommit mem-lock=off
-smp 32,sockets=1,dies=1,clusters=1,cores=32,threads=1
-no-user-config
-nodefaults
-rtc base=localtime,driftfix=slew
-global kvm-pit.lost_tick_policy=delay
-global ICH9-LPC.disable_s3=1
-global ICH9-LPC.disable_s4=1
-boot menu=off,strict=on
-device qemu-xhci,id=xhci
# VFIO 
# VERY IMPORTANT PART. PLEASE NOTE THE FORMAT OF COMMAND
# id":"pci.5","bus":"pcie.0","addr":"0x2.0x4" and "id":"pci.6","bus":"pcie.0","addr":"0x2.0x5"
-device pcie-root-port,bus=pcie.0,id=pci_root,multifunction=true,addr=0x2
-device '{"driver":"pcie-root-port","port":20,"chassis":5,"id":"pci.5","bus":"pcie.0","addr":"0x2.0x4"}'
-device '{"driver":"pcie-root-port","port":21,"chassis":6,"id":"pci.6","bus":"pcie.0","addr":"0x2.0x5"}'
-device '{"driver":"vfio-pci","host":"0000:06:00.0","id":"gpu","bus":"pci.5","addr":"0x0"}'
-device '{"driver":"vfio-pci","host":"0000:06:00.1","id":"hdmiaudio","bus":"pci.6","addr":"0x0"}'
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
qemu-system-x86_64 "${args[@]}"

unbind_vfio
```

