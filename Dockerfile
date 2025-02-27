FROM docker.io/library/alpine:3.21.3 AS base

ENV CONTAINER_NAME="img-builder"
ENV CONTAINER_USER="${CONTAINER_NAME}"
ENV CONTAINER_GROUP="${CONTAINER_USER}"
ENV USER_UID="1001"
ENV GROUP_GID="${USER_UID}"
# ENV STORAGE_DRIVER="vfs"
ENV STORAGE_DRIVER="overlay"
# ENV PODMAN_IGNORE_CGROUPSV1_WARNING="1"

RUN apk add --no-cache \
    bash \
    # coreutils \
    fuse-overlayfs \
    git \
    openrc \
    passt \
    podman \
    shadow

RUN addgroup \
    --gid "${GROUP_GID}" \
    "${CONTAINER_GROUP}" && \
    adduser \
        --disabled-password \
        --gecos "" \
        --ingroup "${CONTAINER_GROUP}" \
        # --no-create-home \
        --uid "${USER_UID}" \
        "${CONTAINER_USER}"

RUN usermod \
    --add-subuids 10000-14999 \
    --add-subgids 10000-14999 \
    "${CONTAINER_USER}"

RUN sed -i "s/^driver = .*/driver = \"${STORAGE_DRIVER}\"/" /etc/containers/storage.conf && \
    mkdir -p "/home/${CONTAINER_USER}/.config/containers" && \
    echo -e "[storage]\ndriver=\"${STORAGE_DRIVER}\"" > "/home/${CONTAINER_USER}/.config/containers/storage.conf" && \
    chown -R "${CONTAINER_USER}":"${CONTAINER_GROUP}" "/home/${CONTAINER_USER}/.config"

RUN printf '%s\n' '#!/bin/sh' \
    'if [ -n "${AUTH_TOKEN}" ] && [ -n "${IMAGE_REGISTRY}" ] && [ -n "${AUTH_USER}" ]; then' \
    '  echo "${AUTH_TOKEN}" | podman login "${IMAGE_REGISTRY}" -u "${AUTH_USER}" --password-stdin' \
    'fi' \
    'if [ -n "${SRC_REPO_URL}" ]; then' \
    '  git clone "${SRC_REPO_URL}" "/home/${CONTAINER_USER}/src"' \
    'fi' \
    'exec "${@}"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh && \
    chown "${CONTAINER_USER}":"${CONTAINER_GROUP}" /entrypoint.sh

COPY bin/ "/opt/${CONTAINER_NAME}/bin/"

COPY installer.sh "/opt/${CONTAINER_NAME}/"

RUN /bin/bash "/opt/${CONTAINER_NAME}/installer.sh" --install-prefix "/usr/local" && \
    rm -rf "/opt/${CONTAINER_NAME}"

USER "${CONTAINER_USER}"

WORKDIR "/home/${CONTAINER_USER}"

ENTRYPOINT ["/entrypoint.sh"]