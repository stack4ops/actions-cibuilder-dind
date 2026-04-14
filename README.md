[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-composite-2088FF?logo=github-actions)](action.yml)
[![cibuilder](https://img.shields.io/badge/cibuilder-rootless-blue?logo=docker)](https://github.com/stack4ops/cibuilder)
[![DinD](https://img.shields.io/badge/Docker--in--Docker-required-1D63ED?logo=docker)](https://hub.docker.com/_/docker)

# actions-cibuilder-dind

A composite GitHub Action that runs a [cibuilder](https://github.com/stack4ops/cibuilder) container together with a Docker-in-Docker (DinD) sidecar, connected via a shared Docker network. Required for any [cibuild](https://github.com/stack4ops/cibuild) run that needs a Docker daemon — primarily the **test run** with `TEST_BACKEND=docker`.

> For runs that don't need DinD (check, build, release) use [actions-cibuilder](https://github.com/stack4ops/actions-cibuilder) instead — it is lighter and starts faster.

---

## Usage

```yaml
- uses: actions/checkout@v5
- uses: stack4ops/actions-cibuilder-dind@v1
  with:
    run_cmd: test
```

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_cmd` | ✓ | — | cibuild run command: `check`, `build`, `test`, `release`, or `all` |
| `image` | | `ghcr.io/stack4ops/cibuilder:rootless` | cibuilder image to use |
| `bin_url` | | `""` | Override the cibuild lib download URL (dynamic lib loading) |
| `bin_ref` | | `""` | Override the cibuild lib branch or tag (dynamic lib loading) |

### Environment variables and secrets

All variables matching the following prefixes are forwarded into the cibuilder container automatically:

- `GITHUB_*` — GitHub Actions context
- `ACTIONS_*` — Actions runtime variables
- `CIBUILD_*` — cibuild configuration and secrets
- `CIBUILDER_*` — cibuilder runtime settings

Pass secrets at the job or workflow level:

```yaml
env:
  CIBUILD_TEST_SERVICE_ACCOUNT: ${{ secrets.CIBUILD_TEST_SERVICE_ACCOUNT }}
```

---

## How It Works

`run.sh` creates a dedicated Docker network (`cibuilder-net`) and starts two containers inside it:

1. **`cibuilder-dind`** — a `docker:dind` container with TLS disabled, listening on `tcp://0.0.0.0:2375`, reachable from within the network as `docker`
2. **`cibuilder`** — the cibuilder container, connected to the same network, with the workspace and output directory mounted

```sh
docker network create cibuilder-net

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
  -v "$PWD:/workspace" \
  -v "${RUNNER_TEMP}/cibuild-output:/cibuild-output" \
  -w /workspace \
  --network cibuilder-net \
  --name cibuilder \
  ghcr.io/stack4ops/cibuilder:rootless
```

The cibuild default `CIBUILD_DOCKER_HOST=tcp://docker:2375` matches the DinD network alias exactly — no extra configuration needed. Both containers are `--rm` and the network is cleaned up automatically when the runner is discarded after the job.

---

## When to Use Which Action

| Scenario | Action |
|----------|--------|
| `run_cmd: check` | `actions-cibuilder` |
| `run_cmd: build` | `actions-cibuilder` |
| `run_cmd: test` with `TEST_BACKEND=docker` | **`actions-cibuilder-dind`** |
| `run_cmd: test` with `TEST_BACKEND=kubernetes` | `actions-cibuilder` |
| `run_cmd: release` | `actions-cibuilder` |
| `run_cmd: all` with Docker test backend | **`actions-cibuilder-dind`** |