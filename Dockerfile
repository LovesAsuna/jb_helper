FROM golang:1.24 AS backend-builder

WORKDIR /usr/src/jetbrains_hacker

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go mod tidy && go build -trimpath -ldflags="-s -w" -o /out/jetbrains_hacker .

FROM oven/bun:1-alpine AS frontend-builder

WORKDIR /usr/src/jetbrains_hacker/frontend

COPY frontend/package.json frontend/bun.lock ./
RUN bun install --frozen-lockfile

COPY frontend/ ./
RUN bun run build

FROM alpine:latest AS caddy-builder

RUN apk add --no-cache curl \
  && curl -fsSL -o /usr/local/bin/caddy "https://caddyserver.com/api/download?os=linux&arch=amd64" \
  && chmod +x /usr/local/bin/caddy

FROM alpine:latest
LABEL authors="LovesAsuna"

WORKDIR /usr/src/jetbrains_hacker

RUN apk add --no-cache ca-certificates libgcc libstdc++ \
  && mkdir -p /var/log/caddy

COPY Caddyfile ./Caddyfile
COPY --from=backend-builder /out/jetbrains_hacker /usr/local/bin/jetbrains_hacker
COPY --from=frontend-builder /usr/local/bin/bun /usr/local/bin/bun
COPY --from=frontend-builder /usr/src/jetbrains_hacker/frontend/build ./frontend/build
COPY --from=caddy-builder /usr/local/bin/caddy /usr/local/bin/caddy

EXPOSE 8080

CMD ["sh", "-c", "jetbrains_hacker run-server --addr :8080 --user-cert /etc/cert/user.crt --user-key /etc/cert/user.key --license-server-cert /etc/cert/license_server.crt --license-server-key /etc/cert/license_server.key & bun frontend/build & exec caddy run --config ./Caddyfile"]