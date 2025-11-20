

COMPOSE_CMD = docker-compose -f srcs/docker-compose.yml


# Obtener automáticamente el HOME y el usuario actual
# Preservar el usuario original incluso si se ejecuta con sudo
USER_NAME := $(shell bash -c 'echo $${SUDO_USER:-$$USER}')
HOST_HOME := $(shell bash -c 'if [ -n "$$SUDO_USER" ]; then echo ~$$SUDO_USER; else echo $$HOME; fi')
DOMAIN_NAME ?= $(USER_NAME).42.fr

export DOMAIN_NAME
export HOST_HOME

.PHONY: all build up run down restart clean fclean test setup-env

all: run

setup-env:
	@if [ -f .env ]; then \
		cp .env srcs/.env; \
		echo "✅ .env copiado a srcs/"; \
	else \
		echo "⚠️  Archivo .env no encontrado. Asegúrate de crear .env en la raíz del proyecto."; \
	fi

build: setup-env
	@if [ -z "$(HOST_HOME)" ]; then \
		echo "❌ Error: HOST_HOME no está definido. Por favor ejecuta desde el Makefile."; \
		exit 1; \
	fi
	@if [ -z "$(DOMAIN_NAME)" ]; then \
		echo "❌ Error: DOMAIN_NAME no está definido. Por favor ejecuta desde el Makefile."; \
		exit 1; \
	fi
	@echo "🔨 Construyendo imágenes con HOST_HOME=$(HOST_HOME) y DOMAIN_NAME=$(DOMAIN_NAME)..."
	HOST_HOME=$(HOST_HOME) DOMAIN_NAME=$(DOMAIN_NAME) $(COMPOSE_CMD) build

up:
	@if [ -z "$(HOST_HOME)" ]; then \
		echo "❌ Error: HOST_HOME no está definido. Por favor ejecuta desde el Makefile."; \
		exit 1; \
	fi
	@if [ -z "$(DOMAIN_NAME)" ]; then \
		echo "❌ Error: DOMAIN_NAME no está definido. Por favor ejecuta desde el Makefile."; \
		exit 1; \
	fi
	@echo "🚀 Iniciando contenedores con HOST_HOME=$(HOST_HOME) y DOMAIN_NAME=$(DOMAIN_NAME)..."
	HOST_HOME=$(HOST_HOME) DOMAIN_NAME=$(DOMAIN_NAME) $(COMPOSE_CMD) up -d

run: build up
	@echo "✅ Todos los contenedores se han iniciado correctamente."
	@echo "🌐 Accede a https://$(DOMAIN_NAME)"

down:
	$(COMPOSE_CMD) down -v

restart: down up

clean:
	@docker stop $$(docker ps -qa) 2>/dev/null || true; \
	docker rm $$(docker ps -qa) 2>/dev/null || true; \
	docker rmi -f $$(docker images -qa) 2>/dev/null || true; \
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true; \
	docker network rm $$(docker network ls -q) 2>/dev/null || true; \
	docker system prune -f --volumes

fclean: clean
	sudo rm -rf $(HOME)/data/mariadb/*
	sudo rm -rf $(HOME)/data/wordpress/*
	@echo "🗑️  Todo limpio ✅"

setup:
	@echo "📁 Creando directorios para volúmenes..."
	@echo "📍 Usuario: $(USER_NAME)"
	@echo "🏠 HOME: $(HOST_HOME)"
	@echo "🌐 Dominio: $(DOMAIN_NAME)"
	@mkdir -p $(HOST_HOME)/data/mariadb $(HOST_HOME)/data/wordpress $(HOST_HOME)/data/ssl
	@if [ -n "$$SUDO_USER" ]; then \
		chown -R $$SUDO_USER:$$SUDO_USER $(HOST_HOME)/data; \
	fi
	@chmod -R 755 $(HOST_HOME)/data
	@echo "🔐 Generando certificados SSL para $(DOMAIN_NAME)..."
	@bash -c 'DOMAIN_NAME=$(DOMAIN_NAME) SSL_DIR=$(HOST_HOME)/data/ssl HOME=$(HOST_HOME) ./srcs/requirements/nginx/tools/generate-ssl.sh'
	@if [ -n "$$SUDO_USER" ]; then \
		chown $$SUDO_USER:$$SUDO_USER $(HOST_HOME)/data/ssl/* 2>/dev/null || true; \
	fi
	@echo "✅ Directorios creados correctamente"
	@echo ""
	@echo "🔧 Configurando /etc/hosts..."
	@if ! grep -q "$(DOMAIN_NAME)" /etc/hosts 2>/dev/null; then \
		echo "⚠️  Necesitas agregar el dominio a /etc/hosts manualmente:"; \
		echo "   Ejecuta: sudo bash -c 'echo \"127.0.0.1 $(DOMAIN_NAME)\" >> /etc/hosts'"; \
	else \
		echo "✅ Dominio ya está en /etc/hosts"; \
	fi

test:
	@echo "🧪 Verificando estado de contenedores..."
	@$(COMPOSE_CMD) ps
	@echo ""
	@echo "✅ Verificación completada"

info:
	@echo "🌐 Servicios disponibles:"
	@echo "  WordPress: https://$(DOMAIN_NAME)"
	@echo ""
	@echo "📊 Estado de contenedores:"
	@$(COMPOSE_CMD) ps