#!/usr/bin/env bash
# =============================================================================
# setup_environment.sh — Bootstrap development environment
# =============================================================================
# Sets up the full project: directories, R packages, git hooks, Python venv
# Usage: ./shell/setup_environment.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; RESET='\033[0m'

ok()      { echo -e "  ${GREEN}✓${RESET} $*"; }
info()    { echo -e "  ${BLUE}→${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET} $*"; }
section() { echo -e "\n${BOLD}${BLUE}── $* ──${RESET}"; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BOLD}Setting up Melbourne Property Analysis environment${RESET}"
echo -e "Project root: $PROJECT_ROOT\n"

# ---- 1. Directory structure -------------------------------------------------
section "Creating directory structure"

dirs=(
  "data"
  "logs"
  "R"
  "R/statistical_analysis"
  "shell"
  "shiny_app/modules"
  "outputs/figures"
  "outputs/tables"
  "outputs/reports"
  "docs"
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
  ok "mkdir -p $d"
done

# ---- 2. Shell scripts permissions ------------------------------------------
section "Setting script permissions"

find shell/ -name "*.sh" -exec chmod +x {} \;
ok "chmod +x shell/*.sh"

# ---- 3. Git setup -----------------------------------------------------------
section "Git setup"

if [[ ! -d ".git" ]]; then
  git init
  ok "git init"
else
  ok "Git already initialised"
fi

# Pre-commit hook: validate R syntax before committing
HOOK_FILE=".git/hooks/pre-commit"
cat > "$HOOK_FILE" << 'HOOK'
#!/usr/bin/env bash
# Pre-commit: check R syntax on staged .R files
echo "Running R syntax check..."
staged_r=$(git diff --cached --name-only --diff-filter=ACM | grep '\.R$' || true)
if [[ -n "$staged_r" ]]; then
  for f in $staged_r; do
    if ! Rscript --vanilla -e "parse('$f')" 2>/dev/null; then
      echo "Syntax error in $f — commit aborted"
      exit 1
    fi
  done
  echo "R syntax OK"
fi
exit 0
HOOK
chmod +x "$HOOK_FILE"
ok "Git pre-commit hook installed (R syntax check)"

# ---- 4. R packages ----------------------------------------------------------
section "Installing R packages"

Rscript --vanilla << 'RSCRIPT'
pkgs <- c(
  "tidyverse", "lubridate", "janitor", "here", "glue",
  "tidytext", "tm", "SnowballC",
  "tidymodels", "xgboost", "ranger", "vip", "Metrics",
  "ggplot2", "plotly", "scales", "patchwork", "ggcorrplot",
  "leaflet", "sf",
  "shiny", "shinydashboard", "bslib", "shinyWidgets", "DT",
  "rmarkdown", "knitr", "gt",
  # Statistical analysis packages
  "lmtest", "car", "sandwich", "MASS",
  "survival", "survminer",
  "tseries", "forecast", "zoo",
  "nortest", "moments", "DescTools",
  "emmeans", "effectsize", "broom"
)
new <- pkgs[!pkgs %in% installed.packages()[,"Package"]]
if (length(new) > 0) {
  cat("Installing:", paste(new, collapse=", "), "\n")
  install.packages(new, repos="https://cran.rstudio.com/", quiet=TRUE)
  cat("Done.\n")
} else {
  cat("All packages already installed.\n")
}
RSCRIPT
ok "R packages installed"

# ---- 5. Python virtual environment (for supplementary scripts) -------------
section "Python environment"

if command -v python3 &>/dev/null; then
  if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
    .venv/bin/pip install --quiet pandas matplotlib seaborn scipy
    ok "Python venv created (.venv/)"
    echo ".venv/" >> .gitignore 2>/dev/null || true
  else
    ok "Python venv already exists"
  fi
else
  warn "python3 not found — skipping venv setup"
fi

# ---- 6. Environment variables template -------------------------------------
section "Environment configuration"

if [[ ! -f ".env.example" ]]; then
  cat > .env.example << 'ENV'
# Copy to .env and fill in your values
# (never commit .env to git)
DATA_PATH=data/TaskC_property_victoria.csv
OUTPUT_DIR=outputs
LOG_LEVEL=INFO
SHINY_HOST=127.0.0.1
SHINY_PORT=3838
ENV
  ok ".env.example created"
fi

# ---- 7. Final summary -------------------------------------------------------
section "Setup complete"

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  1. Place TaskC_property_victoria.csv in data/"
echo "  2. Run: ./shell/validate_data.sh"
echo "  3. Run: ./shell/run_pipeline.sh"
echo "  4. Run: Rscript -e \"shiny::runApp('shiny_app/')\""
echo ""
echo -e "${GREEN}Environment ready.${RESET}\n"
