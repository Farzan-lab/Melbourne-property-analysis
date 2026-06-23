#!/usr/bin/env bash
# =============================================================================
# run_pipeline.sh — Melbourne Property Analysis: Full Pipeline Orchestrator
# =============================================================================
# Usage:
#   ./shell/run_pipeline.sh              # run full pipeline
#   ./shell/run_pipeline.sh --stage eda  # run specific stage only
#   ./shell/run_pipeline.sh --dry-run    # validate environment only
# =============================================================================

set -euo pipefail          # exit on error, unset variable, pipe failure
IFS=$'\n\t'                # safer word splitting

# ---------- colour helpers ---------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_section() { echo -e "\n${BOLD}${BLUE}══════ $* ══════${RESET}"; }

# ---------- defaults ---------------------------------------------------------
STAGE="all"
DRY_RUN=false
SKIP_TESTS=false
LOG_DIR="logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/pipeline_${TIMESTAMP}.log"

# ---------- argument parsing -------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --stage)     STAGE="$2";     shift 2 ;;
    --dry-run)   DRY_RUN=true;   shift ;;
    --skip-tests)SKIP_TESTS=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--stage STAGE] [--dry-run] [--skip-tests]"
      echo "Stages: setup | clean | eda | nlp | stats | model | all"
      exit 0 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ---------- setup ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

mkdir -p "$LOG_DIR" outputs/figures outputs/tables outputs/reports data

# Redirect all output to log AND terminal
exec > >(tee -a "$LOG_FILE") 2>&1

# ---------- banner -----------------------------------------------------------
echo -e "${BOLD}"
cat << 'BANNER'
  ███╗   ███╗███████╗██╗     ██████╗  ██████╗ ██╗   ██╗██████╗ ███╗   ██╗███████╗
  ████╗ ████║██╔════╝██║     ██╔══██╗██╔═══██╗██║   ██║██╔══██╗████╗  ██║██╔════╝
  ██╔████╔██║█████╗  ██║     ██████╔╝██║   ██║██║   ██║██████╔╝██╔██╗ ██║█████╗
  ██║╚██╔╝██║██╔══╝  ██║     ██╔══██╗██║   ██║██║   ██║██╔══██╗██║╚██╗██║██╔══╝
  ██║ ╚═╝ ██║███████╗███████╗██████╔╝╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║███████╗
  ╚═╝     ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝
  Property Market Analysis Pipeline — Victoria 2010–2023
BANNER
echo -e "${RESET}"

log_info "Pipeline started at: $(date)"
log_info "Project root: $PROJECT_ROOT"
log_info "Log file: $LOG_FILE"
log_info "Stage: $STAGE | Dry run: $DRY_RUN"

# ---------- environment check ------------------------------------------------
log_section "Environment Validation"

check_command() {
  if command -v "$1" &>/dev/null; then
    log_ok "$1 found: $(command -v "$1")"
  else
    log_error "$1 not found. Please install it."
    exit 1
  fi
}

check_command Rscript
check_command python3
check_command awk
check_command sed

# Check R version
R_VERSION=$(Rscript -e "cat(R.version\$major, R.version\$minor, sep='.')" 2>/dev/null)
log_info "R version: $R_VERSION"

# Check required R packages
log_info "Checking R packages..."
MISSING_PKGS=$(Rscript -e "
pkgs <- c('tidyverse','lubridate','tidytext','tidymodels','xgboost',
          'ranger','leaflet','shiny','bslib','DT','plotly',
          'lmtest','car','sandwich','survival','forecast','tseries')
missing <- pkgs[!pkgs %in% installed.packages()[,'Package']]
if (length(missing)) cat(paste(missing, collapse=','))
" 2>/dev/null)

if [[ -n "$MISSING_PKGS" ]]; then
  log_warn "Missing R packages: $MISSING_PKGS"
  log_info "Run: Rscript R/00_setup.R to install"
  [[ "$DRY_RUN" == true ]] || Rscript R/00_setup.R
else
  log_ok "All R packages present"
fi

# Check dataset
DATA_FILE="data/TaskC_property_victoria.csv"
if [[ -f "$DATA_FILE" ]]; then
  ROW_COUNT=$(awk 'NR>1' "$DATA_FILE" | wc -l | tr -d ' ')
  FILE_SIZE=$(du -sh "$DATA_FILE" | cut -f1)
  log_ok "Dataset found: $ROW_COUNT rows | $FILE_SIZE"
else
  log_error "Dataset not found: $DATA_FILE"
  log_error "Please place TaskC_property_victoria.csv in the data/ directory"
  exit 1
fi

[[ "$DRY_RUN" == true ]] && { log_ok "Dry run complete — environment OK"; exit 0; }

# ---------- helper: run R script with timing ---------------------------------
run_r_script() {
  local script="$1"
  local label="$2"
  log_info "Running: $script"
  local start_time=$SECONDS
  if Rscript "$script"; then
    local elapsed=$((SECONDS - start_time))
    log_ok "$label completed in ${elapsed}s"
  else
    log_error "$label FAILED (see log: $LOG_FILE)"
    exit 1
  fi
}

# ---------- stage: setup -----------------------------------------------------
run_stage_setup() {
  log_section "Stage: Setup & Data Loading"
  run_r_script "R/00_setup.R"       "Package setup"
  run_r_script "R/01_load_clean.R"  "Data loading & cleaning"

  # Quick data quality report via awk
  log_info "Quick data quality scan (awk)..."
  awk -F',' 'NR==1 { next }
    {
      total++
      if ($5 == "NA" || $5 == "") missing_price++
      if ($7 == "NA" || $7 == "") missing_beds++
      if ($10 == "NA" || $10 == "") missing_area++
    }
    END {
      printf "  Total records  : %d\n", total
      printf "  Missing price  : %d (%.1f%%)\n", missing_price, missing_price/total*100
      printf "  Missing beds   : %d (%.1f%%)\n", missing_beds,  missing_beds/total*100
      printf "  Missing area   : %d (%.1f%%)\n", missing_area,  missing_area/total*100
    }' "$DATA_FILE"
}

# ---------- stage: eda -------------------------------------------------------
run_stage_eda() {
  log_section "Stage: Exploratory Data Analysis"
  run_r_script "R/02_eda_transactions.R" "Transaction EDA"
  run_r_script "R/03_nlp_keywords.R"    "NLP keyword analysis"
  run_r_script "R/04_correlation.R"     "Correlation analysis"
  run_r_script "R/05_capital_gains.R"   "Capital gains"
  run_r_script "R/06_anomaly_detection.R" "Anomaly detection"
}

# ---------- stage: stats -----------------------------------------------------
run_stage_stats() {
  log_section "Stage: Statistical Modelling"
  run_r_script "R/statistical_analysis/08_descriptive_stats.R"   "Descriptive stats"
  run_r_script "R/statistical_analysis/09_hypothesis_testing.R"  "Hypothesis testing"
  run_r_script "R/statistical_analysis/10_regression_analysis.R" "Regression analysis"
  run_r_script "R/statistical_analysis/11_time_series.R"         "Time-series analysis"
  run_r_script "R/statistical_analysis/12_survival_analysis.R"   "Survival analysis"
}

# ---------- stage: model -----------------------------------------------------
run_stage_model() {
  log_section "Stage: ML Price Prediction"
  run_r_script "R/07_price_prediction.R" "Price prediction model"
}

# ---------- dispatch ---------------------------------------------------------
case "$STAGE" in
  setup)  run_stage_setup ;;
  eda)    run_stage_setup; run_stage_eda ;;
  stats)  run_stage_stats ;;
  model)  run_stage_model ;;
  all)
    run_stage_setup
    run_stage_eda
    run_stage_stats
    run_stage_model
    ;;
  *) log_error "Unknown stage: $STAGE"; exit 1 ;;
esac

# ---------- output summary ---------------------------------------------------
log_section "Pipeline Complete"

OUTPUT_COUNT=$(find outputs/ -type f \( -name "*.png" -o -name "*.csv" -o -name "*.html" \) 2>/dev/null | wc -l | tr -d ' ')
log_ok "Outputs generated: $OUTPUT_COUNT files"

echo ""
echo -e "${BOLD}Figures:${RESET}"
find outputs/figures/ -name "*.png" 2>/dev/null | sort | sed 's/^/  ✓ /'

echo ""
echo -e "${BOLD}Tables:${RESET}"
find outputs/tables/ -name "*.csv" 2>/dev/null | sort | sed 's/^/  ✓ /'

echo ""
log_ok "All stages complete. Total runtime: $((SECONDS))s"
log_info "Full log saved to: $LOG_FILE"
echo ""
echo -e "${GREEN}To launch the Shiny dashboard:${RESET}"
echo -e "  Rscript -e \"shiny::runApp('shiny_app/')\" \n"
