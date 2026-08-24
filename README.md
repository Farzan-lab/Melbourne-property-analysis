# 🏠 Melbourne Property Market Analysis (2010–2023)

[![R](https://img.shields.io/badge/R-4.3+-276DC3?style=flat&logo=r&logoColor=white)](https://www.r-project.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shiny App](https://img.shields.io/badge/Shiny-Live%20Demo-blue?style=flat&logo=rstudio)](https://yourname.shinyapps.io/melbourne-property)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)]()

> End-to-end data science project analysing **150,000+ Victorian property transactions** across 13 years. Combines shell automation, exploratory analysis, formal statistical inference, NLP, machine learning, and an interactive Shiny dashboard.

---

## 📌 Problem Statement

Melbourne's property market is one of Australia's most complex. This project answers 14 research questions across 5 analytical domains:

| Domain | Questions |
|--------|-----------|
| 📊 Descriptive Statistics | Price distributions, log-normality, COVID structural shift |
| 🧪 Hypothesis Testing | Property-type price differences, renovation premium, COVID shock |
| 📈 Regression | Hedonic pricing, diminishing returns on land, quantile effects |
| 📉 Time Series | STL decomposition, unit root tests, ARIMA forecast |
| ⏱️ Survival Analysis | Holding periods, Cox PH model of resale behaviour |

---

## 🗂️ Repository Structure

```
melbourne-property-analysis/
│
├── shell/                          ← Bash automation scripts
│   ├── run_pipeline.sh             ← Full pipeline orchestrator (main entry point)
│   ├── validate_data.sh            ← Data quality checks (awk/sed/grep)
│   ├── setup_environment.sh        ← Bootstrap environment & git hooks
│   └── generate_report.sh          ← Render all R Markdown reports
│
├── R/                              ← Core analysis (run in order)
│   ├── 00_setup.R                  ← Packages, theme, helpers
│   ├── 01_load_clean.R             ← Load, parse, clean
│   ├── 02_eda_transactions.R       ← Q1: Top suburbs & 2022 monthly trends
│   ├── 03_nlp_keywords.R           ← Q2: NLP keyword price impact
│   ├── 04_correlation.R            ← Q3: Price–area correlation
│   ├── 05_capital_gains.R          ← Q4: Highest capital gains
│   ├── 06_anomaly_detection.R      ← Q5: Unrealistic properties
│   ├── 07_price_prediction.R       ← Q6: XGBoost 2026 forecast
│   │
│   └── statistical_analysis/       ← Advanced statistical modelling
│       ├── 08_descriptive_stats.R  ← RQ1–3: Distributions, normality, COVID shift
│       ├── 09_hypothesis_testing.R ← RQ4–5: Kruskal-Wallis, t-test, ANOVA
│       ├── 10_regression_analysis.R← RQ6–9: Hedonic model, quantile regression
│       ├── 11_time_series.R        ← RQ10–11: STL, ADF/KPSS, ARIMA
│       └── 12_survival_analysis.R  ← RQ12–14: KM curves, Cox PH model
│
├── shiny_app/                      ← Interactive dashboard
│   ├── app.R
│   └── modules/
│       ├── mod_trends.R
│       ├── mod_predict.R
│       └── mod_map.R
│
├── data/                           ← Raw & processed data (CSV not tracked)
├── outputs/figures/                ← Generated plots
├── outputs/tables/                 ← CSV result exports
├── outputs/reports/                ← Rendered HTML reports
├── docs/                           ← R Markdown source for reports
└── logs/                           ← Pipeline run logs
```

---

## 🚀 Quick Start

```bash
# 1. Clone
git clone https://github.com/yourusername/melbourne-property-analysis.git
cd melbourne-property-analysis

# 2. Bootstrap environment (installs R packages, sets up git hooks)
chmod +x shell/*.sh
./shell/setup_environment.sh

# 3. Add dataset
cp /path/to/TaskC_property_victoria.csv data/

# 4. Validate data quality
./shell/validate_data.sh

# 5. Run full pipeline
./shell/run_pipeline.sh

# 6. Run specific stage only
./shell/run_pipeline.sh --stage stats

# 7. Dry run (environment check only)
./shell/run_pipeline.sh --dry-run

# 8. Launch dashboard
Rscript -e "shiny::runApp('shiny_app/')"
```

---

## 🧪 Statistical Research Questions

### Descriptive Analysis
| RQ | Question | Method |
|----|----------|--------|
| RQ1 | Is the price distribution log-normal? | Shapiro-Wilk, Anderson-Darling, QQ plot |
| RQ2 | How do dispersion metrics vary by property type? | CV, Gini coefficient, violin plots |
| RQ3 | Did COVID structurally shift the price distribution? | KDE comparison, summary stats |

### Hypothesis Testing
| H | Null Hypothesis | Test | Key Result |
|---|-----------------|------|------------|
| H1 | Prices equal across property types | Kruskal-Wallis | `[run to see]` |
| H2 | COVID did NOT increase prices (2019 vs 2021) | Mann-Whitney U | `[run to see]` |
| H3 | "Renovated" keyword has no price effect | Welch t-test | `[run to see]` |
| H4 | Bedroom count does not predict price | One-way ANOVA + Tukey | `[run to see]` |

### Regression Modelling
| RQ | Question | Method |
|----|----------|--------|
| RQ4 | What structural features drive price? | OLS hedonic model + robust SE |
| RQ5 | Linear or diminishing returns on land area? | Log-log vs polynomial, AIC |
| RQ6 | Do determinants differ by price segment? | Quantile regression (τ=0.25/0.50/0.75/0.90) |
| RQ7 | Has bedroom value changed over time? | Interaction model: beds × year |

### Time Series
| RQ | Question | Method |
|----|----------|--------|
| RQ8 | What are trend/seasonal/noise components? | STL decomposition |
| RQ9 | Is the series stationary? | ADF test, KPSS test |
| RQ10 | What does ARIMA forecast for 2024–25? | auto.arima + prediction intervals |

### Survival Analysis
| RQ | Question | Method |
|----|----------|--------|
| RQ12 | How long do owners hold before reselling? | Kaplan-Meier + log-rank |
| RQ13 | What predicts faster resale? | Cox Proportional Hazards |
| RQ14 | Did COVID change holding behaviour? | Stratified KM by era |

---

## 🛠️ Tech Stack

| Category | Tools |
|----------|-------|
| Shell automation | Bash, awk, sed, grep, tee |
| Data wrangling | R, tidyverse, lubridate, janitor |
| Statistics | lmtest, car, sandwich, nortest, moments, DescTools |
| Survival analysis | survival, survminer |
| Time series | tseries, forecast, zoo |
| NLP | tidytext, tm, SnowballC |
| Machine learning | tidymodels, xgboost, ranger, vip |
| Visualisation | ggplot2, plotly, leaflet, patchwork |
| Dashboard | shiny, bslib, DT, shinyWidgets |

---

## 👤 Author

**Your Name**
- 🔗 LinkedIn: [linkedin.com/in/farzan-momayezi](https://www.linkedin.com/in/farzan-momayezi)
- 📧 Email: farzanmomayezi@gmail.com
- 🌐 Portfolio: [yourportfolio.com](https://yourportfolio.com)

*This project was developed as part of a data science portfolio to demonstrate end-to-end skills in real estate analytics, NLP, machine learning, shell scripting, statistical inference, and interactive visualisation using Victorian property transaction data.*
