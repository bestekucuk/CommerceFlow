# Convenience targets for the local infrastructure. Run from this folder:
#   make -C infrastructure up
# Every target delegates to a PowerShell script in scripts/ (the scripts are the source of
# truth and also work without make). Override the shell with PWSH=pwsh on Linux/macOS.
PWSH ?= powershell
RUN = $(PWSH) -NoProfile -ExecutionPolicy Bypass -File

.PHONY: up down health migrate connectors verify-cdc topics logs ps

up:            ## start the stack and wait for health checks
	$(RUN) scripts/up.ps1

down:          ## stop the stack (keeps volumes)
	$(RUN) scripts/down.ps1

health:        ## check every component
	$(RUN) scripts/health.ps1

migrate:       ## apply all service migrations + CDC grants/publications
	$(RUN) scripts/migrate.ps1 -All

connectors:    ## register Debezium connectors for migrated services
	$(RUN) scripts/register-connectors.ps1

verify-cdc:    ## end-to-end CDC check (product-service)
	$(RUN) scripts/verify-cdc.ps1 -Service product

topics:        ## (re)apply topics.csv
	docker compose -f ../docker-compose.yml run --rm kafka-init

ps:
	docker compose -f ../docker-compose.yml ps

logs:
	docker compose -f ../docker-compose.yml logs -f --tail=100
