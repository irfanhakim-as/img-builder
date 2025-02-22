#!/usr/bin/env bash

# print help message
function print_help() {
    echo "Usage: ${0} [options]"; echo
    echo "OPTIONS:"
    echo "  -h, --help                   Print help message"
    echo "  -a, --arch <arch>[,<arch>]   Specify at least a single architecture"
    echo "  -e, --env <envfile>          Specify an environment file"
    echo "  -f, --file <dockerfile>      Specify a Dockerfile"
    echo "  -r, --runtime <runtime>      Specify a container runtime"
    echo "  -v, --version <version>      Specify the container image version"
}

# get optional argument
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -h|--help)
            print_help
            exit 0
            ;;
        -a|--arch)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify at least a single architecture"
                exit 1
            fi
            IMAGE_ARCH="${2}"
            shift
            ;;
        -e|--env)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify an environment file"
                exit 1
            fi
            BUILD_ENVFILE="${2}"
            shift
            ;;
        -f|--file)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify a Dockerfile"
                exit 1
            fi
            IMAGE_DOCKERFILE="${2}"
            shift
            ;;
        -r|--runtime)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify a container runtime"
                exit 1
            fi
            CONTAINER_RUNTIME="${2}"
            shift
            ;;
        -v|--version)
            if [ -z "${2}" ]; then
                echo "ERROR: Please specify the container image version"
                exit 1
            fi
            IMAGE_VERSION="${2}"
            shift
            ;;
        *)
            echo "ERROR: Invalid argument (${1})"
            exit 1
            ;;
    esac
    shift
done

# source env file if supplied
if [ -n "${BUILD_ENVFILE}" ] && [ -f "${BUILD_ENVFILE}" ]; then
    source "$(realpath "${BUILD_ENVFILE}")"
fi

# determine container runtime only if not set
if [ -z "${CONTAINER_RUNTIME}" ]; then
    readonly RUNTIME_OPTS=("podman" "docker" "nerdctl")
    for runtime in "${RUNTIME_OPTS[@]}"; do
        if [ -x "$(command -v ${runtime})" ]; then
            readonly CONTAINER_RUNTIME="${runtime}"
            break
        fi
    done
    if [ -z "${CONTAINER_RUNTIME}" ]; then
        echo "ERROR: You must have a supported container runtime installed"
        exit 1
    fi
else
    # check if specified container runtime is installed
    if [ ! -x "$(command -v ${CONTAINER_RUNTIME})" ]; then
        echo "ERROR: Specified container runtime is not installed (${CONTAINER_RUNTIME})"
        exit 1
    fi
fi

# ask for image name until it is set
while [ -z "${IMAGE_NAME}" ]; do
    read -p "Enter image name: " IMAGE_NAME
done

# ask for image registry if not set
if [ -z "${IMAGE_REGISTRY}" ]; then
    read -p "Enter image registry [ghcr.io]: " IMAGE_REGISTRY
fi

# ask for image repository if not set
if [ -z "${IMAGE_REPOSITORY}" ]; then
    read -p "Enter image repository [irfanhakim-as]: " IMAGE_REPOSITORY
fi

# ask for image version if not set
if [ -z "${IMAGE_VERSION}" ]; then
    read -p "Enter image version [latest]: " IMAGE_VERSION
fi

# ask for image architecture if not set
if [ -z "${IMAGE_ARCH}" ]; then
    read -p "Enter image architecture(s) [linux/amd64]: " IMAGE_ARCH
fi

# ask for image dockerfile if not set
if [ -z "${IMAGE_DOCKERFILE}" ]; then
    read -p "Enter image Dockerfile [Dockerfile]: " IMAGE_DOCKERFILE
fi

readonly IMAGE_REGISTRY="${IMAGE_REGISTRY:-"ghcr.io"}"
readonly IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-"irfanhakim-as"}"
readonly IMAGE_VERSION="${IMAGE_VERSION:-"latest"}"
readonly IMAGE_PATH="${IMAGE_PATH:-"${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}"}"
IFS="," read -ra IMAGE_ARCH <<< "${IMAGE_ARCH:-"linux/amd64"}"
readonly IMAGE_DOCKERFILE="${IMAGE_DOCKERFILE:-"Dockerfile"}"
IMAGE_BUILDS=()

echo "#====== Building ${IMAGE_NAME} v${IMAGE_VERSION} at $(date +"%T") ======#"

# ${CONTAINER_RUNTIME} build --platform linux/amd64 -t "${IMAGE_NAME}":latest -f "${IMAGE_DOCKERFILE}" . \
# && ${CONTAINER_RUNTIME} images \
# && ${CONTAINER_RUNTIME} tag "${IMAGE_NAME}":latest "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}" \
# && ${CONTAINER_RUNTIME} push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}" \
# && ${CONTAINER_RUNTIME} rmi "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}"

# build and publish image for each platform
for platform in "${IMAGE_ARCH[@]}"; do
    os="${platform%%/*}"
    arch="${platform#*/}"
    arch_name="${arch%%/*}"
    arch_version="${arch#*/}"; if [[ "${arch_version}" == "${arch_name}" ]]; then arch_version=""; fi
    image_tag="${IMAGE_PATH}-${os}-${arch//\//-}"
    if [[ -z "${os}" || -z "${arch}" ]]; then
        echo "WARN: Invalid platform format \"${platform}\". Skipping..."
        continue
    fi
    # publish each image with its own tag
    if ${CONTAINER_RUNTIME} build --platform "${platform}" -t "${IMAGE_REGISTRY}/${image_tag}" -f "${IMAGE_DOCKERFILE}" .; then
        if [[ "$(${CONTAINER_RUNTIME} inspect --format '{{ .Os }}/{{ .Architecture }}' ${IMAGE_REGISTRY}/${image_tag})" == "${os}/${arch_name}" ]]; then
            if ${CONTAINER_RUNTIME} push "${IMAGE_REGISTRY}/${image_tag}"; then
                IMAGE_BUILDS+=("${IMAGE_REGISTRY}/${image_tag}")
            fi
        else
            echo "WARN: Platform mismatch for ${image_tag}. Skipping..."
            ${CONTAINER_RUNTIME} rmi "${IMAGE_REGISTRY}/${image_tag}"
        fi
    fi
    # store each image locally
    # if ${CONTAINER_RUNTIME} build --platform "${platform}" -t "${image_tag}" -f "${IMAGE_DOCKERFILE}" .; then
    #     IMAGE_BUILDS+=("containers-storage:localhost/${image_tag}")
    # fi
done

# publish manifest of built images
if [[ ${#IMAGE_BUILDS[@]} -gt 0 ]]; then
    if ${CONTAINER_RUNTIME} manifest inspect "${IMAGE_REGISTRY}/${IMAGE_PATH}" > /dev/null 2>&1; then
        ${CONTAINER_RUNTIME} manifest rm "${IMAGE_REGISTRY}/${IMAGE_PATH}"
    fi
    ${CONTAINER_RUNTIME} manifest create "${IMAGE_REGISTRY}/${IMAGE_PATH}" "${IMAGE_BUILDS[@]}" \
    && ${CONTAINER_RUNTIME} manifest push "${IMAGE_REGISTRY}/${IMAGE_PATH}" \
    && ${CONTAINER_RUNTIME} manifest rm "${IMAGE_REGISTRY}/${IMAGE_PATH}"
fi

if [ ${?} -eq 0 ]; then
    echo "#====== Build ${IMAGE_NAME} v${IMAGE_VERSION} pushed to ${IMAGE_REGISTRY} at $(date +"%T") ======#"
else
    echo "#====== Build ${IMAGE_NAME} v${IMAGE_VERSION} failed at $(date +"%T") ======#"; exit 1
fi
