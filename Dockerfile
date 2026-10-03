# Keep these versions aligned with the current official Caddy image(https://github.com/caddyserver/caddy-docker)
ARG CADDY_VERSION=2.11.7

FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder

ARG CADDY_VERSION
ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache ca-certificates git

RUN GOBIN=/usr/local/bin go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

RUN CGO_ENABLED=0 GOOS="$TARGETOS" GOARCH="$TARGETARCH" \
    xcaddy build "v${CADDY_VERSION}" \
        --output /out/caddy \
        --with github.com/caddy-dns/luadns \
        --with github.com/mholt/caddy-l4

FROM alpine:3.23

RUN apk add --no-cache ca-certificates

COPY --from=builder /out/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp

WORKDIR /srv

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
