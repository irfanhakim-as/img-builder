# img-builder

img-builder is a lightweight tool for building and publishing container images to an image registry.

## Features

- **Multi-architecture**: Build and publish container images for multiple architectures.
- **Containerised**: [Container image](https://github.com/irfanhakim-as/img-builder/pkgs/container/img-builder) is provided for a reproducible setup.
- **Intuitive**: Super easy to use, while being very configurable.

## Examples

> [!NOTE]  
> Replace `<container-runtime>` with your installed container runtime (i.e. `podman`, `docker`, `nerdctl`).

Basic rootless, unprivileged setup:

```sh
<container-runtime> run --rm -it ghcr.io/irfanhakim-as/img-builder:latest sh
```

Rootless, privileged setup with, **optionally**, a complete set of [environment variables](#docker-variables):

> [!IMPORTANT]  
> `--privileged` is required to use some `podman` functionalities, including what is featured in img-builder.

```sh
<container-runtime> run --rm -it \
--privileged \
-e IMAGE_REGISTRY="ghcr.io" \
-e AUTH_USER="my-user" \
-e AUTH_TOKEN="my-secret-token" \
-e SRC_REPO_URL="https://github.com/example/test.git" \
ghcr.io/irfanhakim-as/img-builder:latest \
sh
```

For a full list of configuration options, use the `--help` flag:

```sh
img-builder --help
```

## Configuration

### Environment Variables

| **Option** | **Description** | **Sample Value** | **Default Value** |
| --- | --- | --- | --- |
| `IMAGE_NAME` | The name of the container image. | `my-container` | - |
| `IMAGE_REGISTRY` | The container registry where the image should be published. | `ghcr.io`, `registry.gitlab.com` | `docker.io` |
| `IMAGE_REPOSITORY` | The user account or namespace in the registry where the image will be stored. | `my-user`, `my-user/my-container` | - |
| `IMAGE_VERSION` | The tag assigned to the image to indicate its version or build. | `0.1.0-stable-r1` | `latest` |
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
