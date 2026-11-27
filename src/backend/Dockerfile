FROM golang:1.17-alpine AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .

ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/root/.cache/go-build \
    GOOS=linux GOARCH=amd64 \
    go build -trimpath -buildvcs=false \
      -ldflags="-s -w" \
      -o /out/app ./cmd/api

FROM builder AS test
RUN --mount=type=cache,target=/root/.cache/go-build go test ./...

FROM gcr.io/distroless/static-debian12:nonroot AS prod
WORKDIR /app
COPY --from=builder /out/app /app/app
EXPOSE 8081
USER nonroot:nonroot
CMD ["/app/app"]