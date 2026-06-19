# Outputs Directory

This directory contains all generated outputs from the analysis pipeline.

## Structure

```
outputs/
├── figures/    ← All plots (.png, .html interactive)
├── tables/     ← CSV exports of key results
└── reports/    ← Rendered R Markdown / Quarto reports
```

## Generated files

After running `R/01_load_clean.R` through `R/07_price_prediction.R`, the following files are created here:

| File | Script | Description |
|------|--------|-------------|
| `figures/01_monthly_transactions_top3_2022.png` | `02_eda_transactions.R` | Q1 main plot |
| `figures/01b_top15_suburbs_alltime.png` | `02_eda_transactions.R` | Q1 all-time ranking |
| `figures/02_keyword_price_impact.png` | `03_nlp_keywords.R` | Q2 keyword lift chart |
| `figures/03_price_area_correlations.png` | `04_correlation.R` | Q3 scatter plots |
| `figures/03b_correlation_heatmap.png` | `04_correlation.R` | Q3 heatmap |
| `figures/04_top5_capital_gains.png` | `05_capital_gains.R` | Q4 bar chart |
| `figures/04b_capital_gains_timeline.png` | `05_capital_gains.R` | Q4 price journey |
| `figures/06_predicted_prices_2026.png` | `07_price_prediction.R` | Q6 predictions |
| `tables/01_top_suburbs.csv` | `02_eda_transactions.R` | Top suburbs by volume |
| `tables/03_correlations.csv` | `04_correlation.R` | Full correlation table |
| `tables/04_top5_capital_gains.csv` | `05_capital_gains.R` | Top 5 gains |
| `tables/05_anomaly_summary.csv` | `06_anomaly_detection.R` | Anomaly table |
| `tables/06_predictions_july2026.csv` | `07_price_prediction.R` | 2026 price forecasts |

> Output files are excluded from git tracking (see `.gitignore`).
