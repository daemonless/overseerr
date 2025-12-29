# Overseerr - Media request management
# Multi-stage build: compile with npm, run with node only

ARG BASE_VERSION=15
FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

# Build dependencies
RUN pkg update && pkg install -y \
    node20 npm-node20 yarn-node20 python311 \
    gmake pkgconf sqlite3 git-lite \
    FreeBSD-clang FreeBSD-lld FreeBSD-toolchain FreeBSD-clibs-dev FreeBSD-runtime-dev \
    ca_root_nss \
    && pkg clean -ay

# Symlink compilers
RUN ln -sf /usr/bin/clang /usr/bin/cc && \
    ln -sf /usr/bin/clang++ /usr/bin/c++

# Clone and build Overseerr
ENV PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
ENV NODE_OPTIONS="--max-old-space-size=2048"

RUN mkdir -p /app/overseerr && \
    fetch -qo - "https://github.com/sct/overseerr/archive/refs/heads/develop.tar.gz" | \
    tar xzf - -C /app/overseerr --strip-components=1 && \
    cd /app/overseerr && \
    grep '"version"' package.json | head -1 | cut -d '"' -f 4 > /app/version

WORKDIR /app/overseerr

RUN CYPRESS_INSTALL_BINARY=0 npm install --legacy-peer-deps && \
    npm run build && \
    npm prune --production --legacy-peer-deps && \
    rm -rf src server .next/cache

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG PACKAGES="node20"

LABEL org.opencontainers.image.title="Overseerr" \
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

# Runtime dependencies only
RUN pkg update && \
    pkg install -y ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Copy built application from builder
COPY --from=builder /app/overseerr /app/overseerr
COPY --from=builder /app/version /app/version

# Create directories and fix permissions
RUN mkdir -p /config && \
    chown -R bsd:bsd /config /app

# Copy service files
COPY root/ /
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

EXPOSE 5055
VOLUME /config
