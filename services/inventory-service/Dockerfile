# syntax=docker/dockerfile:1.7
# Build context: this folder (scripts also pass --build-context contracts=contracts for
# future code generation; unused until CF-002/CF-003).
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/inventory-service ./cmd/inventory-service

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/inventory-service /inventory-service
COPY --from=build /src/migrations /migrations
USER nonroot:nonroot
EXPOSE 8083
ENTRYPOINT ["/inventory-service"]
