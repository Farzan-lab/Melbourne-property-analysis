# =============================================================================
# 12_survival_analysis.R — Survival Analysis: Time-to-Resale
# Melbourne Property Market Analysis (2010–2023)
# =============================================================================
#
# RESEARCH QUESTIONS:
#
#   RQ12: How long do Melbourne homeowners hold their properties
#         before reselling, and does this differ by property type,
#         suburb tier, and market conditions?
#         → Kaplan-Meier survival curves + log-rank test
#
#   RQ13: What factors predict faster resale (shorter holding period)?
#         → Cox Proportional Hazards model
#         (hazard = probability of resale per unit time)
#
#   RQ14: Did the COVID boom change holding period behaviour?
#         → KM stratified by era + log-rank test
#
# FRAMING:
#   "Survival" = holding the property (not yet resold)
#   "Event"    = resale (resold within the dataset period)
#   "Censored" = property bought but not resold by end of 2023
#
# TECHNIQUES: Kaplan-Meier, log-rank test, Cox PH, Schoenfeld residuals,
#             median survival, survival probability at fixed time points
# =============================================================================

source(here::here("R", "00_setup.R"))
library(survival)
library(survminer)

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# =============================================================================
# Build survival dataset: pair first and subsequent sales of same property
# =============================================================================
message("Building holding-period dataset...")

# Properties sold at least twice
multi_sales <- prop_priced |>
  filter(!is.na(address), !is.na(sold_date), !is.na(sold_price)) |>
  arrange(address, sold_date) |>
  group_by(address) |>
  mutate(
    prev_sale_date  = lag(sold_date),
    prev_sale_price = lag(sold_price),
    sale_number     = row_number()
  ) |>
  filter(sale_number > 1) |>           # Second+ sales only
  ungroup() |>
  mutate(
    holding_days   = as.numeric(sold_date - prev_sale_date),
    holding_years  = holding_days / 365.25,
    resold         = 1L                 # Event occurred (resale observed)
  ) |>
  filter(
    holding_days > 90,                 # Exclude likely errors/flips < 3 months
    holding_days < 20 * 365,           # Exclude > 20 years (likely data issue)
    property_type %in% c("house", "unit", "townhouse", "apartment")
  )

# Single-sale properties = censored (held since purchase, not yet resold)
single_sales <- prop_priced |>
  filter(!is.na(address)) |>
  group_by(address) |>
  filter(n() == 1) |>
  ungroup() |>
  mutate(
    # Time from purchase to end of dataset = censored holding time
    holding_days   = as.numeric(as.Date("2023-12-31") - sold_date),
    holding_years  = holding_days / 365.25,
    resold         = 0L                 # Censored: not yet resold
  ) |>
  filter(
    holding_days > 0,
    property_type %in% c("house", "unit", "townhouse", "apartment")
  )

surv_data <- bind_rows(multi_sales, single_sales) |>
  mutate(
    era = case_when(
      sold_year <= 2015 ~ "2010–2015",
      sold_year <= 2019 ~ "2016–2019",
      sold_year <= 2021 ~ "2020–2021 (COVID)",
      TRUE              ~ "2022–2023"
    ),
    suburb_tier = case_when(
      sold_price >= 2e6 ~ "Luxury (≥$2M)",
      sold_price >= 1e6 ~ "Premium ($1M–$2M)",
      sold_price >= 5e5 ~ "Mid-market ($500K–$1M)",
      TRUE              ~ "Affordable (<$500K)"
    )
  )

message(glue(
  "Survival dataset:\n",
  "  Observed resales  : {sum(surv_data$resold):,}\n",
  "  Censored (no resale): {sum(!surv_data$resold):,}\n",
  "  Median holding period: {round(median(surv_data[surv_data$resold==1,'holding_years']$holding_years), 1)} years (resold only)"
))

# =============================================================================
# RQ12: Kaplan-Meier curves — by property type
# =============================================================================
message("\n── RQ12: Kaplan-Meier holding period analysis ──")

# Create survival object
surv_obj <- Surv(time  = surv_data$holding_years,
                 event = surv_data$resold)

# KM by property type
km_type <- survfit(surv_obj ~ property_type, data = surv_data)

# Log-rank test
lr_type <- survdiff(surv_obj ~ property_type, data = surv_data)
lr_pval <- 1 - pchisq(lr_type$chisq, df = length(lr_type$n) - 1)

message(glue("Log-rank test (property type): χ² = {round(lr_type$chisq,2)}, p = {format.pval(lr_pval,4)}"))

# Median survival by type
km_summary <- summary(km_type)$table |>
  as_tibble(rownames = "type") |>
  select(type, n = records, events, `median`)

message("\nMedian holding period by property type:")
print(km_summary)

# KM plot
p_km_type <- ggsurvplot(
  km_type,
  data        = surv_data,
  fun         = "event",        # Plot cumulative events (resale probability)
  conf.int    = TRUE,
  pval        = TRUE,
  risk.table  = FALSE,
  palette     = unname(PALETTE[c("blue","teal","amber","coral")]),
  legend.title = "Property type",
  title        = "Cumulative Resale Probability by Property Type",
  subtitle     = "0% = no resales yet | 100% = all properties resold",
  xlab         = "Years since purchase",
  ylab         = "Probability of resale",
  xlim         = c(0, 15),
  ggtheme      = theme_minimal(base_size = 12)
)

ggsave(
  file.path(DIR_FIGURES, "12a_km_by_type.png"),
  plot   = print(p_km_type),
  width  = 10, height = 7, dpi = 150
)
message("✔ Saved: 12a_km_by_type.png")

# KM by era
km_era <- survfit(surv_obj ~ era, data = surv_data)
lr_era <- survdiff(surv_obj ~ era, data = surv_data)
lr_era_p <- 1 - pchisq(lr_era$chisq, df = length(lr_era$n) - 1)

message(glue("\nLog-rank test (era): χ² = {round(lr_era$chisq,2)}, p = {format.pval(lr_era_p,4)}"))

p_km_era <- ggsurvplot(
  km_era,
  data         = surv_data,
  fun          = "event",
  conf.int     = TRUE,
  pval         = TRUE,
  palette      = unname(PALETTE[c("blue","amber","coral","teal")]),
  legend.title = "Market era",
  title        = "Cumulative Resale Probability by Market Era",
  subtitle     = "Did COVID change holding behaviour?",
  xlab         = "Years since purchase",
  ylab         = "Probability of resale",
  xlim         = c(0, 12),
  ggtheme      = theme_minimal(base_size = 12)
)

ggsave(
  file.path(DIR_FIGURES, "12b_km_by_era.png"),
  plot   = print(p_km_era),
  width  = 10, height = 7, dpi = 150
)
message("✔ Saved: 12b_km_by_era.png")

# =============================================================================
# RQ13: Cox Proportional Hazards Model
# =============================================================================
message("\n── RQ13: Cox Proportional Hazards Model ──")

cox_data <- surv_data |>
  filter(!is.na(sold_price), !is.na(beds)) |>
  mutate(
    log_price_prev = log(coalesce(prev_sale_price, sold_price)),
    beds_c         = pmin(coalesce(beds, 3), 6),
    type_house     = as.integer(property_type == "house"),
    era_covid      = as.integer(era == "2020–2021 (COVID)")
  )

cox_fit <- coxph(
  Surv(holding_years, resold) ~
    type_house + beds_c + log_price_prev + era_covid,
  data = cox_data
)

cox_tidy <- tidy(cox_fit, exponentiate = TRUE, conf.int = TRUE) |>
  mutate(
    term = recode(term,
      type_house     = "House (vs unit/apt)",
      beds_c         = "Bedrooms",
      log_price_prev = "Log(prior price)",
      era_covid      = "COVID era (2020–21)"
    ),
    interpretation = case_when(
      conf.low > 1  ~ glue("{round((estimate-1)*100,1)}% higher hazard of resale"),
      conf.high < 1 ~ glue("{round((1-estimate)*100,1)}% lower hazard of resale"),
      TRUE          ~ "Not significant"
    )
  )

message("\nCox PH Model — Hazard Ratios (HR > 1 = faster resale):")
cox_tidy |>
  select(term, estimate, conf.low, conf.high, p.value, interpretation) |>
  mutate(across(c(estimate, conf.low, conf.high), ~round(., 3))) |>
  print()

# Proportional hazards assumption: Schoenfeld residuals
ph_test <- cox.zph(cox_fit)
message("\nSchoenfeld test (PH assumption — p > 0.05 = PH holds):")
print(ph_test$table)

# Forest plot
p_cox <- cox_tidy |>
  mutate(term = fct_rev(term)) |>
  ggplot(aes(x = term, y = estimate, ymin = conf.low, ymax = conf.high)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_pointrange(color = PALETTE["blue"], fatten = 4) +
  coord_flip() +
  scale_y_log10() +
  labs(
    title    = "Cox Proportional Hazards — Resale Hazard Ratios",
    subtitle = "HR > 1 = faster resale | HR < 1 = slower resale | 95% CI",
    x        = NULL,
    y        = "Hazard ratio (log scale)",
    caption  = "Survival = holding property | Event = resale"
  )
save_plot(p_cox, "12c_cox_forest.png", width = 9, height = 5)

# Save results
write_csv(cox_tidy, file.path(DIR_TABLES, "12_cox_results.csv"))
write_csv(km_summary, file.path(DIR_TABLES, "12_km_median_survival.csv"))

message("\n✅ 12_survival_analysis.R complete")
