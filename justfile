default: (build "base")

build target:
  just butane --pretty --strict {{target}}.bu --output {{target}}.ign            
  just validate {{target}}

validate target:
  just ignition-validate {{target}}.ign && echo "Success"

start target="base":
  just build {{target}}
  chcon --verbose --type svirt_home_t {{target}}.ign
  virt-install --name=fcos --vcpus=2 --ram=2048 --os-variant=fedora-coreos-stable \
      --import --network=bridge=virbr0 --graphics=none \
      --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/{{target}}.ign" \
      --disk=size=20,backing_store=${PWD}/fedora-coreos.qcow2

destroy:
  virsh destroy fcos
  virsh undefine --remove-all-storage fcos

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
