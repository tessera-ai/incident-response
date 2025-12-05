.PHONY: setup-local dev dev-deps test clean build release

# Local development setup with Railway services
setup-local:
	@echo "🚀 Setting up local development with Railway services..."
	@./scripts/setup-local.sh

# Start local development server with Railway services
dev:
	@echo "🔥 Starting Phoenix server with Railway services..."
	@if [ -f .env.local ]; then \
		. .env.local && mix phx.server; \
	else \
		echo "❌ .env.local not found. Run 'make setup-local' first."; \
		exit 1; \
	fi

# Install development dependencies
dev-deps:
	@echo "📦 Installing development dependencies..."
	mix deps.get
	mix compile
	npm install --prefix assets

# Run tests
test:
	mix test

# Clean build artifacts
clean:
	mix clean

# Build for production
build:
	MIX_ENV=prod mix release

# Deploy to Railway
deploy:
	@echo "🚀 Deploying to Railway..."
	git add .
	git commit -m "Deploy to Railway"
	git push origin main
	railway up

# Database operations
db-create:
	@if [ -f .env.local ]; then \
		. .env.local && mix ecto.create; \
	else \
		echo "❌ .env.local not found. Run 'make setup-local' first."; \
	fi

db-migrate:
	@if [ -f .env.local ]; then \
		. .env.local && mix ecto.migrate; \
	else \
		echo "❌ .env.local not found. Run 'make setup-local' first."; \
	fi

db-reset:
	@if [ -f .env.local ]; then \
		. .env.local && mix ecto.drop && mix ecto.create && mix ecto.migrate; \
	else \
		echo "❌ .env.local not found. Run 'make setup-local' first."; \
	fi
