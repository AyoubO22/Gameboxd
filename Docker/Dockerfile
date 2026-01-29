#
# Dockerfile for Gameboxd Backend API
# Demonstrates Docker Certified Associate knowledge
#
# Multi-stage build for optimized production image
# Implements security best practices and layer optimization
#

# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM swift:5.9-jammy AS builder

# Build arguments for flexibility
ARG ENVIRONMENT=production
ARG BUILD_DATE
ARG VCS_REF

# Labels following OCI image spec
LABEL org.opencontainers.image.title="Gameboxd API"
LABEL org.opencontainers.image.description="Backend API for Gameboxd gaming journal app"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Gameboxd"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="dev@gameboxd.app"

# Set working directory
WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Package.swift first for dependency caching
# Docker layer caching: dependencies only rebuilt when Package.swift changes
COPY Package.swift Package.resolved ./

# Resolve dependencies (cached layer)
RUN swift package resolve

# Copy source code
COPY Sources/ Sources/
COPY Tests/ Tests/

# Build release binary with optimizations
RUN swift build \
    --configuration release \
    --static-swift-stdlib \
    -Xswiftc -cross-module-optimization \
    -Xswiftc -Osize

# Run tests in build stage (fail fast)
RUN swift test --enable-code-coverage

# ==========================================
# Stage 2: Production Stage
# ==========================================
FROM ubuntu:22.04 AS production

# Security: Don't run as root
# Create non-privileged user
RUN groupadd --gid 1000 gameboxd \
    && useradd --uid 1000 --gid gameboxd --shell /bin/bash --create-home gameboxd

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcurl4 \
    libssl3 \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set timezone
ENV TZ=UTC

# Create app directory with proper permissions
WORKDIR /app
RUN chown gameboxd:gameboxd /app

# Copy binary from build stage
COPY --from=builder --chown=gameboxd:gameboxd /build/.build/release/GameboxdAPI .

# Copy any static assets
COPY --chown=gameboxd:gameboxd Public/ Public/
COPY --chown=gameboxd:gameboxd Resources/ Resources/

# Security: Make binary read-only
RUN chmod 555 /app/GameboxdAPI

# Switch to non-root user
USER gameboxd

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port (documentation)
EXPOSE 8080

# Environment variables
ENV ENVIRONMENT=${ENVIRONMENT}
ENV LOG_LEVEL=info
ENV PORT=8080

# Use exec form for proper signal handling
ENTRYPOINT ["./GameboxdAPI"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]

# ==========================================
# Stage 3: Development Stage (optional)
# ==========================================
FROM swift:5.9-jammy AS development

WORKDIR /app

# Install development tools
RUN apt-get update && apt-get install -y \
    vim \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy source for development
COPY . .

# Development port
EXPOSE 8080

# Hot reload command
CMD ["swift", "run", "--enable-test-discovery"]

# ==========================================
# Build Commands:
# ==========================================
#
# Build production image:
# docker build --target production -t gameboxd-api:latest .
#
# Build with build args:
# docker build --target production \
#   --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
#   --build-arg VCS_REF=$(git rev-parse --short HEAD) \
#   -t gameboxd-api:1.0.0 .
#
# Build development image:
# docker build --target development -t gameboxd-api:dev .
#
# ==========================================
