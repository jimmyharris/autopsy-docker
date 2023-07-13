#
# autopsy-2 Dockerfile
#
# https://github.com/jlesage/docker-autopsy-2
#
# NOTES:
#   - We are using JRE version 8 because recent versions are much bigger.
#   - JRE for ARM 32-bits on Alpine is very hard to get:
#     - The version in Alpine repo is very, very slow.
#     - The glibc version doesn't work well on Alpine with a compatibility
#       layer (gcompat or libc6-compat).  The `__xstat` symbol is missing and
#       implementing a wrapper is not straight-forward because the `struct stat`
#       is not constant across architectures (32/64 bits) and glibc/musl.
#

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=

# Define software download URLs.
ARG AUTOPSY_VERSION=4.20.0
ARG AUTOPSY_ARCHIVE=autopsy-${AUTOPSY_VERSION}.zip
ARG SLEUTHKIT_VERSION=4.12.0
ARG AUTOPSY_URL=https://github.com/sleuthkit/autopsy/releases/download/autopsy-${AUTOPSY_VERSION}/${AUTOPSY_ARCHIVE}
ARG SLUETHKIT_URL=https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-${SLEUTHKIT_VERSION}/sleuthkit-java_${SLEUTHKIT_VERSION}-1_amd64.deb

# Download Autopsy
FROM --platform=$BUILDPLATFORM alpine:3.18 AS autopsy_fetcher
ARG AUTOPSY_URL
ARG AUTOPSY_ARCHIVE
ARG AUTOPSY_VERSION
ARG SLUETHKIT_URL
# Install tools and create directories
RUN \
    apk --no-cache add curl && \
    mkdir -p /tools && \
    mkdir -p /prereqs
# Download autopsy
RUN \
    curl -# -L -o /prereqs/sleuthkit.deb ${SLUETHKIT_URL} && \
    curl -# -L -o /tools/${AUTOPSY_ARCHIVE} ${AUTOPSY_URL} && \
    cd /tools/ && \
    unzip -d . ${AUTOPSY_ARCHIVE} && \
    rm ${AUTOPSY_ARCHIVE}

# Copy pre-req installer out and modify it to run as root using helper scripts
RUN \
    cp /tools/autopsy-${AUTOPSY_VERSION}/linux_macos_install_scripts/install_prereqs_ubuntu.sh /prereqs/install_autopsy_prereqs.sh && \
    sed -i -e 's/u+x/a+x/' /tools/autopsy-${AUTOPSY_VERSION}/unix_setup.sh && \
    sed -i -e 's/sudo //' \
        # -e '/apt update/d' \
        # -e 's/apt -y install /add-pkg /' \
        /prereqs/install_autopsy_prereqs.sh

# Pull base image.
FROM jlesage/baseimage-gui:ubuntu-22.04-v4.4.2

ARG DOCKER_IMAGE_VERSION
ARG AUTOPSY_VERSION

COPY --from=autopsy_fetcher /tools /
COPY --from=autopsy_fetcher /prereqs /prereqs

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN \
    bash /prereqs/install_autopsy_prereqs.sh && \
    rm -rf /var/lib/apt/lists/* 
RUN \
    add-pkg /prereqs/sleuthkit.deb

RUN \
    bash /autopsy-${AUTOPSY_VERSION}/unix_setup.sh -n autopsy -j "/usr/lib/jvm/bellsoft-java8-full-amd64"
# Generate and install favicons.
RUN \
    APP_ICON_URL=http://sleuthkit.org/picts/renzik_sm.jpg && \
    install_app_icon.sh "$APP_ICON_URL"

# Add files.
COPY rootfs/ /

# Set internal environment variables.
RUN \
    set-cont-env APP_NAME "Autopsy" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    set-cont-env AUTOPSY_VERSION "${AUTOPSY_VERSION}" && \
    set-cont-env JAVA_HOME "/usr/lib/jvm/bellsoft-java8-full-amd64" && \
    true

# Define mountable directories.
VOLUME ["/data"]

# Expose ports.
#   - 3129: For MyAutopsy in Direct Connection mode.
EXPOSE 3129

# Metadata.
LABEL \
      org.label-schema.name="autopsy-2" \
      org.label-schema.description="Docker container for Autopsy 2" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-autopsy-2" \
      org.label-schema.schema-version="1.0"
