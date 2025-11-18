# Makefile for PDP-7 Unix Documentation
# Generates EPUB and PDF from markdown sources

# Output files
BOOK_TITLE = pdp7-unix-complete-reference
EPUB_FILE = $(BOOK_TITLE).epub
PDF_FILE = $(BOOK_TITLE).pdf
HTML_FILE = $(BOOK_TITLE).html

# Source files in order
METADATA = metadata.yaml
FRONTMATTER = 00-frontmatter.md

CHAPTERS = \
	chapters/01-introduction.md \
	chapters/02-hardware.md \
	chapters/03-assembly.md \
	chapters/04-architecture.md \
	chapters/05-kernel.md \
	chapters/06-boot-initialization.md \
	chapters/07-filesystem.md \
	chapters/08-process-management.md \
	chapters/09-device-drivers.md \
	chapters/10-development-tools.md \
	chapters/11-user-utilities.md \
	chapters/12-b-language.md \
	chapters/13-evolution.md \
	chapters/14-legacy.md

APPENDICES = \
	appendices/a-instruction-reference.md \
	appendices/b-syscall-reference.md \
	appendices/c-sysmap.md \
	appendices/glossary.md \
	appendices/e-index.md \
	appendices/f-bibliography.md

# All markdown sources
SOURCES = $(FRONTMATTER) $(CHAPTERS) $(APPENDICES)

# Pandoc options
PANDOC = pandoc
PANDOC_OPTS = --toc --toc-depth=3 --number-sections

# PDF-specific options
PDF_OPTS = \
	--pdf-engine=xelatex \
	-V geometry:margin=1in \
	-V fontsize=11pt \
	-V documentclass=book \
	-V papersize=letter \
	--highlight-style=tango

# EPUB-specific options
EPUB_OPTS = \
	--epub-cover-image=images/cover.png \
	--epub-metadata=metadata.yaml \
	--highlight-style=tango

# HTML-specific options
HTML_OPTS = \
	--standalone \
	--self-contained \
	--highlight-style=tango \
	--css=styles.css

# Default target
all: $(EPUB_FILE) $(PDF_FILE)

# Generate EPUB
$(EPUB_FILE): $(METADATA) $(SOURCES)
	@echo "Generating EPUB..."
	$(PANDOC) $(PANDOC_OPTS) $(EPUB_OPTS) \
		$(METADATA) $(SOURCES) \
		-o $(EPUB_FILE)
	@echo "✓ EPUB generated: $(EPUB_FILE)"

# Generate PDF
$(PDF_FILE): $(METADATA) $(SOURCES)
	@echo "Generating PDF..."
	$(PANDOC) $(PANDOC_OPTS) $(PDF_OPTS) \
		$(METADATA) $(SOURCES) \
		-o $(PDF_FILE)
	@echo "✓ PDF generated: $(PDF_FILE)"

# Generate HTML
$(HTML_FILE): $(METADATA) $(SOURCES)
	@echo "Generating HTML..."
	$(PANDOC) $(PANDOC_OPTS) $(HTML_OPTS) \
		$(METADATA) $(SOURCES) \
		-o $(HTML_FILE)
	@echo "✓ HTML generated: $(HTML_FILE)"

# Generate all formats
formats: $(EPUB_FILE) $(PDF_FILE) $(HTML_FILE)

# Check if all required files exist
check:
	@echo "Checking for required files..."
	@for file in $(METADATA) $(SOURCES); do \
		if [ ! -f $$file ]; then \
			echo "✗ Missing: $$file"; \
			exit 1; \
		fi \
	done
	@echo "✓ All required files present"

# Count statistics
stats:
	@echo "=== Documentation Statistics ==="
	@echo "Chapters: $(words $(CHAPTERS))"
	@echo "Appendices: $(words $(APPENDICES))"
	@echo "Total files: $(words $(SOURCES))"
	@echo ""
	@echo "=== Line Counts ==="
	@wc -l $(SOURCES) | tail -1
	@echo ""
	@echo "=== Word Counts ==="
	@wc -w $(SOURCES) | tail -1
	@echo ""
	@echo "=== File Sizes ==="
	@du -ch $(SOURCES) | tail -1

# Preview in system's EPUB reader
preview-epub: $(EPUB_FILE)
	@echo "Opening EPUB..."
	@xdg-open $(EPUB_FILE) 2>/dev/null || open $(EPUB_FILE) 2>/dev/null || echo "Please open $(EPUB_FILE) manually"

# Preview PDF
preview-pdf: $(PDF_FILE)
	@echo "Opening PDF..."
	@xdg-open $(PDF_FILE) 2>/dev/null || open $(PDF_FILE) 2>/dev/null || echo "Please open $(PDF_FILE) manually"

# Clean generated files
clean:
	rm -f $(EPUB_FILE) $(PDF_FILE) $(HTML_FILE)
	@echo "✓ Cleaned generated files"

# Deep clean (including temporary files)
distclean: clean
	find . -name "*~" -delete
	find . -name "*.bak" -delete
	@echo "✓ Deep clean complete"

# Help
help:
	@echo "PDP-7 Unix Documentation Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build EPUB and PDF (default)"
	@echo "  epub         - Build EPUB only"
	@echo "  pdf          - Build PDF only"
	@echo "  html         - Build standalone HTML"
	@echo "  formats      - Build all formats (EPUB, PDF, HTML)"
	@echo "  check        - Verify all source files exist"
	@echo "  stats        - Show documentation statistics"
	@echo "  preview-epub - Open generated EPUB"
	@echo "  preview-pdf  - Open generated PDF"
	@echo "  clean        - Remove generated files"
	@echo "  distclean    - Remove all generated and temporary files"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - pandoc (2.0+)"
	@echo "  - xelatex (for PDF generation)"
	@echo ""
	@echo "Usage:"
	@echo "  make          # Build EPUB and PDF"
	@echo "  make epub     # Build just EPUB"
	@echo "  make stats    # Show statistics"

# Individual targets
epub: $(EPUB_FILE)
pdf: $(PDF_FILE)
html: $(HTML_FILE)

.PHONY: all epub pdf html formats check stats preview-epub preview-pdf clean distclean help
