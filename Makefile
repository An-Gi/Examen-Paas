# Atajos del proyecto. Uso: make <objetivo>   (make ayuda para ver la lista)
# Las recetas van con TAB (no .RECIPEPREFIX): el make 3.81 de macOS no lo soporta.
.DEFAULT_GOAL := ayuda
SHELL := /bin/bash

ROL ?= todos
BUILD := docs/build

.PHONY: ayuda verificar horas horas-md commits diagrama pdf lint todos secretos \
        tf-init tf-plan tf-apply tf-destroy vpn proxy

ayuda: ## Lista los objetivos disponibles
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

# --- Fase 0 / utilidades ----------------------------------------------------
verificar: ## Herramientas del equipo (ROL=a | ROL=b | ROL=todos)
	@bash scripts/verificar-entorno.sh $(ROL)

horas: ## Suma y valida las bitácoras
	@python3 scripts/bitacora/sumar-horas.py docs/bitacoras

horas-md: ## Tablas de horas para la §5 -> docs/build/horas.md
	@mkdir -p $(BUILD) && python3 scripts/bitacora/sumar-horas.py docs/bitacoras --markdown > $(BUILD)/horas.md && echo "$(BUILD)/horas.md"

commits: ## Reporte de commits para la §6 -> docs/build/commits.md
	@mkdir -p $(BUILD) && bash scripts/git/reporte-commits.sh > $(BUILD)/commits.md && echo "$(BUILD)/commits.md"

todos: ## Lista los TODO pendientes por estudiante
	@grep -rnE 'TODO\((A|B|A\+B)\)' --exclude-dir=.git --exclude=Makefile --exclude=CONTRIBUTING.md . | sort || echo "Sin TODOs pendientes"

secretos: ## Escanea todo el repo en busca de secretos (gitleaks vía pre-commit)
	pre-commit run gitleaks --all-files

# --- Documentación ------------------------------------------------------------
diagrama: ## Exporta docs/diagramas/red.mmd -> docs/img/red.png
	npx -y @mermaid-js/mermaid-cli -i docs/diagramas/red.mmd -o docs/img/red.png -w 1600 -b white

pdf: ## Genera docs/build/documentacion.pdf con pandoc
	@mkdir -p $(BUILD)
	cd docs && pandoc documentacion.md -o build/documentacion.pdf --pdf-engine=xelatex --resource-path=.
	@echo "$(BUILD)/documentacion.pdf"

# --- Calidad --------------------------------------------------------------------
lint: ## terraform fmt/validate, yamllint, ansible-lint y docker compose config
	@if command -v terraform >/dev/null; then terraform -chdir=terraform fmt -check -recursive && terraform -chdir=terraform validate; else echo "terraform no instalado, se omite"; fi
	@if command -v yamllint >/dev/null; then yamllint -d relaxed k8s ansible docker; else echo "yamllint no instalado, se omite"; fi
	@if command -v ansible-lint >/dev/null; then (cd ansible && ansible-lint playbooks/); else echo "ansible-lint no instalado, se omite"; fi
	@if docker compose version >/dev/null 2>&1; then \
	  for f in docker/0*/docker-compose.yml docker/extras/*/docker-compose.yml; do \
	    docker compose --env-file docker/.env.example -f $$f config -q && echo "ok  $$f"; \
	  done; else echo "docker compose no instalado, se omite"; fi

# --- IaC (Estudiante A) ---------------------------------------------------------
tf-init: ## terraform init
	terraform -chdir=terraform init

tf-plan: ## terraform plan
	terraform -chdir=terraform plan

tf-apply: ## terraform apply (crea la EC2: genera costo)
	terraform -chdir=terraform apply

tf-destroy: ## terraform destroy (hacerlo al terminar cada sesión)
	terraform -chdir=terraform destroy

vpn: ## Aplica el rol openvpn en la EC2
	cd ansible && ansible-playbook playbooks/vpn.yml --skip-tags proxy

proxy: ## Aplica el rol nginx_proxy en la EC2 (Fase 5)
	cd ansible && ansible-playbook playbooks/vpn.yml --tags proxy
