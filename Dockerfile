FROM caddy:builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/luadns \
    --with github.com/mholt/caddy-l4

FROM caddy:alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
