default: (build "oakland")

build target:
  just butane --pretty --strict base.bu --output base.ign --files-dir .           
  just butane --pretty --strict modules/adguardhome.bu --output modules/adguardhome.ign --files-dir .           
  just butane --pretty --strict modules/k3s.bu --output modules/k3s.ign --files-dir .           
  just butane --pretty --strict hosts/{{target}}.bu --output hosts/{{target}}.ign --files-dir .           
  just validate {{target}}

validate target:
  just ignition-validate hosts/{{target}}.ign && echo "Success"

start target="oakland":
  just build {{target}}
  chcon --verbose --type svirt_home_t hosts/{{target}}.ign
  virt-install --name=fcos --vcpus=2 --ram=2048 --os-variant=fedora-coreos-stable \
      --import --network=bridge=virbr0 --graphics=none \
      --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/hosts/{{target}}.ign" \
      --disk=size=20,backing_store=${PWD}/fedora-coreos.qcow2

stop:
  virsh destroy fcos
  virsh undefine --remove-all-storage fcos

restart: stop start

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
