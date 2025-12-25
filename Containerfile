ARG BASE_VERSION=15
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG PACKAGES="FreeBSD-clang FreeBSD-lld FreeBSD-toolchain FreeBSD-clibs-dev FreeBSD-runtime-dev node20 npm-node20 yarn-node20 python311 sqlite3 git-lite gmake ca_root_nss"

LABEL org.opencontainers.image.title="overseerr" \
    org.opencontainers.image.description="Overseerr media request management on FreeBSD" \
    org.opencontainers.image.source="https://github.com/daemonless/overseerr" \
    org.opencontainers.image.url="https://overseerr.dev/" \
    org.opencontainers.image.documentation="https://docs.overseerr.dev/" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="5055" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.category="Media Management" \
    io.daemonless.upstream-mode="github_commits" \
    io.daemonless.upstream-repo="sct/overseerr" \
    io.daemonless.upstream-branch="develop" \
    io.daemonless.packages="${PACKAGES}"

# Install build dependencies from ports and pkgbase
# (FreeBSD-base repo is already configured in base image)
RUN pkg update && \
    pkg install -y \
    ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* && \
    ln -sf /usr/bin/clang /usr/bin/cc && \
    ln -sf /usr/bin/clang++ /usr/bin/c++

# Create overseerr user

# Clone and build Overseerr
ENV PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
ENV NODE_OPTIONS="--max-old-space-size=2048"
RUN mkdir -p /app/overseerr && \
    chmod 755 /app && \
    fetch -qo - "https://github.com/sct/overseerr/archive/refs/heads/develop.tar.gz" | \
    tar xzf - -C /app/overseerr --strip-components=1 && \
    cd /app/overseerr && \
    OVERSEERR_VERSION=$(grep '"version"' package.json | head -1 | cut -d '"' -f 4) && \
    echo "$OVERSEERR_VERSION" > /app/version && \
    CYPRESS_INSTALL_BINARY=0 npm install --legacy-peer-deps && \
    npm run build && \
    npm prune --production --legacy-peer-deps && \
    rm -rf src server .next/cache && \
    chown -R bsd:bsd /app/overseerr

# Create config directory
RUN mkdir -p /config && \
    chown -R bsd:bsd /config

# Copy service definition and init scripts
COPY root/ /

# Make scripts executable
RUN chmod +x /etc/services.d/overseerr/run /etc/cont-init.d/* 2>/dev/null || true

# Set up s6 service link

EXPOSE 5055
VOLUME /config


