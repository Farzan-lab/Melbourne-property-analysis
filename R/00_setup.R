# ============================================================
# 00_setup.R — Package Installation & Global Settings
# Melbourne Property Market Analysis (2010–2023)
# ============================================================

# ----- Install required packages (run once) -----------------
packages <- c(
  # Data wrangling
  "tidyverse", "lubridate", "janitor", "readr",
  # NLP
  "tidytext", "tm", "SnowballC", "wordcloud2", "topicmodels",
  # Machine Learning
  "tidymodels", "xgboost", "ranger", "vip", "Metrics",
  # Visualisation
  "ggplot2", "plotly", "scales", "ggcorrplot", "patchwork",
  # Geospatial
  "leaflet", "sf",
  # Shiny
  "shiny", "shinydashboard", "bslib", "shinyWidgets", "DT",
  # Reporting
  "rmarkdown", "knitr", "gt", "kableExtra",
  # Utilities
  "here", "glue", "tictoc"
)

new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(new_packages) > 0) {
  message("Installing: ", paste(new_packages, collapse = ", "))
  install.packages(new_packages, repos = "https://cran.rstudio.com/")
}

# ----- Load core libraries ----------------------------------
library(tidyverse)
library(lubridate)
library(janitor)
library(here)
library(glue)
library(scales)

# ----- Global settings --------------------------------------
theme_set(
  theme_minimal(base_size = 13) +
    theme(
      plot.title    = element_text(face = "bold", size = 15, margin = margin(b = 8)),
      plot.subtitle = element_text(color = "grey50", margin = margin(b = 12)),
      plot.caption  = element_text(color = "grey60", size = 9, hjust = 0),
      panel.grid.minor = element_blank(),
      legend.position  = "bottom"
    )
)

# Melbourne property colour palette
PALETTE <- c(
  blue    = "#185FA5",
  teal    = "#1D9E75",
  amber   = "#BA7517",
  coral   = "#D85A30",
  purple  = "#534AB7",
  gray    = "#5F5E5A"
)

# ----- Directory paths (using here package) -----------------
DIR_DATA    <- here("data")
DIR_R       <- here("R")
DIR_FIGURES <- here("outputs", "figures")
DIR_TABLES  <- here("outputs", "tables")
DIR_REPORTS <- here("outputs", "reports")

# Create output directories if they don't exist
walk(c(DIR_FIGURES, DIR_TABLES, DIR_REPORTS), dir.create, showWarnings = FALSE, recursive = TRUE)

# ----- Save plot helper -------------------------------------
save_plot <- function(plot, filename, width = 10, height = 6, dpi = 150) {
  path <- file.path(DIR_FIGURES, filename)
  ggsave(path, plot = plot, width = width, height = height, dpi = dpi)
  message(glue("✔ Saved: {path}"))
  invisible(plot)
}

message("✅ Setup complete. Run scripts 01–07 in order.")
