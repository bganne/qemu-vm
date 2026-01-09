IMAGE=debian-13-generic-amd64.qcow2
URL=https://cdimage.debian.org/cdimage/cloud/trixie/latest
LOCALHOST=127.1.1.1
BRIDGE=vmtest0
BRIDGE_IP=192.168.100.1/24
TAP1=vmtap1
TAP2=vmtap2

all: run

$(IMAGE):
	wget "$(URL)/$(IMAGE)"

cloud-init.raw: cloud-init/meta-data cloud-init/user-data
	truncate -s 10M "$@"
	/usr/sbin/mkfs.vfat "$@"
	mlabel -i "$@" ::cidata
	mcopy -i "$@" cloud-init/meta-data cloud-init/user-data ::

data.raw:
	truncate -s 20G "$@"
	/usr/sbin/mke2fs -t ext4 -F "$@"

data.qcow2: data.raw
	qemu-img convert -f raw -O qcow2 -c -o compression_type=zstd "$<" "$@"

sys.qcow2: $(IMAGE)
	qemu-img create -f qcow2 -F qcow2 -b "$^" "$@"

run: sys.qcow2 data.qcow2 cloud-init.raw FORCE
	BRIDGE=$(BRIDGE) BRIDGE_IP=$(BRIDGE_IP) \
	sudo -E setpriv --reuid=$(USER) --regid=$(shell id -g) --init-groups \
		--inh-caps=+net_admin --ambient-caps=+net_admin \
		qemu-system-x86_64 \
		-enable-kvm \
		-cpu host,migratable=off \
		-smp $(shell nproc),sockets=1,cores=$(shell nproc),threads=1 \
		-m 16G \
		-nographic \
		-serial mon:stdio \
		-monitor telnet::1111,server,nowait \
		-object iothread,id=io0 \
		-object iothread,id=io1 \
		-drive file="sys.qcow2",if=none,id=drive0,format=qcow2,cache=none,aio=io_uring \
		-device virtio-blk-pci,drive=drive0,iothread=io0,num-queues=4 \
		-drive file="data.qcow2",if=none,id=drive1,format=qcow2,cache=none,aio=io_uring \
		-device virtio-blk-pci,drive=drive1,iothread=io1,num-queues=4 \
		-drive file="cloud-init.raw",index=2,format=raw,cache=none,aio=io_uring,if=virtio \
		-virtfs local,path="$(HOME)",mount_tag=host,readonly=on,security_model=none \
		-nic user,model=virtio,hostfwd=tcp:$(LOCALHOST):2222-:22,hostfwd=tcp:$(LOCALHOST):4443-:443 \
		-netdev tap,id=net1,script=qemu-ifup.sh,downscript=qemu-ifdown.sh,vhost=on,queues=4 \
		-device virtio-net-pci,netdev=net1,mq=on,vectors=10 \
		-netdev tap,id=net2,script=qemu-ifup.sh,downscript=qemu-ifdown.sh,vhost=on,queues=4 \
		-device virtio-net-pci,netdev=net2,mq=on,vectors=10

ssh: FORCE
	ssh -i id_debian_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p2222 debian@$(LOCALHOST)

mon: FORCE
	telnet localhost 1111

clean: FORCE
	$(RM) -r sys.qcow2 data.qcow2 data.raw

distclean: clean
	$(RM) $(IMAGE) cloud-init.raw

.PHONY: FORCE
