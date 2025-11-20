# Default recipe shows available commands
default:
    @just --list

# Update a formula with bottles from GitHub releases
update FORMULA VERSION="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check for gum
    if ! command -v gum &> /dev/null; then
        echo "❌ gum is required. Install with: brew install gum"
        exit 1
    fi
    
    FORMULA="{{ FORMULA }}"
    
    # Validate formula exists
    if [ ! -f "Formula/${FORMULA}.rb" ]; then
        gum style --foreground 196 "❌ Formula not found: Formula/${FORMULA}.rb"
        exit 1
    fi
    
    # Get GitHub repo (convention: foxworth-uni/<formula>)
    REPO="foxworth-uni/${FORMULA}"
    
    # Get version (auto-detect or use provided)
    if [ -z "{{ VERSION }}" ]; then
        gum style --foreground 99 "📦 Fetching latest ${FORMULA} version..."
        
        # Try to get latest tag using git ls-remote (works for public repos)
        # Sort logic: split by ., numeric sort each component
        LATEST=$(git ls-remote --tags "https://github.com/${REPO}.git" 2>/dev/null | \
                 grep -o 'refs/tags/v[0-9]*\.[0-9]*\.[0-9]*$' | \
                 cut -d/ -f3 | sed 's/^v//' | \
                 sort -t. -k1,1n -k2,2n -k3,3n | tail -1 || echo "")
        
        if [ -z "$LATEST" ]; then
            LATEST="0.0.1"
        fi
        
        VERSION=$(gum input \
            --placeholder "Version (e.g. 0.0.7)" \
            --value "$LATEST" \
            --header "🎯 Enter ${FORMULA} version to package")
    else
        VERSION="{{ VERSION }}"
    fi
    
    # Confirm version
    echo ""
    gum style --bold --foreground 212 "Updating ${FORMULA} to v${VERSION}"
    echo ""
    
    if ! gum confirm "Fetch SHA256 hashes for v${VERSION}?"; then
        gum style --foreground 240 "Cancelled"
        exit 0
    fi
    
    echo ""
    
    # Extract existing metadata safely
    DESC=$(grep -m1 '^[[:space:]]*desc ' "Formula/${FORMULA}.rb" | sed -E 's/^[[:space:]]*desc "(.*)"/\1/' || echo "")
    HOMEPAGE=$(grep -m1 '^[[:space:]]*homepage ' "Formula/${FORMULA}.rb" | sed -E 's/^[[:space:]]*homepage "(.*)"/\1/' || echo "https://github.com/${REPO}")
    
    # Extract crate path from existing formula to preserve it
    # Default to crates/<formula>-cli if not found
    CRATE_PATH=$(grep -m1 'path: "' "Formula/${FORMULA}.rb" | sed -E 's/.*path: "(.*)".*/\1/' || echo "crates/${FORMULA}-cli")
    
    # Formula Class Name Generation (Snake-case to CamelCase)
    # e.g. my-tool -> MyTool
    CLASS_NAME=$(echo "$FORMULA" | awk -F- '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' OFS='')
    
    # Fetch source SHA256
    gum style --foreground 99 "📦 Source tarball"
    SOURCE_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
    SOURCE_SHA=$(gum spin --spinner dot --title "Downloading..." -- \
        sh -c "curl -sL '$SOURCE_URL' | shasum -a 256 | cut -d' ' -f1")
    
    if [[ ! "$SOURCE_SHA" =~ ^[a-f0-9]{64}$ ]]; then
        gum style --foreground 196 "   ❌ Failed - release may not exist"
        gum style --foreground 240 "   $SOURCE_URL"
        exit 1
    fi
    gum style --foreground 46 "   ✅ $SOURCE_SHA"
    
    # Fetch ARM64 bottle SHA256
    gum style --foreground 99 "🍺 ARM64 bottle (Apple Silicon)"
    ARM64_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FORMULA}-${VERSION}.arm64_sonoma.bottle.tar.gz"
    ARM64_SHA=$(gum spin --spinner dot --title "Downloading..." -- \
        sh -c "curl -sL '$ARM64_URL' | shasum -a 256 | cut -d' ' -f1")
    
    if [[ ! "$ARM64_SHA" =~ ^[a-f0-9]{64}$ ]]; then
        gum style --foreground 196 "   ❌ Failed - bottles may not be ready"
        gum style --foreground 240 "   Check: https://github.com/${REPO}/actions"
        gum style --foreground 240 "   Wait for release workflow to complete"
        exit 1
    fi
    gum style --foreground 46 "   ✅ $ARM64_SHA"
    
    # Fetch x86_64 bottle SHA256
    gum style --foreground 99 "🍺 x86_64 bottle (Intel)"
    X86_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FORMULA}-${VERSION}.x86_64_sonoma.bottle.tar.gz"
    X86_SHA=$(gum spin --spinner dot --title "Downloading..." -- \
        sh -c "curl -sL '$X86_URL' | shasum -a 256 | cut -d' ' -f1")
    
    if [[ ! "$X86_SHA" =~ ^[a-f0-9]{64}$ ]]; then
        gum style --foreground 196 "   ❌ Failed"
        gum style --foreground 240 "   $X86_URL"
        exit 1
    fi
    gum style --foreground 46 "   ✅ $X86_SHA"
    
    echo ""
    
    # Show formatted summary
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "1 2" \
        --align center \
        --width 70 \
        "$(gum style --bold --foreground 212 "${FORMULA} v${VERSION}")"
    
    gum style \
        --border rounded \
        --border-foreground 240 \
        --padding "0 2" \
        --width 70 \
        "Source:  ${SOURCE_SHA:0:16}...${SOURCE_SHA:48}" \
        "ARM64:   ${ARM64_SHA:0:16}...${ARM64_SHA:48}" \
        "x86_64:  ${X86_SHA:0:16}...${X86_SHA:48}"
    
    echo ""
    
    # Confirm update
    if ! gum confirm "Update Formula/${FORMULA}.rb?"; then
        gum style --foreground 240 "Cancelled"
        exit 0
    fi
    
    # Define operators to avoid just parser issues
    LT="<"
    ARROW="=>"
    
    # Update formula
    cat > "Formula/${FORMULA}.rb" <<EOF
class ${CLASS_NAME} ${LT} Formula
  desc "${DESC}"
  homepage "${HOMEPAGE}"
  url "https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
  sha256 "${SOURCE_SHA}"
  license "MIT"
  head "https://github.com/${REPO}.git", branch: "main"

  bottle do
    root_url "https://github.com/${REPO}/releases/download/v${VERSION}"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "${ARM64_SHA}"
    sha256 cellar: :any_skip_relocation, x86_64_sonoma: "${X86_SHA}"
  end

  depends_on "rust" ${ARROW} :build

  def install
    system "cargo", "install", *std_cargo_args(path: "${CRATE_PATH}")
  end

  test do
    assert_match "${FORMULA}", shell_output("#{bin}/${FORMULA} --help")
  end
end
EOF
    
    gum style --foreground 46 "✅ Formula updated!"
    echo ""
    
    # Show diff
    if git diff --quiet "Formula/${FORMULA}.rb"; then
        gum style --foreground 240 "No changes detected"
    else
        gum style --foreground 99 --bold "📝 Changes:"
        git diff "Formula/${FORMULA}.rb" | gum format -t code || git diff "Formula/${FORMULA}.rb"
        echo ""
    fi
    
    # Commit
    if gum confirm "Commit changes?"; then
        git add "Formula/${FORMULA}.rb"
        COMMIT_MSG="chore: update ${FORMULA} to v${VERSION}"
        git commit -m "$COMMIT_MSG"
        gum style --foreground 46 "✅ Committed: $COMMIT_MSG"
        echo ""
        
        # Push
        if gum confirm "Push to origin?"; then
            git push origin main
            echo ""
            gum style --border rounded --border-foreground 46 --padding "1 2" --align center --width 60 \
                "$(gum style --bold --foreground 46 "🚀 Released!")" \
                "" \
                "$(gum style --foreground 240 "brew install foxworth-uni/tap/${FORMULA}")"
        else
            echo ""
            gum style --foreground 240 "💡 To push: git push origin main"
        fi
    else
        echo ""
        gum style --foreground 240 "⚠️  Formula updated but not committed"
    fi

# List all formulae
list:
    @echo "📋 Available formulae:"
    @ls -1 Formula/*.rb | sed 's/Formula\//  • /' | sed 's/\.rb//'

# Test install a formula locally
test-install FORMULA:
    @echo "🧪 Testing {{ FORMULA }} installation..."
    brew uninstall {{ FORMULA }} 2>/dev/null || true
    brew install --build-from-source ./Formula/{{ FORMULA }}.rb
    {{ FORMULA }} --version || {{ FORMULA }} --help
    @echo "✅ Test successful"

