#!/bin/bash

# Setup script for fully local development
echo "🏠 Setting up local Phoenix development with local services..."

# Create .env.local from example if it doesn't exist
if [ ! -f .env.local ]; then
    echo "Creating .env.local file..."
    cp .env.local.example .env.local
    echo "✅ Created .env.local - please review and update any needed values"
else
    echo "ℹ️  .env.local already exists, skipping creation"
fi

# Check if local PostgreSQL is running
echo "🗄️  Checking PostgreSQL..."
if ! pg_isready -q; then
    echo "⚠️  PostgreSQL is not running. Please start it:"
    echo "   macOS: brew services start postgresql"
    echo "   Linux: sudo systemctl start postgresql"
    echo "   Or use Docker: docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi



# Install dependencies if needed
echo "📦 Installing dependencies..."
mix deps.get
npm install

# Create and migrate database if needed
echo "🗄️  Setting up database..."
mix ecto.create
mix ecto.migrate

echo ""
echo "🎉 Setup complete!"
echo ""
echo "To start your local development server:"
echo "    make dev"
echo ""
echo "Or manually:"
echo "    source .env.local && mix phx.server"
echo ""
echo "Local services:"
echo "  🏠 Phoenix app: http://localhost:4000"
echo "  🗄️  PostgreSQL: localhost:5432"
