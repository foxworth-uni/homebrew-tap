# Default recipe shows available commands
default:
    @just --list

# Update a formula with bottles from GitHub releases
update FORMULA VERSION="":
    @ruby scripts/update-formula.rb {{ FORMULA }} {{ VERSION }}

# Dry run - preview what would be updated without making changes
dry-run FORMULA VERSION="":
    @ruby scripts/update-formula.rb {{ FORMULA }} {{ VERSION }} --dry-run

# List all formulae
list:
    @echo "📋 Available formulae:"
    @ls -1 Formula/*.rb | sed 's/Formula\//  • /' | sed 's/\.rb//'

# Test install a formula locally
test-install FORMULA:
    @echo "🧪 Testing {{ FORMULA }} installation..."
    @brew uninstall {{ FORMULA }} 2>/dev/null || true
    @brew install --build-from-source ./Formula/{{ FORMULA }}.rb
    @{{ FORMULA }} --version || {{ FORMULA }} --help
    @echo "✅ Test successful"
