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
  packer-builder-arm init pwnagotchi.pkr.hcl

# Build Packer image
docker run \
  --cpu-shares 4098 \
  --privileged \
  -v /dev:/dev \
  -v ${PWD}:/build \
  -v ${PWD}/../../nexmon:/nexmon \
  -e PACKER_CACHE_DIR=/build/packer_cache \
  -e PACKER_CONFIG_DIR=/build/packer_plugins \
  packer-builder-arm build pwnagotchi.pkr.hcl > ../output.log
