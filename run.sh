#!/usr/bin/env bash
set -euo pipefail

sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

export CIBUILD_RUN_CMD="$1"
export CIBUILDER_BIN_URL="$2"
export CIBUILDER_BIN_REF="$3"
IMAGE="$4"

CIBUILD_OUTPUT="${RUNNER_TEMP:-/tmp}/cibuild-output"
mkdir -p "${CIBUILD_OUTPUT}"
chmod 1777 "${CIBUILD_OUTPUT}"

env | grep '^GITHUB_' > github.env
env | grep '^ACTIONS_' >> github.env
env | grep '^CIBUILD_' >> github.env
env | grep '^CIBUILDER_' >> github.env
echo "CIBUILD_OUTPUT_DIR=/cibuild-output" >> github.env

sudo chown -R 1000:1000 "$PWD"

docker network create cibuilder-net

docker network inspect cibuilder-net

docker run --privileged --rm -d \
  -e DOCKER_HOST=tcp://0.0.0.0:2375 \
  -e DOCKER_TLS_VERIFY= \
  -e DOCKER_TLS_CERTDIR= \
  --network cibuilder-net \
  --network-alias docker \
  --name cibuilder-dind \
  docker:dind

docker run --privileged --rm \
  --env-file github.env \
  -e DOCKER_HOST=tcp://docker:2375 \
  -v "$PWD:/workspace" \
  -v "${CIBUILD_OUTPUT}:/cibuild-output" \
  -w /workspace \
  --network cibuilder-net \
  --name cibuilder \
  "$IMAGE"
