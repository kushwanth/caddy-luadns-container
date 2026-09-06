# renovate: datasource=docker depName=caddy
ARG CADDY_VERSION=2.11.4

FROM --platform=$BUILDPLATFORM caddy:${CADDY_VERSION}-builder-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

RUN [ -z "$TARGETVARIANT" ] || export GOARM=${TARGETVARIANT#v}; \
    GOOS=$TARGETOS GOARCH=$TARGETARCH xcaddy build \
        --with github.com/caddy-dns/luadns \
        --with github.com/mholt/caddy-l4

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

