# Run from this folder. Requires Go 1.23+ (or use scripts/build-service.ps1, which falls
# back to the golang Docker image).
.PHONY: lint test integration build

lint:
	go vet ./...
	test -z "$$(gofmt -l .)"

test:
	go test -race -count=1 ./...

integration:
	go test -tags=integration -count=1 ./tests/...

build:
	CGO_ENABLED=0 go build -trimpath -o bin/notification-service ./cmd/notification-service
