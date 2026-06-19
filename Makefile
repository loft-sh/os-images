# Build an mdraid-ready Ubuntu cloud image.
#
#   make compressed                  # full pipeline -> compressed qcow2
#   make UBUNTU_RELEASE=jammy image  # pick a different release via var

export LIBGUESTFS_BACKEND := direct

UBUNTU_RELEASE   ?= noble
UBUNTU_ARCH      ?= amd64

BASE_IMAGE_URL   ?= https://cloud-images.ubuntu.com/$(UBUNTU_RELEASE)/current/$(UBUNTU_RELEASE)-server-cloudimg-$(UBUNTU_ARCH).img
BASE_IMAGE       ?= $(UBUNTU_RELEASE)-server-cloudimg-$(UBUNTU_ARCH).img
TARGET_IMAGE     ?= $(UBUNTU_RELEASE)-server-cloudimg-$(UBUNTU_ARCH)-mdraid.img

MDADM_CONF       ?= mdadm.conf

RELEASE_TAG      ?=
RELEASE_ARCH     ?= amd64 arm64
RELEASE_IMAGES   := $(foreach a,$(RELEASE_ARCH),$(UBUNTU_RELEASE)-server-cloudimg-$(a)-mdraid.img)

.PHONY: all base image release clean clobber

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

# Upload images to an existing release named RELEASE_TAG and set its notes -
# it never builds and never creates the release. The release (created from any
# branch, in the UI or via 'gh release create') is the trigger; CI builds each
# arch natively, copies the resulting $(RELEASE_IMAGES) here, then runs this.
# RELEASE_ARCH tokens must match Ubuntu's cloud-image arch naming (amd64, arm64).
release:
	@test -n "$(RELEASE_TAG)" || { echo "set RELEASE_TAG, e.g. make release RELEASE_TAG=v20260618"; exit 1; }
	@for img in $(RELEASE_IMAGES); do \
		test -f $$img || { echo "missing $$img - build it with 'make image UBUNTU_ARCH=<arch>' and copy it here"; exit 1; }; \
	done
	gh release upload $(RELEASE_TAG) $(RELEASE_IMAGES) --clobber
	gh release edit $(RELEASE_TAG) \
		--notes "$$(printf '## SHA256\n```\n%s\n```' "$$(sha256sum $(RELEASE_IMAGES))")"

clean:
	rm -f $(TARGET_IMAGE) $(RELEASE_IMAGES)

clobber: clean
	rm -f $(BASE_IMAGE)
