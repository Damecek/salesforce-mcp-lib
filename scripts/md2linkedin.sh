#!/usr/bin/env bash
#
# md2linkedin.sh — Convert a Markdown file to rich HTML and copy it
# to the macOS clipboard so you can paste directly into LinkedIn's
# article editor with full formatting preserved.
#
# Usage:
#   ./scripts/md2linkedin.sh <file.md>
#   ./scripts/md2linkedin.sh specs/002-linkedin-content-system/content/my-article.md
#
# Options:
#   --preview   Also open a browser preview before copying
#   --dry-run   Print the HTML to stdout instead of copying
#
# Requirements (auto-installed on first run):
#   - pandoc (via Homebrew)
#   - Swift runtime (ships with Xcode / CLT)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_HELPER="$SCRIPT_DIR/pbcopy-html.swift"

# ── Colours ───────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No colour

# ── Argument parsing ──────────────────────────────────────
PREVIEW=false
DRY_RUN=false
MD_FILE=""

for arg in "$@"; do
    case "$arg" in
        --preview) PREVIEW=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            echo "Usage: md2linkedin.sh [--preview] [--dry-run] <file.md>"
            echo ""
            echo "Converts Markdown to rich HTML and copies it to the clipboard"
            echo "so you can paste directly into LinkedIn's article editor."
            echo ""
            echo "Options:"
            echo "  --preview   Open a browser preview before copying"
            echo "  --dry-run   Print the HTML to stdout instead of copying"
            echo "  -h, --help  Show this help"
            exit 0
            ;;
        *)
            if [[ -z "$MD_FILE" ]]; then
                MD_FILE="$arg"
            else
                echo -e "${RED}Error: unexpected argument '$arg'${NC}" >&2
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$MD_FILE" ]]; then
    echo -e "${RED}Error: No Markdown file specified.${NC}" >&2
    echo "Usage: md2linkedin.sh [--preview] [--dry-run] <file.md>" >&2
    exit 1
fi

if [[ ! -f "$MD_FILE" ]]; then
    echo -e "${RED}Error: File not found: $MD_FILE${NC}" >&2
    exit 1
fi

# ── Ensure pandoc is installed ────────────────────────────
if ! command -v pandoc &>/dev/null; then
    echo -e "${YELLOW}pandoc not found. Installing via Homebrew...${NC}"
    if ! command -v brew &>/dev/null; then
        echo -e "${RED}Error: Homebrew is not installed. Install it first:${NC}"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install pandoc
    echo -e "${GREEN}pandoc installed successfully.${NC}"
fi

# ── Ensure the Swift helper is compiled / executable ──────
if [[ ! -x "$SWIFT_HELPER" ]]; then
    chmod +x "$SWIFT_HELPER"
fi

# ── LinkedIn-optimised Pandoc CSS ─────────────────────────
# LinkedIn's editor strips most CSS but keeps basic inline styles
# and structural HTML. We use a minimal standalone template so that
# headings, lists, code blocks, and links survive the paste.
#
# Key choices:
#   • code blocks get a light-grey background (survives LinkedIn)
#   • no <style> block — LinkedIn strips it; we rely on structural HTML
#   • smart typography (curly quotes, em-dashes)

read -r -d '' PANDOC_TEMPLATE << 'TMPL' || true
$body$
TMPL

TEMPLATE_FILE=$(mktemp /tmp/md2li-tmpl-XXXXXX.html)
echo "$PANDOC_TEMPLATE" > "$TEMPLATE_FILE"

# ── Convert ───────────────────────────────────────────────
HTML=$(pandoc "$MD_FILE" \
    --from=markdown+smart \
    --to=html5 \
    --template="$TEMPLATE_FILE" \
    --no-highlight \
    --wrap=none \
)

rm -f "$TEMPLATE_FILE"

# ── Post-process: make code blocks LinkedIn-friendly ──────
# 1. Protect <pre><code> blocks by replacing them with a placeholder
# 2. Replace inline <code>...</code> with <b><i>...</i></b>
#    (LinkedIn doesn't render inline code — bold+italic is the convention)
# 3. Restore <pre><code> blocks with inline styles
HTML=$(echo "$HTML" | sed \
    -e 's/<pre><code[^>]*>/⟦PRE_OPEN⟧/g' \
    -e 's|</code></pre>|⟦PRE_CLOSE⟧|g' \
    -e 's|<code[^>]*>\([^<]*\)</code>|<b><i>\1</i></b>|g' \
    -e 's/⟦PRE_OPEN⟧/<pre style="background:#f4f4f4;padding:12px;border-radius:6px;overflow-x:auto;font-size:14px"><code style="font-family:monospace">/g' \
    -e 's|⟦PRE_CLOSE⟧|</code></pre>|g' \
)

# ── Output ────────────────────────────────────────────────
if $DRY_RUN; then
    echo "$HTML"
    echo ""
    echo -e "${GREEN}(dry-run — HTML printed above, not copied to clipboard)${NC}"
    exit 0
fi

# Preview in browser
if $PREVIEW; then
    PREVIEW_FILE=$(mktemp /tmp/md2li-preview-XXXXXX.html)
    cat > "$PREVIEW_FILE" <<PREVIEW_HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>LinkedIn Preview: $(basename "$MD_FILE")</title>
<style>
  body {
    max-width: 700px;
    margin: 40px auto;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    padding: 0 20px;
  }
  pre { background: #f4f4f4; padding: 12px; border-radius: 6px; overflow-x: auto; }
  code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; font-size: 14px; }
  blockquote { border-left: 3px solid #0a66c2; margin-left: 0; padding-left: 16px; color: #555; }
  a { color: #0a66c2; }
  img { max-width: 100%; }
  hr { border: none; border-top: 1px solid #ddd; margin: 24px 0; }
</style>
</head>
<body>
$HTML
</body>
</html>
PREVIEW_HTML
    open "$PREVIEW_FILE"
    echo -e "${GREEN}Preview opened in browser.${NC}"
    sleep 1
fi

# Copy rich HTML to clipboard
echo "$HTML" | "$SWIFT_HELPER"

WORD_COUNT=$(wc -w < "$MD_FILE" | tr -d ' ')
echo -e "${GREEN}Copied to clipboard!${NC}"
echo -e "  File:  $MD_FILE"
echo -e "  Words: $WORD_COUNT"
echo ""
echo -e "  ${YELLOW}Now paste (Cmd+V) into LinkedIn's article editor.${NC}"
