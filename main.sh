#!/usr/bin/env bash

# print help message
function print_help() {
    echo "Usage: ${0} [options]"; echo
    echo "OPTIONS:"
    echo "  -h, --help                   print help message"
    echo "  -a, --arch <arch>[,<arch>]   specify at least a single architecture"
    echo "  -e, --env <envfile>          specify an environment file"
    echo "  -f, --file <dockerfile>      specify a dockerfile"
    echo "  -r, --runtime <runtime>      specify a container runtime"
    echo "  -v, --version <version>      specify the container image version"
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

# ============================================================================================================================

function trim() {
    local v="${1}"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    echo "${v}"
}

function parse_list_item() {
    local i="${1}"
    local var desc default
    IFS='|' read -r var desc default <<< "${i}"
    echo "$(trim "${var}")|$(trim "${desc}")|$(trim "${default}")"
}

function get_values() {
    local vars=("${@}")
    local v var desc default hint value
    for v in "${vars[@]}"; do
        v=$(parse_list_item "${v}")
        IFS='|' read -r var desc default <<< "${v}"
        if [ -z "${!var}" ]; then
            hint="Enter ${desc:-${var}}"
            if [ -n "${default}" ]; then
                hint="${hint} [${default}]"
            fi
            while [ -z "${!var}" ]; do
                read -p "${hint}: " value
                if [ -n "${value}" ]; then
                    export "${var}=${value}"
                elif [ -n "${default}" ]; then
                    export "${var}=${default}"
                fi
            done
        fi
    done
}

function confirm_values() {
    local vars=("${@}")
    local v var desc default value values
    # check if all variables are set
    for v in "${vars[@]}"; do
        v=$(parse_list_item "${v}")
        IFS='|' read -r var desc default <<< "${v}"
        value="${!var}"
        if [ -z "${value}" ]; then
            echo "ERROR: \"${var}\" has not been set"
            return 1
        fi
        values+="\$${var} = \"${value[@]}\"\n"
    done
    # print values
    if [ -n "${values}" ]; then
        echo -e "${values::-2}"
    fi
    # get user confirmation
    echo; read -p "Would you like to continue with your supplied values? [y/N]: " -n 1 -r; echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# ============================================================================================================================

# verify supported container runtime
if [ -z "${CONTAINER_RUNTIME}" ]; then
    readonly RUNTIME_OPTS=("podman" "docker" "nerdctl")
    for r in "${RUNTIME_OPTS[@]}"; do
        if [ -x "$(command -v ${r})" ]; then
            readonly CONTAINER_RUNTIME="${r}"; break
        fi
    done
fi
if [ -z "${CONTAINER_RUNTIME}" ] || [ ! -x "$(command -v ${CONTAINER_RUNTIME})" ]; then
    echo "ERROR: You must have a supported container runtime installed"; exit 1
fi

# get user-supplied values
user_vars=(
    "IMAGE_NAME|image name"
    "IMAGE_REGISTRY|image registry|ghcr.io"
    "IMAGE_REPOSITORY|image repository"
    "IMAGE_VERSION|image version|latest"
    "IMAGE_ARCH|image architecture(s)|linux/amd64"
    "IMAGE_DOCKERFILE|image Dockerfile|Dockerfile"
)
get_values "${user_vars[@]}"; echo

# additional variable processing and declaration
readonly IMAGE_PATH="${IMAGE_PATH:-"${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}"}"
IMAGE_BUILDS=()

# confirm required variable values
required_vars=("CONTAINER_RUNTIME" "${user_vars[@]}" "IMAGE_PATH")
if ! confirm_values "${required_vars[@]}"; then
    exit 1
fi

# ============================================================================================================================

echo; echo "#====== Building ${IMAGE_NAME} v${IMAGE_VERSION} at $(date +"%T") ======#"

# ${CONTAINER_RUNTIME} build --platform linux/amd64 -t "${IMAGE_NAME}":latest -f "${IMAGE_DOCKERFILE}" . \
# && ${CONTAINER_RUNTIME} images \
# && ${CONTAINER_RUNTIME} tag "${IMAGE_NAME}":latest "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}" \
# && ${CONTAINER_RUNTIME} push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}" \
# && ${CONTAINER_RUNTIME} rmi "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${IMAGE_VERSION}"

# build and publish image for each platform
IFS=',' read -ra IMAGE_ARCH <<< "${IMAGE_ARCH}"
for platform in "${IMAGE_ARCH[@]}"; do
    platform=$(trim "${platform}")
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
