# 🏠 Melbourne Property Market Analysis (2010–2023)

[![R](https://img.shields.io/badge/R-4.3+-276DC3?style=flat&logo=r&logoColor=white)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shiny App](https://img.shields.io/badge/Shiny-Live%20Demo-blue?style=flat&logo=rstudio)](https://yourname.shinyapps.io/melbourne-property)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)]()

> An end-to-end data science project analysing **150,000+ Victorian property transactions** across 13 years, combining exploratory analysis, NLP, machine learning, and interactive visualisation to uncover actionable insights for buyers, investors, and the real estate industry.

---

## 📌 Problem Statement

Melbourne's property market is one of Australia's most dynamic and complex. This project investigates:

- **Which suburbs** drive the highest transaction volumes — and how did they behave in 2022?
- **What language** in property descriptions actually influences sale prices?
- **How strongly** does land size correlate with price across different property types?
- **Which properties** delivered the highest capital gains within 5 years of first sale?
- **What anomalies** exist in the data — properties that could not realistically exist?
- **What will a renovated 4-bed/2-bath house cost in July 2026** across six target suburbs?

---

## 🔑 Key Findings

| # | Finding | Value |
|---|---------|-------|
| 1 | Top suburb by transaction volume (2010–2023) | `[TBD after analysis]` |
| 2 | Most impactful keyword on property price | `[TBD after analysis]` |
| 3 | Strongest price–land size correlation | `[TBD after analysis]` |
| 4 | Highest capital gain in <5 years | `[TBD after analysis]` |
| 5 | Predicted price in Glen Waverley (Jul 2026) | `[TBD after analysis]` |

> 📄 Full findings in [`docs/executive_summary.pdf`](docs/executive_summary.pdf)

---

## 🗂️ Repository Structure

```
melbourne-property-analysis/
│
├── README.md                    ← You are here
├── LICENSE
├── .gitignore
│
├── data/
│   └── TaskC_property_victoria.csv    ← Raw dataset (not tracked by git)
│
├── R/                           ← Analysis scripts (run in order)
│   ├── 00_setup.R               ← Package installation & global settings
│   ├── 01_load_clean.R          ← Data loading, cleaning, type casting
│   ├── 02_eda_transactions.R    ← Q1: Top suburbs & monthly trends
│   ├── 03_nlp_keywords.R        ← Q2: NLP keyword extraction
│   ├── 04_correlation.R         ← Q3: Price vs land size correlations
│   ├── 05_capital_gains.R       ← Q4: Highest capital gain properties
│   ├── 06_anomaly_detection.R   ← Q5: Unrealistic property identification
│   └── 07_price_prediction.R    ← Q6: ML model & 2026 price forecast
│
├── shiny_app/                   ← Interactive dashboard
│   ├── app.R                    ← Main Shiny entry point
│   └── modules/
│       ├── mod_map.R            ← Leaflet map module
│       ├── mod_predict.R        ← Price prediction UI module
│       └── mod_trends.R         ← Transaction trend module
│
├── outputs/
│   ├── figures/                 ← All generated plots (.png / .html)
│   ├── reports/                 ← R Markdown rendered reports
│   └── tables/                  ← CSV exports of key results
│
└── docs/
    └── executive_summary.pdf    ← One-page business summary
```

---

## 🛠️ Tech Stack

| Category | Tools |
|----------|-------|
| Language | R 4.3+ |
| Data Wrangling | `tidyverse`, `lubridate`, `janitor` |
| NLP | `tidytext`, `tm`, `wordcloud2` |
| Machine Learning | `tidymodels`, `xgboost`, `ranger` |
| Visualisation | `ggplot2`, `plotly`, `leaflet` |
| Dashboard | `shiny`, `shinydashboard`, `bslib` |
| Reporting | `rmarkdown`, `knitr`, `gt` |

---

## 🚀 How to Run

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/melbourne-property-analysis.git
cd melbourne-property-analysis
```

### 2. Install dependencies
```r
# Run this first
source("R/00_setup.R")
```

### 3. Add the dataset
Place `TaskC_property_victoria.csv` inside the `data/` folder.

### 4. Run the analysis pipeline
```r
source("R/01_load_clean.R")
source("R/02_eda_transactions.R")
source("R/03_nlp_keywords.R")
source("R/04_correlation.R")
source("R/05_capital_gains.R")
source("R/06_anomaly_detection.R")
source("R/07_price_prediction.R")
```

### 5. Launch the Shiny dashboard
```r
shiny::runApp("shiny_app/")
```

---

## 📊 Sample Visualisations

> *(After running the analysis, plots are saved to `outputs/figures/`)*

- `01_monthly_transactions_top3_2022.png` — Monthly counts for top 3 suburbs + Toorak
- `02_nlp_wordcloud.png` — Keywords weighted by price impact
- `03_correlation_heatmap.png` — Price vs land size by suburb & property type
- `04_capital_gains_timeline.png` — Top 5 capital gain properties
- `05_anomalies_table.png` — Unrealistic property summary
- `06_predicted_prices_2026.png` — Predicted July 2026 prices for 6 suburbs

---

## 🧠 Methodology

### Q2 — NLP Keyword Analysis
A 10% stratified sample of the dataset was used. Property descriptions were cleaned (HTML tags removed, stopwords filtered), and TF-IDF was computed. Keywords were then correlated with log-transformed sale prices using linear regression to identify the top 3 price-driving terms.

### Q6 — Price Prediction Model
An XGBoost regression model was trained on the full 2010–2023 dataset with the following engineered features:

- Suburb (one-hot encoded)
- Property type
- Beds, baths, parking
- Land area
- Keyword flags: "renovated", "shopping centre", "primary school"
- Sold year + month (temporal features)

Model selection via 5-fold cross-validation. Final model predicts July 2026 prices for 6 suburbs under Chris's criteria.

---

## 📁 Data Description

| Column | Description |
|--------|-------------|
| `ID` | Unique property listing identifier |
| `postcode` | Victorian postcode |
| `suburb` | Suburb name |
| `sold_time` | Date of sale |
| `sold_price` | Sale price in AUD |
| `address` | Full street address |
| `beds` | Number of bedrooms |
| `baths` | Number of bathrooms |
| `parking` | Number of parking spaces |
| `area` | Land area in m² |
| `property_type` | house / unit / townhouse / apartment / etc. |
| `description` | Full listing description text |

**Dataset period:** 2010–2023 | **Geography:** Victoria, Australia

---

## 📄 License

This project is licensed under the MIT License — see [`LICENSE`](LICENSE) for details.

---

## 👤 Author

**Your Name**
- 🔗 LinkedIn: [www.linkedin.com/in/farzan-momayezi](www.linkedin.com/in/farzan-momayezi)
- 📧 Email: farzanmomayezi@gmail.com
  
---

*This project was developed as part of a data science portfolio to demonstrate skills in real estate analytics, NLP, and machine learning using Victorian property transaction data.*
