#!/bin/sh
# Boot Debian VM, install pwsh, enable SSH remoting, start hello.ps1 in the background.
set -eu
cd "$(dirname "$0")"
PORT=8642
[ -f key ] || ssh-keygen -q -t ed25519 -N '' -C tracepoint -f key
mkdir -p run/seed
rm -f run/disk.qcow2  # fresh overlay each run: cloud-init only runs on first boot
qemu-img create -q -f qcow2 -F qcow2 \
  -b "$PWD/cache/img/debian-13-genericcloud-arm64.qcow2" run/disk.qcow2 8G
ln -sf "$PWD/cache/pwsh/powershell-7.6.5-linux-arm64.tar.gz" run/seed/pwsh.tar.gz
echo "instance-id: tracepoint" > run/seed/meta-data
: > run/seed/vendor-data; printf "version: 2\nethernets:\n  all: {match: {name: \"e*\"}, dhcp4: true}\n" > run/seed/network-config
cat > run/seed/user-data <<YAML
#cloud-config
users:
  - name: dbg
    shell: /bin/bash
    ssh_authorized_keys: ["$(cat key.pub)"]
write_files:
  - path: /etc/ssh/sshd_config.d/pwsh.conf
    content: "Subsystem powershell /opt/pwsh/pwsh -sshs -NoLogo\n"
  - path: /opt/hello.ps1
    encoding: b64
    content: $(base64 -w0 hello.ps1)
runcmd:
  - mkdir -p /opt/pwsh && curl -sf http://10.0.2.2:$PORT/pwsh.tar.gz | tar xz -C /opt/pwsh
  # no libicu in the image: run .NET in invariant-globalization mode
  - [sed, -i, 's/"configProperties": {/&"System.Globalization.Invariant": true,/', /opt/pwsh/pwsh.runtimeconfig.json]
  - systemctl reload ssh
  - systemd-run --unit=hello --uid=dbg /opt/pwsh/pwsh -NoLogo -NoProfile -File /opt/hello.ps1
YAML

python3 -I -m http.server $PORT -b 127.0.0.1 -d run/seed >run/http.log 2>&1 & HTTP=$!
trap 'kill $HTTP' EXIT
# KVM if accessible (user in 'kvm' group), else slow TCG emulation
if [ -w /dev/kvm ]; then ACC='-accel kvm -cpu host'; else ACC='-accel tcg,thread=multi -cpu max,pauth-impdef=on'; fi
qemu-system-aarch64 -machine virt $ACC -smp 4 -m 1536 \
  -bios /usr/share/qemu/edk2-aarch64-code.fd \
  -drive if=virtio,file=run/disk.qcow2 \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
  -smbios "type=1,serial=ds=nocloud;s=http://10.0.2.2:$PORT/" \
  -display none -serial file:run/console.log -daemonize -pidfile run/qemu.pid

t=$(date +%s)
until ssh -q -i key -p 2222 -o BatchMode=yes -o ConnectTimeout=3 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    dbg@127.0.0.1 'pgrep -af hello.ps1' 2>/dev/null; do sleep 3; done
echo "ready after $(( $(date +%s) - t ))s"
