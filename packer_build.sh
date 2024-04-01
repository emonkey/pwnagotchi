docker build -t packer-builder-arm-arm64 ../packer-plugin-arm-image

cd builder

# Install necessary Packer plugins
docker run \
  --rm \
  --privileged \
  -v /dev:/dev \
  -v ${PWD}:/build \
  -e PACKER_CACHE_DIR=/build/packer_cache \
  -e PACKER_CONFIG_DIR=/build/packer_plugins \
  packer-builder-arm-arm64 init pwnagotchi.pkr.hcl

# Build Packer image
docker run \
  --rm \
  --privileged \
  -v /dev:/dev \
  -v ${PWD}:/build \
  -e PACKER_CACHE_DIR=/build/packer_cache \
  -e PACKER_CONFIG_DIR=/build/packer_plugins \
  packer-builder-arm-arm64 build pwnagotchi.pkr.hcl
