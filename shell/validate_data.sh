#!/usr/bin/env bash
# =============================================================================
# validate_data.sh — Deep Data Quality & Integrity Checks
# =============================================================================
# Demonstrates: awk, sed, grep, sort, uniq, cut, wc, bc arithmetic
# Usage: ./shell/validate_data.sh [path/to/dataset.csv]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

DATA_FILE="${1:-data/TaskC_property_victoria.csv}"
REPORT_DIR="outputs/reports"
REPORT_FILE="${REPORT_DIR}/data_validation_$(date +%Y%m%d).txt"
mkdir -p "$REPORT_DIR"

banner() { echo -e "\n${BOLD}${BLUE}▶ $*${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET} $*"; }
fail()   { echo -e "  ${RED}✗${RESET} $*"; }

echo -e "${BOLD}Melbourne Property Dataset — Validation Report${RESET}"
echo -e "Generated: $(date)"
echo -e "File: $DATA_FILE\n"

# ============================================================================
# 1. FILE-LEVEL CHECKS
# ============================================================================
banner "1. File-level checks"

if [[ ! -f "$DATA_FILE" ]]; then
  fail "File not found: $DATA_FILE"; exit 1
fi

FILE_SIZE=$(du -sh "$DATA_FILE" | cut -f1)
TOTAL_LINES=$(wc -l < "$DATA_FILE")
TOTAL_RECORDS=$((TOTAL_LINES - 1))   # subtract header
HEADER=$(head -1 "$DATA_FILE")
COL_COUNT=$(echo "$HEADER" | awk -F',' '{print NF}')

ok "File size   : $FILE_SIZE"
ok "Total rows  : $TOTAL_RECORDS records"
ok "Columns     : $COL_COUNT"
ok "Header      : $HEADER"

# Check for Windows line endings (CRLF)
if file "$DATA_FILE" | grep -q "CRLF"; then
  warn "Windows line endings detected — may need dos2unix"
else
  ok "Line endings: Unix (LF)"
fi

# ============================================================================
# 2. COLUMN-BY-COLUMN MISSING VALUE ANALYSIS
# ============================================================================
banner "2. Missing value analysis (per column)"

awk -F',' '
NR == 1 {
  for (i = 1; i <= NF; i++) header[i] = $i
  ncols = NF
  next
}
{
  total++
  for (i = 1; i <= ncols; i++) {
    if ($i == "NA" || $i == "" || $i == "NULL") missing[i]++
  }
}
END {
  printf "  %-25s %10s %10s %8s\n", "Column", "Missing", "Present", "Missing%"
  printf "  %-25s %10s %10s %8s\n", "------", "-------", "-------", "--------"
  for (i = 1; i <= ncols; i++) {
    m = (missing[i] ? missing[i] : 0)
    p = total - m
    pct = (m / total) * 100
    flag = (pct > 30) ? " ⚠" : ""
    printf "  %-25s %10d %10d %7.1f%%%s\n", header[i], m, p, pct, flag
  }
  printf "\n  Total records: %d\n", total
}' "$DATA_FILE"

# ============================================================================
# 3. PRICE DISTRIBUTION ANALYSIS
# ============================================================================
banner "3. Price distribution (sold_price column)"

awk -F',' '
NR == 1 { next }
$5 != "NA" && $5 != "" && $5+0 > 0 {
  price = $5 + 0
  sum += price
  count++
  prices[count] = price
  if (price < min || min == 0) min = price
  if (price > max) max = price
}
END {
  mean = sum / count
  # Variance
  for (i = 1; i <= count; i++) sq_sum += (prices[i] - mean)^2
  std = sqrt(sq_sum / count)

  # Sort for median/percentiles (bubble sort — small enough for awk)
  n = count
  for (i = 1; i <= n; i++)
    for (j = i+1; j <= n; j++)
      if (prices[i] > prices[j]) { tmp=prices[i]; prices[i]=prices[j]; prices[j]=tmp }

  median = (n % 2) ? prices[int(n/2)+1] : (prices[n/2] + prices[n/2+1]) / 2
  p25 = prices[int(n*0.25)]
  p75 = prices[int(n*0.75)]
  p90 = prices[int(n*0.90)]
  p99 = prices[int(n*0.99)]

  printf "  Count       : %d\n",   count
  printf "  Min         : $%s\n",  format_num(min)
  printf "  P25         : $%s\n",  format_num(p25)
  printf "  Median      : $%s\n",  format_num(median)
  printf "  Mean        : $%s\n",  format_num(mean)
  printf "  P75         : $%s\n",  format_num(p75)
  printf "  P90         : $%s\n",  format_num(p90)
  printf "  P99         : $%s\n",  format_num(p99)
  printf "  Max         : $%s\n",  format_num(max)
  printf "  Std Dev     : $%s\n",  format_num(std)
  printf "  Skewness    : %.2f (positive = right-skewed)\n", \
    (mean - median) / std * 3
}
function format_num(n,    s) {
  s = sprintf("%.0f", n)
  # Basic comma formatting
  while (s ~ /[0-9][0-9][0-9][0-9]/) {
    sub(/([0-9])([0-9][0-9][0-9])([^0-9]|$)/, "\\1,\\2\\3", s)
  }
  return s
}' "$DATA_FILE"

# ============================================================================
# 4. PROPERTY TYPE DISTRIBUTION
# ============================================================================
banner "4. Property type distribution"

awk -F',' '
NR == 1 { next }
$11 != "NA" && $11 != "" {
  gsub(/\r/, "", $11)
  types[$11]++
  total++
}
END {
  printf "  %-25s %8s %8s\n", "Property Type", "Count", "Percent"
  printf "  %-25s %8s %8s\n", "-------------", "-----", "-------"
  # Print in sorted order
  for (t in types) print types[t], t
}' "$DATA_FILE" | sort -rn | head -20 | \
awk '{ total += $1; data[NR] = $0 }
END {
  for (i = 1; i <= NR; i++) {
    split(data[i], a, " ")
    pct = a[1] / total * 100
    printf "  %-25s %8d %7.1f%%\n", a[2], a[1], pct
  }
}'

# ============================================================================
# 5. TEMPORAL COVERAGE
# ============================================================================
banner "5. Temporal coverage (transactions by year)"

awk -F',' '
NR == 1 { next }
$4 != "NA" && $4 != "" {
  # Extract year from M/D/YYYY format
  n = split($4, parts, "/")
  if (n == 3) years[parts[3]]++
}
END {
  printf "  %-6s %8s\n", "Year", "Count"
  printf "  %-6s %8s\n", "----", "-----"
}' "$DATA_FILE"

# Use sort to get chronological order
awk -F',' '
NR == 1 { next }
$4 != "NA" && $4 != "" {
  n = split($4, parts, "/")
  if (n >= 3 && length(parts[3]) == 4) years[parts[3]]++
}
END {
  for (y in years) print y, years[y]
}' "$DATA_FILE" | sort -k1n | awk '{ printf "  %-6s %8d\n", $1, $2 }'

# ============================================================================
# 6. TOP 10 SUBURBS BY VOLUME
# ============================================================================
banner "6. Top 10 suburbs by transaction volume"

awk -F',' 'NR > 1 && $3 != "" && $3 != "NA" { print $3 }' "$DATA_FILE" | \
  sed 's/\r//' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-30s %6d\n", $2, $1 }'

# ============================================================================
# 7. DATA ANOMALY FLAGS
# ============================================================================
banner "7. Anomaly flags"

# Negative area values
NEG_AREA=$(awk -F',' 'NR>1 && $10 ~ /^-[0-9]/' "$DATA_FILE" | wc -l | tr -d ' ')
warn "Negative area values      : $NEG_AREA"

# Suspiciously low prices (< $1,000)
LOW_PRICE=$(awk -F',' 'NR>1 && $5+0 > 0 && $5+0 < 1000' "$DATA_FILE" | wc -l | tr -d ' ')
warn "Prices under \$1,000       : $LOW_PRICE"

# Extreme bedroom counts (> 10)
HIGH_BEDS=$(awk -F',' 'NR>1 && $7+0 > 10' "$DATA_FILE" | wc -l | tr -d ' ')
warn "Bedrooms > 10             : $HIGH_BEDS"

# Properties with 0 beds (non-land)
ZERO_BEDS=$(awk -F',' 'NR>1 && $7 == "0" && $11 !~ /land/' "$DATA_FILE" | wc -l | tr -d ' ')
warn "Zero-bed non-land props   : $ZERO_BEDS"

# ============================================================================
# 8. SAVE REPORT
# ============================================================================
banner "8. Summary"

# Re-run to capture everything into report file
{
  echo "Melbourne Property Dataset — Validation Report"
  echo "Generated: $(date)"
  echo "File: $DATA_FILE"
  echo "Records: $TOTAL_RECORDS"
  echo "---"
  echo "Negative area: $NEG_AREA"
  echo "Low prices: $LOW_PRICE"
  echo "High beds: $HIGH_BEDS"
  echo "Zero beds (non-land): $ZERO_BEDS"
} > "$REPORT_FILE"

ok "Report saved to: $REPORT_FILE"
echo -e "\n${GREEN}${BOLD}Validation complete.${RESET}\n"
