# ---- Стадия сборки ----
FROM golang:1.17-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /app/app ./cmd/api


FROM golang:1.17-alpine AS runtime

WORKDIR /app

RUN addgroup -S -g 10001 backend && \
    adduser -S -D -H -u 10001 -G backend -s /sbin/nologin backend

COPY --from=builder --chown=backend:backend /app/app /app/app

EXPOSE 8081

USER 10001:10001

CMD ["/app/app"]