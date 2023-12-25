default: (build "oakland")

build host:
  just butane --pretty --strict base.bu --output base.ign --files-dir .           
  just butane --pretty --strict modules/adguardhome.bu --output modules/adguardhome.ign --files-dir .           
  just butane --pretty --strict modules/k3s.bu --output modules/k3s.ign --files-dir .           
  just butane --pretty --strict modules/tailscale.bu --output modules/tailscale.ign --files-dir .           
  just butane --pretty --strict hosts/{{host}}.bu --output hosts/{{host}}.ign --files-dir .           
  just validate {{host}}

validate host:
  just ignition-validate hosts/{{host}}.ign && echo "Success"

start host="oakland":
  just build {{host}}
  chcon --verbose --type svirt_home_t hosts/{{host}}.ign
  virt-install --name=fcos --vcpus=2 --ram=2048 --os-variant=fedora-coreos-stable \
      --import --network=bridge=virbr0 --graphics=none \
      --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/hosts/{{host}}.ign" \
      --disk=size=20,backing_store=${PWD}/fedora-coreos.qcow2

stop:
  virsh destroy fcos
  virsh undefine --remove-all-storage fcos

restart: stop start

iso host input:
  just coreos-installer iso customize --dest-device /dev/vda --dest-ignition hosts/{{host}}.ign -o coreos-{{host}}.iso {{input}}

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
