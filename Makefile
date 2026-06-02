# Makefile — TaskFlow API

BINARY   = bin/taskflow-api
IMAGE    = taskflow-api
REGISTRY ?= ghcr.io/your-username
VERSION  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")
DB_URL   ?= postgres://taskflow:taskflow_secret@localhost:5432/taskflow?sslmode=disable

.PHONY: all vet test test-race test-cover test-integration \
        build docker-build docker-push docker-stable rollback \
        db-up db-down up clean help

# ===============================
# BASIC
# ===============================

all: vet test build

## go vet
vet:
	@echo "→ go vet ./..."
	go vet ./...

## unit test
test:
	@echo "→ go test ./..."
	go test ./... -v -timeout 30s

## race detector (WAJIB CI)
test-race:
	@echo "→ go test -race ./..."
	go test ./... -race -timeout 30s

## coverage
test-cover:
	@echo "→ coverage report"
	go test ./... -coverprofile=coverage.out -covermode=atomic
	go tool cover -func=coverage.out

## integration test (postgres)
test-integration:
	@echo "→ integration test (DATABASE_URL=$(DB_URL))"
	DATABASE_URL=$(DB_URL) go test -tags=integration ./... -v -race -timeout 60s

# ===============================
# BUILD
# ===============================

build:
	@echo "→ go build ($(VERSION))"
	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux go build \
		-ldflags="-w -s" \
		-o $(BINARY) ./cmd/server

# ===============================
# DOCKER
# ===============================

docker-build:
	@echo "→ docker build ($(VERSION))"
	docker build -t $(REGISTRY)/$(IMAGE):sha-$(VERSION) .
	@docker images $(REGISTRY)/$(IMAGE):sha-$(VERSION) --format "Size: {{.Size}}"

docker-push:
	@echo "→ docker push"
	docker push $(REGISTRY)/$(IMAGE):sha-$(VERSION)

## update stable (HARUS setelah smoke test PASS)
docker-stable:
	@echo "→ tag $(VERSION) sebagai stable"
	docker tag $(REGISTRY)/$(IMAGE):sha-$(VERSION) $(REGISTRY)/$(IMAGE):stable
	docker push $(REGISTRY)/$(IMAGE):stable

# ===============================
# ROLLBACK (⭐ INI YANG DINILAI S5)
# ===============================

## Usage:
## make rollback ROLLBACK_TAG=sha-xxxxx
rollback:
	@test -n "$(ROLLBACK_TAG)" || (echo "❌ Set ROLLBACK_TAG=sha-xxxxx"; exit 1)

	@echo "→ Pull image $(ROLLBACK_TAG)"
	docker pull $(REGISTRY)/$(IMAGE):$(ROLLBACK_TAG)

	@echo "→ Stop container lama"
	docker stop taskflow-api 2>/dev/null || true
	docker rm taskflow-api 2>/dev/null || true

	@echo "→ Jalankan container baru"
	docker run -d --rm \
	  --name taskflow-api \
	  -p 9000:9000 \
	  -e DATABASE_URL=$(DB_URL) \
	  $(REGISTRY)/$(IMAGE):$(ROLLBACK_TAG)

	@echo "⏳ Menunggu server siap..."
	@sleep 5

	@echo "→ Health check..."
	@curl -sf http://localhost:9000/health \
	  || (echo "❌ Health check gagal! rollback tidak valid"; exit 1)

	@echo "→ Validasi endpoint utama..."
	@curl -sf http://localhost:9000/api/v1/stats \
	  || (echo "❌ Endpoint stats gagal!"; exit 1)

	@echo "✅ Rollback berhasil ke $(ROLLBACK_TAG)"

# ===============================
# DEV
# ===============================

db-up:
	docker compose up -d postgres
	@echo "⏳ Menunggu postgres siap..."
	@sleep 3
	@echo "✅ Postgres siap di localhost:5432"

up:
	docker compose up -d
	@echo "✅ API: http://localhost:9000/health"

db-down:
	docker compose down

clean:
	rm -rf bin/ coverage.out

help:
	@grep -E '^##' Makefile | sed 's/## /  /'