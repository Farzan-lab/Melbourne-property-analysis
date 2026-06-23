#!/usr/bin/env bash
# =============================================================================
# generate_report.sh — Render all R Markdown / Quarto reports
# =============================================================================
# Usage: ./shell/generate_report.sh [--format html|pdf|all]
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
info() { echo -e "  ${BLUE}→${RESET} $*"; }

FORMAT="${1:---format}"
VALUE="${2:-html}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

REPORT_DIR="outputs/reports"
mkdir -p "$REPORT_DIR"

echo -e "${BOLD}Generating reports...${RESET}"
echo "Format: $VALUE | Output: $REPORT_DIR"
echo ""

# Render function
render_rmd() {
  local src="$1"
  local out="$2"
  local fmt="$3"

  if [[ -f "$src" ]]; then
    info "Rendering: $src → $out"
    Rscript -e "
      rmarkdown::render(
        '$src',
        output_format = '$fmt',
        output_file   = '$out',
        output_dir    = '$REPORT_DIR',
        quiet         = TRUE
      )
    " && ok "Done: $REPORT_DIR/$out"
  else
    echo "  – Skipping (not found): $src"
  fi
}

# ---- Reports to render ------------------------------------------------------
render_rmd "docs/01_data_quality_report.Rmd"    "data_quality_report.html"    "html_document"
render_rmd "docs/02_statistical_report.Rmd"     "statistical_report.html"     "html_document"
render_rmd "docs/03_model_evaluation_report.Rmd" "model_evaluation.html"      "html_document"
render_rmd "docs/executive_summary.Rmd"          "executive_summary.html"     "html_document"

# ---- Compile outputs index (HTML) ------------------------------------------
info "Generating outputs index..."
{
  echo "<!DOCTYPE html><html><head><meta charset='UTF-8'>"
  echo "<title>Melbourne Property Analysis — Report Index</title>"
  echo "<style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px}"
  echo "h1{color:#185FA5}a{color:#1D9E75}li{margin:8px 0}</style></head><body>"
  echo "<h1>🏠 Melbourne Property Analysis</h1>"
  echo "<p>Generated: $(date)</p><ul>"
  find "$REPORT_DIR" -name "*.html" | sort | while read -r f; do
    name=$(basename "$f")
    echo "<li><a href='$name'>$name</a></li>"
  done
  echo "</ul></body></html>"
} > "$REPORT_DIR/index.html"

ok "Index created: $REPORT_DIR/index.html"
echo ""
echo -e "${GREEN}${BOLD}All reports generated.${RESET}"
echo -e "Open: open $REPORT_DIR/index.html\n"
