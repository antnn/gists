#!/bin/bash
#cat .local/lookinglass/module/load-kvmfr.sh
( cd $HOME/.local/lookinglass/module/
  echo Building and loading KVMFR module
  make
  sudo insmod kvmfr.ko static_size_mb=256 #4K
)

VMDIR="$HOME/vm/win11"

gpu="0000:07:00.0"
aud="0000:07:00.1"
gpu_vd="$(cat /sys/bus/pci/devices/$gpu/vendor) $(cat /sys/bus/pci/devices/$gpu/device)"
aud_vd="$(cat /sys/bus/pci/devices/$aud/vendor) $(cat /sys/bus/pci/devices/$aud/device)"
echo "gpu_vd=\"$gpu_vd\"" > "$VMDIR/vfio_id"
echo "aud_vd=\"$aud_vd\"" >> "$VMDIR/vfio_id"

function bind_vfio {
  source "$VMDIR/vfio_id"
  if [ -f "/sys/bus/pci/devices/$gpu/driver/unbind" ]; then
    echo "Unbinding GPU: $gpu"
    echo "$gpu" | sudo tee "/sys/bus/pci/devices/$gpu/driver/unbind" > /dev/null
  else
    echo "GPU unbind file not found for $gpu"
  fi
  if [ -f "/sys/bus/pci/devices/$aud/driver/unbind" ]; then
    echo "Unbinding Audio: $aud"
    echo "$aud" | sudo tee "/sys/bus/pci/devices/$aud/driver/unbind" > /dev/null
  else
    echo "Audio unbind file not found for $aud"
  fi
  echo "Binding GPU to vfio-pci: $gpu_vd"
  echo "$gpu_vd" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id > /dev/null
  echo "Binding Audio to vfio-pci: $aud_vd"
  echo "$aud_vd" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id > /dev/null
}

function unbind_vfio {
  source "$VMDIR/vfio_id"
  if [ -f "/sys/bus/pci/drivers/vfio-pci/remove_id" ]; then
    echo "Removing GPU from vfio-pci: $gpu_vd"
    echo "$gpu_vd" | sudo tee "/sys/bus/pci/drivers/vfio-pci/remove_id" > /dev/null
  else
    echo "vfio-pci remove_id file not found for GPU"
  fi
  if [ -f "/sys/bus/pci/drivers/vfio-pci/remove_id" ]; then
    echo "Removing Audio from vfio-pci: $aud_vd"
    echo "$aud_vd" | sudo tee "/sys/bus/pci/drivers/vfio-pci/remove_id" > /dev/null
  else
    echo "vfio-pci remove_id file not found for Audio"
  fi
  echo "Removing GPU device"
  echo 1 | sudo tee "/sys/bus/pci/devices/$gpu/remove" > /dev/null
  echo "Removing Audio device"
  echo 1 | sudo tee "/sys/bus/pci/devices/$aud/remove" > /dev/null
  echo "Rescanning PCI bus"
  echo 1 | sudo tee "/sys/bus/pci/rescan" > /dev/null
  rm "$VMDIR/vfio_id"
}


TPMSTATE="$VMDIR/tpm2"
TPMSOCKET="/run/user/$(id -u)/win11-swtpm.sock"
function tpm() {
   sudo /usr/bin/swtpm socket --ctrl type=unixio,path="$TPMSOCKET,mode=0600" --tpmstate dir="$TPMSTATE,mode=0600" --log file="$HOME/.cache/libvirt/qemu/log/win11-swtpm.log" --terminate --tpm2 &
}

MAINDISK="$VMDIR/win11.qcow2"
NETWORK_DEVICE="virtio-net"
MAC_ADDRESS="00:16:cb:00:21:19"
CPU="host,host-phys-bits-limit=0x28,migratable=on,topoext=on,svm=off,apic=on,hypervisor=on,invtsc=on,hv-time=on,hv-relaxed=on,hv-vapic=on,hv-spinlocks=0x1fff,hv-vpindex=on,hv-synic=on,hv-stimer=on,hv-reset=on,hv-vendor-id=1234567890ab,hv-frequencies=on,kvm=off,host-cache-info=on,l3-cache=off"
# Copy host cpu - Workaround for nested Hyper-V
CPU="Snowridge,vmx=on,fma=on,avx=on,f16c=on,hypervisor=on,ss=on,tsc-adjust=on,bmi1=on,avx2=on,bmi2=on,invpcid=on,adx=on,pku=on,waitpkg=on,vaes=on,vpclmulqdq=on,rdpid=on,fsrm=on,md-clear=on,serialize=on,stibp=on,flush-l1d=on,avx-vnni=on,fsrs=on,xsaves=on,abm=on,ibpb=on,ibrs=on,amd-stibp=on,amd-ssbd=on,rdctl-no=on,ibrs-all=on,skip-l1dfl-vmentry=on,mds-no=on,pschange-mc-no=on,sbdr-ssdp-no=on,fbsdp-no=on,psdp-no=on,gds-no=on,vmx-ins-outs=on,vmx-true-ctls=on,vmx-store-lma=on,vmx-activity-hlt=on,vmx-activity-wait-sipi=on,vmx-vmwrite-vmexit-fields=on,vmx-apicv-xapic=on,vmx-ept=on,vmx-desc-exit=on,vmx-rdtscp-exit=on,vmx-apicv-x2apic=on,vmx-vpid=on,vmx-wbinvd-exit=on,vmx-unrestricted-guest=on,vmx-apicv-register=on,vmx-apicv-vid=on,vmx-rdrand-exit=on,vmx-invpcid-exit=on,vmx-vmfunc=on,vmx-shadow-vmcs=on,vmx-rdseed-exit=on,vmx-pml=on,vmx-xsaves=on,vmx-tsc-scaling=on,vmx-enable-user-wait-pause=on,vmx-ept-execonly=on,vmx-page-walk-4=on,vmx-ept-2mb=on,vmx-ept-1gb=on,vmx-invept=on,vmx-eptad=on,vmx-invept-single-context=on,vmx-invept-all-context=on,vmx-invvpid=on,vmx-invvpid-single-addr=on,vmx-invvpid-all-context=on,vmx-intr-exit=on,vmx-nmi-exit=on,vmx-vnmi=on,vmx-preemption-timer=on,vmx-posted-intr=on,vmx-vintr-pending=on,vmx-tsc-offset=on,vmx-hlt-exit=on,vmx-invlpg-exit=on,vmx-mwait-exit=on,vmx-rdpmc-exit=on,vmx-rdtsc-exit=on,vmx-cr3-load-noexit=on,vmx-cr3-store-noexit=on,vmx-cr8-load-exit=on,vmx-cr8-store-exit=on,vmx-flexpriority=on,vmx-vnmi-pending=on,vmx-movdr-exit=on,vmx-io-exit=on,vmx-io-bitmap=on,vmx-mtf=on,vmx-msr-bitmap=on,vmx-monitor-exit=on,vmx-pause-exit=on,vmx-secondary-ctls=on,vmx-exit-nosave-debugctl=on,vmx-exit-load-perf-global-ctrl=on,vmx-exit-ack-intr=on,vmx-exit-save-pat=on,vmx-exit-load-pat=on,vmx-exit-save-efer=on,vmx-exit-load-efer=on,vmx-exit-save-preemption-timer=on,vmx-entry-noload-debugctl=on,vmx-entry-ia32e-mode=on,vmx-entry-load-perf-global-ctrl=on,vmx-entry-load-pat=on,vmx-entry-load-efer=on,vmx-eptp-switching=on,mpx=off,cldemote=off,core-capability=off,split-lock-detect=off"
args=(
#-display gtk,grab-on-hover=on,full-screen=on
-name guest=windows11,debug-threads=on
-blockdev '{"driver":"file","filename":"/usr/share/edk2/ovmf/OVMF_CODE_4M.secboot.qcow2","node-name":"libvirt-pflash0-storage","auto-read-only":true,"discard":"unmap"}'
-blockdev '{"node-name":"libvirt-pflash0-format","read-only":true,"driver":"qcow2","file":"libvirt-pflash0-storage"}'
-blockdev '{"driver":"file","filename":"'"$VMDIR"'/win11_VARS.qcow2","node-name":"libvirt-pflash1-storage","auto-read-only":true,"discard":"unmap"}'
-blockdev '{"node-name":"libvirt-pflash1-format","read-only":false,"driver":"qcow2","file":"libvirt-pflash1-storage"}'
-machine pc-q35-8.2,vmport=off,smm=on,kernel_irqchip=on,dump-guest-core=off,pflash0=libvirt-pflash0-format,pflash1=libvirt-pflash1-format,hpet=off,acpi=on
-accel kvm
-cpu $CPU
-global driver=cfi.pflash01,property=secure,value=on
-m size=16G
-overcommit mem-lock=off
-smp 32,sockets=1,dies=1,clusters=1,cores=32,threads=1
-no-user-config
-nodefaults
-rtc base=localtime,driftfix=slew
-global kvm-pit.lost_tick_policy=delay
-global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
#-no-shutdown
-global ICH9-LPC.disable_s3=1
-global ICH9-LPC.disable_s4=1
-boot menu=off,strict=on
  -global "ICH9-LPC.disable_s3=1"
  -global "ICH9-LPC.disable_s4=1"
  -boot "menu=on,strict=on"
  -device '{"driver":"pcie-root-port","port":16,"chassis":1,"id":"pci.1","bus":"pcie.0","multifunction":true,"addr":"0x2"}'
  -device '{"driver":"pcie-root-port","port":17,"chassis":2,"id":"pci.2","bus":"pcie.0","addr":"0x2.0x1"}'
  -device '{"driver":"pcie-root-port","port":18,"chassis":3,"id":"pci.3","bus":"pcie.0","addr":"0x2.0x2"}'
  -device '{"driver":"pcie-root-port","port":19,"chassis":4,"id":"pci.4","bus":"pcie.0","addr":"0x2.0x3"}'
  -device '{"driver":"pcie-root-port","port":20,"chassis":5,"id":"pci.5","bus":"pcie.0","addr":"0x2.0x4"}'
  -device '{"driver":"pcie-root-port","port":21,"chassis":6,"id":"pci.6","bus":"pcie.0","addr":"0x2.0x5"}'
  -device '{"driver":"pcie-root-port","port":22,"chassis":7,"id":"pci.7","bus":"pcie.0","addr":"0x2.0x6"}'
  -device '{"driver":"pcie-root-port","port":23,"chassis":8,"id":"pci.8","bus":"pcie.0","addr":"0x2.0x7"}'
  -device '{"driver":"pcie-root-port","port":24,"chassis":9,"id":"pci.9","bus":"pcie.0","multifunction":true,"addr":"0x3"}'
  -device '{"driver":"pcie-root-port","port":25,"chassis":10,"id":"pci.10","bus":"pcie.0","addr":"0x3.0x1"}'
  -device '{"driver":"pcie-root-port","port":26,"chassis":11,"id":"pci.11","bus":"pcie.0","addr":"0x3.0x2"}'
  -device '{"driver":"pcie-root-port","port":27,"chassis":12,"id":"pci.12","bus":"pcie.0","addr":"0x3.0x3"}'
  -device '{"driver":"pcie-root-port","port":28,"chassis":13,"id":"pci.13","bus":"pcie.0","addr":"0x3.0x4"}'
  -device '{"driver":"pcie-root-port","port":29,"chassis":14,"id":"pci.14","bus":"pcie.0","addr":"0x3.0x5"}'
  -device '{"driver":"pcie-root-port","port":30,"chassis":15,"id":"pci.15","bus":"pcie.0","addr":"0x3.0x6"}'
  -device '{"driver":"pcie-pci-bridge","id":"pci.16","bus":"pci.5","addr":"0x0"}'
  -device '{"driver":"qemu-xhci","p2":15,"p3":15,"id":"usb","bus":"pci.2","addr":"0x0"}'
  -device '{"driver":"virtio-serial-pci","id":"virtio-serial0","bus":"pci.3","addr":"0x0"}'
 -blockdev '{"driver":"file","filename":"'"$MAINDISK"'","node-name":"libvirt-3-storage","auto-read-only":true,"discard":"unmap"}'
  -blockdev '{"node-name":"libvirt-3-format","read-only":false,"driver":"qcow2","file":"libvirt-3-storage","backing":null}'
  -device '{"driver":"virtio-blk-pci","bus":"pci.4","addr":"0x0","drive":"libvirt-3-format","id":"virtio-disk0","bootindex":2}'
 # -blockdev {"driver":"file","filename":"$HOME/Downloads/virtio-win-0.1.262.iso","node-name":"libvirt-2-storage","auto-read-only":true,"discard":"unmap"}
 # -blockdev '{"node-name":"libvirt-2-format","read-only":true,"driver":"raw","file":"libvirt-2-storage"}'
 # -device '{"driver":"ide-cd","bus":"ide.0","drive":"libvirt-2-format","id":"sata0-0-0"}'
 # -blockdev {"driver":"file","filename":"$HOME/Windows.iso","node-name":"libvirt-1-storage","auto-read-only":true,"discard":"unmap"}
 # -blockdev '{"node-name":"libvirt-1-format","read-only":true,"driver":"raw","file":"libvirt-1-storage"}'
 # -device '{"driver":"ide-cd","bus":"ide.1","drive":"libvirt-1-format","id":"sata0-0-1","bootindex":1}'
  -chardev "pty,id=charserial0"
  -device '{"driver":"isa-serial","chardev":"charserial0","id":"serial0","index":0}'
  -chardev "spicevmc,id=charchannel0,name=vdagent"
  -device '{"driver":"virtserialport","bus":"virtio-serial0.0","nr":1,"chardev":"charchannel0","id":"channel0","name":"com.redhat.spice.0"}'
  #-device '{"driver":"usb-tablet","id":"input0","bus":"usb.0","port":"1"}'
  -audiodev '{"id":"audio1","driver":"spice"}'
  -spice "port=5900,addr=127.0.0.1,disable-ticketing=on,image-compression=off,seamless-migration=on"
  -device '{"driver":"VGA","id":"video0","vgamem_mb":16,"bus":"pcie.0","addr":"0x1"}'
  -device '{"driver":"ich9-intel-hda","id":"sound0","bus":"pcie.0","addr":"0x1b"}'
  -device '{"driver":"hda-duplex","id":"sound0-codec0","bus":"sound0.0","cad":0,"audiodev":"audio1"}'
  -global "ICH9-LPC.noreboot=off"
  -watchdog-action reset
  -chardev "spicevmc,id=charredir0,name=usbredir"
  -device '{"driver":"usb-redir","chardev":"charredir0","id":"redir0","bus":"usb.0","port":"2"}'
  -chardev "spicevmc,id=charredir1,name=usbredir"
  -device '{"driver":"usb-redir","chardev":"charredir1","id":"redir1","bus":"usb.0","port":"3"}'
  -sandbox "on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny"
  -object '{"qom-type":"memory-backend-file","id":"shmmem-shmem0","mem-path":"/dev/kvmfr0","size":268435456,"share":true}'
  -device '{"driver":"ivshmem-plain","id":"shmem0","memdev":"shmmem-shmem0","bus":"pci.16","addr":"0x1"}'
  -msg "timestamp=on"
  -netdev "user,id=usernet0"
  -device '{"driver":"virtio-net-pci","netdev":"usernet0","id":"net0","mac":"52:54:00:a3:2e:bc","bus":"pci.1","addr":"0x0"}'

# VFIO
# PLEASE NOTE: Attaching to the root PCI bus causes issues in a guest
# We create a separate PCI root port (pcie.6) and attach the devices to that root port instead of the root PCI bus
-device '{"driver":"pcie-root-port","port":6,"id":"pcie.6","bus":"pcie.0","multifunction":true,"addr":"0x6"}'
-device '{"driver":"vfio-pci","host":"0000:07:00.0","id":"gpu","bus":"pcie.6","multifunction":true,"addr":"0x0"}'
-device '{"driver":"vfio-pci","host":"0000:07:00.1","id":"hdmiaudio","bus":"pcie.6","addr":"0x0.0x1"}'
#
-monitor stdio

# TPM
-chardev socket,id=chrtpm,path="$TPMSOCKET"
-tpmdev emulator,id=tpm-tpm0,chardev=chrtpm
-device  '{"driver":"tpm-crb","tpmdev":"tpm-tpm0","id":"tpm0"}'
)
tpm
#bind_vfio
echo -e "After qemu is started, run: \n   sudo chown \$USER:\$USER /dev/kvmfr0 \n   looking-glass-client -f /dev/kvmfr0"
sudo qemu-system-x86_64 "${args[@]}"
sudo rm -rf "$TPMSTATE/"*
#unbind_vfio


