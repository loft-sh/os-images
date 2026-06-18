# Build an mdraid-ready Ubuntu cloud image.
#
#   make compressed                  # full pipeline -> compressed qcow2
#   make UBUNTU_RELEASE=jammy image  # pick a different release via var

export LIBGUESTFS_BACKEND := direct

UBUNTU_RELEASE   ?= noble
UBUNTU_ARCH      ?= amd64

BASE_IMAGE_URL   ?= https://cloud-images.ubuntu.com/$(UBUNTU_RELEASE)/current/$(UBUNTU_RELEASE)-server-cloudimg-$(UBUNTU_ARCH).img
BASE_IMAGE       ?= $(UBUNTU_RELEASE)-server-cloudimg-$(UBUNTU_ARCH).img
TARGET_IMAGE     ?= $(UBUNTU_RELEASE)-mdraid-$(UBUNTU_ARCH).qcow2

MDADM_CONF       ?= mdadm.conf

.PHONY: all base image clean clobber

all: image

base: $(BASE_IMAGE)
image: $(TARGET_IMAGE)

$(BASE_IMAGE):
	curl -fSL -o $@ $(BASE_IMAGE_URL)

$(TARGET_IMAGE): $(BASE_IMAGE) $(MDADM_CONF)
	cp $(BASE_IMAGE) $@
	virt-customize -a $@ \
		--run-command 'apt-get update' \
		--run-command 'DEBIAN_FRONTEND=noninteractive apt-get install -y mdadm' \
		--run-command 'mkdir -p /etc/mdadm' \
		--upload $(MDADM_CONF):/etc/mdadm/mdadm.conf \
		--run-command 'update-initramfs -u -k all' \
		--run-command 'update-grub' \
		--run-command 'apt-get clean' \
		--run-command 'rm -rf /var/lib/apt/lists/*'
	virt-sparsify --in-place $@

clean:
	rm -f $(TARGET_IMAGE)

clobber: clean
	rm -f $(BASE_IMAGE)
