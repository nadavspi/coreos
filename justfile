default: (build "oakland")

base: 
  just butane --pretty --strict base.bu --output base.ign --files-dir .           
  virt-install --name=coreos --vcpus=2 --ram=2048 --os-variant=fedora-coreos-stable \
      --import --network=bridge=virbr0 --graphics=none \
      --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/base.ign" \
      --disk=size=20,backing_store=${PWD}/fedora-coreos.qcow2
  
build host:
  just butane --pretty --strict base.bu --output base.ign --files-dir .           
  just butane --pretty --strict modules/adguardhome.bu --output modules/adguardhome.ign --files-dir .           
  just butane --pretty --strict modules/k3s.bu --output modules/k3s.ign --files-dir .           
  just butane --pretty --strict modules/k3s-join.bu --output modules/k3s-join.ign --files-dir .           
  just butane --pretty --strict modules/tailscale.bu --output modules/tailscale.ign --files-dir .           
  just butane --pretty --strict hosts/{{host}}.bu --output hosts/{{host}}.ign --files-dir .           
  just validate {{host}}

validate host:
  just ignition-validate hosts/{{host}}.ign && echo "Success"

start host="oakland":
  just build {{host}}
  chcon --verbose --type svirt_home_t hosts/{{host}}.ign
  virt-install --name=coreos --vcpus=2 --ram=2048 --os-variant=fedora-coreos-stable \
      --import --network=bridge=virbr0 --graphics=none \
      --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/hosts/{{host}}.ign" \
      --disk=size=20,backing_store=${PWD}/fedora-coreos.qcow2

stop:
  virsh destroy coreos
  virsh undefine --remove-all-storage coreos

restart: stop start

# vda for vm
iso host dev="/dev/sda" input="fedora-coreos-39.20231119.3.0-live.x86_64.iso":
  just coreos-installer iso customize --dest-device {{dev}} --dest-ignition hosts/{{host}}.ign -o coreos-{{host}}.iso {{input}}

butane +ARGS: 
  podman run --rm --interactive       \
           --security-opt label=disable        \
           --volume ${PWD}:/pwd --workdir /pwd \
           quay.io/coreos/butane:release {{ARGS}}

ignition-validate +ARGS:
  podman run --rm --interactive       \
                           --security-opt label=disable        \
                           --volume ${PWD}:/pwd --workdir /pwd \
                           quay.io/coreos/ignition-validate:release {{ARGS}}

coreos-installer +ARGS:
  podman run --pull=always            \
        --rm --interactive                  \
        --security-opt label=disable        \
        --volume ${PWD}:/pwd --workdir /pwd \
        quay.io/coreos/coreos-installer:release {{ARGS}}

config-kubectl:
  scp 192.168.1.187:/etc/rancher/k3s/k3s.yaml .
  sed -i "s/127\.0\.0\.1/192\.168\.1\.187/" k3s.yaml

copy-token host:
  op read "op://Personal/k3s node token/password" | ssh {{host}} "cat > token"
