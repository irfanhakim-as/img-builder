# img-builder

img-builder is a lightweight tool for building and publishing container images to an image registry.

## Features

- **Multi-architecture**: Build and publish container images for multiple architectures.
- **Containerised**: [Container image](https://github.com/irfanhakim-as/img-builder/pkgs/container/img-builder) is provided for a simple, reproducible setup.
- **Intuitive**: Super easy to use, while being very configurable.
- **Cross-platform**: Works on Linux, macOS, and Windows (using [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) or the supplied container).
- **Compatibility**: Compatible with various container runtimes and container registries.

## Pre-requisites

The following binaries or packages are required to be present on your system to install or use img-builder:

- `bash`
- `podman`, `docker`, or `nerdctl`
- `realpath`

If you are using an up-to-date system or the provided container image, these should be available by default.

For multi-architecture build support, the following package(s) need to be installed on the host system:

- Arch Linux: `qemu-user-static` and `qemu-user-static-binfmt`
- Debian/Ubuntu: `qemu-user-static`

**Alternatively**, run the following container **once** to enable multi-arch support:

> [!NOTE]  
> Replace `<container-runtime>` with your installed container runtime (i.e. `podman`, `docker`, `nerdctl`).

```sh
<container-runtime> run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p yes
```

If you wish to undo this in the future, run the following command:

```sh
<container-runtime> run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p no
```

If you are facing permission issues, you may need to run the aforementioned commands as `root` using `sudo`.

## Installation

First and foremost, ensure that your system has met all of the documented [pre-requisites](#pre-requisites).

### Container

If you wish to use img-builder as a container, refer to the [examples](#examples) section to deploy a **rootless, privileged** setup.

### Local

If you wish to use img-builder locally, follow these steps to install it on your system:

1. Clone the [img-builder](https://github.com/irfanhakim-as/img-builder) repository to your home directory (i.e. `~/.img-builder`):

    ```sh
    git clone https://github.com/irfanhakim-as/img-builder.git ~/.img-builder
    ```

2. Get the breakdown of the installer options, using the `--help` flag:

    ```sh
    bash ~/.img-builder/installer.sh --help
    ```

3. Install img-builder using the provided installer. By default, this will install to the `~/.local` prefix:

    ```sh
    bash ~/.img-builder/installer.sh
    ```

    You may either change the installation prefix or ensure that it exists and `~/.local/bin` is in your `${PATH}`.

## Examples

Basic rootless, unprivileged setup:

> [!NOTE]  
> Replace `<container-runtime>` with your installed container runtime (i.e. `podman`, `docker`, `nerdctl`).

```sh
<container-runtime> run --rm -it ghcr.io/irfanhakim-as/img-builder:latest sh
```

Rootless, privileged setup with, **optionally**, a complete set of [environment variables](#docker-variables):

> [!IMPORTANT]  
> `--privileged` is required to use some `podman` functionalities, including what is featured in img-builder.

```sh
<container-runtime> run --rm -it --privileged \
-e IMAGE_REGISTRY="ghcr.io" \
-e AUTH_USER="my-user" \
-e AUTH_TOKEN="my-secret-token" \
-e SRC_REPO_URL="https://github.com/example/test.git" \
ghcr.io/irfanhakim-as/img-builder:latest sh
```

For a breakdown of img-builder usage options, use the `--help` flag:

```sh
img-builder --help
```

## Configuration

### Installer Variables

| **Option** | **Description** | **Sample Value** | **Default Value** |
| --- | --- | --- | --- |
| `INSTALL_PFX` | The base installation prefix where files will be installed. | `/usr/local` | `${HOME}/.local` |

### Environment Variables

| **Option** | **Description** | **Sample Value** | **Default Value** |
| --- | --- | --- | --- |
| `BUILD_ENVFILE` | The path to an environment file defining build config variables. | `.build.env` | - |
| `CONTAINER_RUNTIME` | The runtime environment used for container-based operations. | `docker` | `podman`, `docker`, or `nerdctl` |
| `IMAGE_NAME` | The name of the container image. | `my-container` | - |
| `IMAGE_REGISTRY` | The container registry where the image should be published. | `ghcr.io`, `registry.gitlab.com` | `docker.io` |
| `IMAGE_REPOSITORY` | The user account or namespace in the registry where the image will be stored. | `my-user`, `my-user/my-container` | - |
| `IMAGE_TAG` | The tag assigned to the image to indicate its version or build. | `0.1.0-stable-r1` | `latest` |
| `IMAGE_ARCH` | Comma-separated list of target platforms and architectures for the image build. | `linux/amd64,linux/arm/v7,linux/arm64/v8` | `linux/amd64` |
| `IMAGE_CONTEXT` | The build context directory containing the Dockerfile and related files. | `./my-container` | `.` |
| `IMAGE_DOCKERFILE` | The Dockerfile to use for building the image. | `slim-dockerfile` | `Dockerfile` |

### Docker Variables

| **Option** | **Description** | **Sample Value** | **Default Value** |
| --- | --- | --- | --- |
| `IMAGE_REGISTRY` | The container registry where the image should be published. | `ghcr.io`, `registry.gitlab.com` | `docker.io` |
| `AUTH_USER` | The username for authenticating with the image registry. | `my-user` | - |
| `AUTH_TOKEN` | The authentication token or password for the image registry. | `my-secret-token` | - |
| `SRC_REPO_URL` | The URL of a repository to clone into the container. | `https://github.com/example/test.git` | - |

## License

This project is licensed under the [AGPL-3.0-only](https://choosealicense.com/licenses/agpl-3.0) license. Please refer to the [LICENSE](LICENSE) file for more information.
