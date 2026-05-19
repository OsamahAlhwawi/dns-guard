SHELL := /bin/bash

.PHONY: help setup up down restart logs ps backup restore admin shell test build clean

help:
	@echo "DNS Guard backend — common targets"
	@echo "  make setup    First-run: generate JWT keys, copy .env, bring up stack"
	@echo "  make up       docker compose up -d"
	@echo "  make down     docker compose down"
	@echo "  make restart  Restart the backend container"
	@echo "  make logs     Tail backend logs"
	@echo "  make ps       Show container status"
	@echo "  make admin    Bootstrap the first admin account"
	@echo "  make backup   Snapshot SQLite + AdGuard data to ./backups/"
	@echo "  make restore F=backups/<name>.tar.gz   Restore from a snapshot"
	@echo "  make shell    Shell into the backend container"
	@echo "  make test     Run bun:test inside the backend image"
	@echo "  make build    Rebuild the backend image"
	@echo "  make clean    Remove containers + volumes (data loss!)"

setup:
	./scripts/setup.sh

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart backend

logs:
	docker compose logs -f backend

ps:
	docker compose ps

admin:
	./scripts/create-admin.sh

backup:
	./scripts/backup.sh

restore:
	@if [ -z "$(F)" ]; then echo "Usage: make restore F=backups/<file>.tar.gz"; exit 1; fi
	./scripts/restore.sh "$(F)"

shell:
	docker compose exec backend sh

test:
	docker compose run --rm backend bun test

build:
	docker compose build backend

clean:
	docker compose down -v
