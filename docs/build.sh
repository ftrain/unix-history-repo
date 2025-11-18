#!/bin/bash
# Build script for PDP-7 Unix documentation

set -e  # Exit on error

echo "========================================="
echo "PDP-7 Unix Documentation Build System"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check for pandoc
if ! command -v pandoc &> /dev/null; then
    echo -e "${RED}Error: pandoc not found${NC}"
    echo "Please install pandoc:"
    echo "  Ubuntu/Debian: sudo apt-get install pandoc"
    echo "  macOS: brew install pandoc"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found pandoc $(pandoc --version | head -1)"

# Check for xelatex (for PDF)
if ! command -v xelatex &> /dev/null; then
    echo -e "${YELLOW}Warning: xelatex not found - PDF generation will fail${NC}"
    echo "Install texlive-xetex for PDF support"
fi

echo ""
echo "Building documentation..."
echo ""

# Run make
if make "$@"; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    ls -lh *.epub *.pdf 2>/dev/null || echo "Check 'make help' for available targets"
else
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}Build failed!${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
