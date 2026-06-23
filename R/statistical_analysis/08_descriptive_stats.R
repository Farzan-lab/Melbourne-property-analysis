# =============================================================================
# 08_descriptive_stats.R — Comprehensive Descriptive Statistics
# Melbourne Property Market Analysis (2010–2023)
# =============================================================================
#
# RESEARCH QUESTIONS ADDRESSED:
#   RQ1: What is the distributional profile of Melbourne property prices,
#        and does the market exhibit log-normality?
#   RQ2: How do central tendency, dispersion, and shape metrics differ
#        across property types and geographic tiers?
#   RQ3: Is there evidence of a structural shift in price distribution
#        before and after the 2020 COVID-19 shock?
#
# TECHNIQUES: Summary statistics, distribution fitting, QQ-plots,
#             Shapiro-Wilk, skewness/kurtosis, violin + box plots,
#             coefficient of variation, Gini coefficient
# =============================================================================

source(here::here("R", "00_setup.R"))
library(moments)       # skewness, kurtosis
library(nortest)       # Anderson-Darling normality test
library(DescTools)     # Gini coefficient
library(broom)         # tidy model outputs

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# Restrict to residential sales with valid price > $50k
analysis_data <- prop_priced |>
  filter(
    property_type %in% c("house", "unit", "townhouse", "apartment"),
    sold_price > 50000,
    sold_year >= 2010
  ) |>
  mutate(log_price = log(sold_price))

message(glue("📊 Descriptive analysis: {nrow(analysis_data):,} records"))

# =============================================================================
# RQ1: Price distributional profile — does it follow log-normality?
# =============================================================================
message("\n── RQ1: Price distributional profile ──")

# Full summary
price_summary <- analysis_data |>
  summarise(
    n          = n(),
    mean       = mean(sold_price),
    median     = median(sold_price),
    sd         = sd(sold_price),
    cv         = sd / mean * 100,           # Coefficient of variation
    skewness   = skewness(sold_price),
    kurtosis   = kurtosis(sold_price) - 3,  # Excess kurtosis
    iqr        = IQR(sold_price),
    p10        = quantile(sold_price, 0.10),
    p25        = quantile(sold_price, 0.25),
    p75        = quantile(sold_price, 0.75),
    p90        = quantile(sold_price, 0.90),
    p99        = quantile(sold_price, 0.99),
    gini       = Gini(sold_price),
    min_price  = min(sold_price),
    max_price  = max(sold_price)
  )

message("Price distribution summary:")
price_summary |>
  pivot_longer(everything(), names_to = "metric", values_to = "value") |>
  mutate(value = case_when(
    str_detect(metric, "^(mean|median|sd|iqr|p[0-9]|min|max)") ~
      dollar(value, prefix = "$", big.mark = ",", accuracy = 1),
    TRUE ~ round(value, 4) |> as.character()
  )) |>
  print(n = 20)

# Normality tests on log-price (sample of 5000 for speed)
set.seed(42)
sample_log <- analysis_data |> slice_sample(n = min(5000, nrow(.))) |> pull(log_price)

sw_test <- shapiro.test(sample_log)
ad_test <- nortest::ad.test(sample_log)

message(glue(
  "\nNormality tests on log(price) [n = {length(sample_log)}]:",
  "\n  Shapiro-Wilk  W = {round(sw_test$statistic, 4)}, p = {format.pval(sw_test$p.value, digits=3)}",
  "\n  Anderson-Darling A = {round(ad_test$statistic, 4)}, p = {format.pval(ad_test$p.value, digits=3)}"
))

# Interpretation
if (sw_test$p.value > 0.05) {
  message("  → Log-price is consistent with normality (log-normal model appropriate)")
} else {
  message("  → Log-price departs from normality — heavier tails than log-normal")
}

# Plot 1: Price distribution — raw vs log
p_dist <- analysis_data |>
  slice_sample(n = min(50000, nrow(.))) |>
  pivot_longer(c(sold_price, log_price), names_to = "scale", values_to = "value") |>
  mutate(scale = recode(scale,
    sold_price = "Raw price (AUD)",
    log_price  = "Log price (ln AUD)"
  )) |>
  ggplot(aes(x = value)) +
  geom_histogram(aes(y = after_stat(density)), bins = 60,
                 fill = PALETTE["blue"], alpha = 0.7, color = "white", linewidth = 0.1) +
  geom_density(color = PALETTE["coral"], linewidth = 1) +
  facet_wrap(~scale, scales = "free", ncol = 2) +
  labs(
    title    = "Property Price Distribution — Raw vs Log Scale",
    subtitle = glue("n = {comma(nrow(analysis_data))} | Skewness (raw): {round(price_summary$skewness, 2)}"),
    x        = NULL,
    y        = "Density",
    caption  = "Curve = kernel density estimate"
  )
save_plot(p_dist, "08a_price_distribution.png", width = 12, height = 5)

# Plot 2: QQ-plot for log-normality
p_qq <- ggplot(slice_sample(analysis_data, n = 5000), aes(sample = log_price)) +
  stat_qq(color = PALETTE["blue"], alpha = 0.3, size = 0.8) +
  stat_qq_line(color = PALETTE["coral"], linewidth = 1) +
  labs(
    title    = "Normal Q-Q Plot — Log(Price)",
    subtitle = glue("Shapiro-Wilk p = {format.pval(sw_test$p.value, digits=3)}"),
    x        = "Theoretical quantiles",
    y        = "Sample quantiles",
    caption  = "Deviation from line → departure from log-normality"
  )
save_plot(p_qq, "08b_qqplot_logprice.png", width = 7, height = 6)

# =============================================================================
# RQ2: Distribution metrics by property type
# =============================================================================
message("\n── RQ2: Metrics by property type ──")

by_type <- analysis_data |>
  group_by(property_type) |>
  summarise(
    n        = n(),
    mean     = mean(sold_price),
    median   = median(sold_price),
    sd       = sd(sold_price),
    cv_pct   = sd / mean * 100,
    skewness = skewness(sold_price),
    gini     = Gini(sold_price),
    p25      = quantile(sold_price, 0.25),
    p75      = quantile(sold_price, 0.75),
    .groups  = "drop"
  ) |>
  arrange(desc(median))

message("Stats by property type:")
print(by_type, n = 10)

# Plot 3: Violin + box plot by type
p_violin <- analysis_data |>
  filter(sold_price < quantile(sold_price, 0.99)) |>
  ggplot(aes(x = reorder(property_type, sold_price, median),
             y = sold_price / 1e6, fill = property_type)) +
  geom_violin(alpha = 0.5, trim = TRUE, scale = "width") +
  geom_boxplot(width = 0.15, outlier.shape = NA, alpha = 0.8,
               color = "grey30", linewidth = 0.5) +
  stat_summary(fun = median, geom = "point",
               shape = 21, size = 3, fill = "white", color = "grey30") +
  scale_fill_manual(values = unname(PALETTE), guide = "none") +
  scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
  labs(
    title    = "Price Distribution by Property Type",
    subtitle = "Violin width ∝ density | Box = IQR | Point = median | Capped at 99th percentile",
    x        = NULL,
    y        = "Sale price (AUD millions)",
    caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
  )
save_plot(p_violin, "08c_violin_by_type.png", width = 10, height = 6)

# =============================================================================
# RQ3: Pre-COVID vs post-COVID distribution shift (2019 vs 2020–2021)
# =============================================================================
message("\n── RQ3: Pre- vs post-COVID price distribution ──")

covid_data <- analysis_data |>
  filter(
    property_type == "house",
    sold_year %in% c(2018, 2019, 2020, 2021, 2022, 2023)
  ) |>
  mutate(
    period = case_when(
      sold_year %in% c(2018, 2019) ~ "Pre-COVID (2018–19)",
      sold_year %in% c(2020, 2021) ~ "COVID (2020–21)",
      sold_year %in% c(2022, 2023) ~ "Post-COVID (2022–23)"
    )
  )

covid_summary <- covid_data |>
  group_by(period) |>
  summarise(
    n        = n(),
    median   = median(sold_price),
    mean     = mean(sold_price),
    sd       = sd(sold_price),
    skewness = skewness(sold_price),
    .groups  = "drop"
  )

message("Pre/during/post-COVID house prices:")
print(covid_summary)

p_covid <- covid_data |>
  filter(sold_price < quantile(sold_price, 0.99)) |>
  ggplot(aes(x = sold_price / 1e6, fill = period, color = period)) +
  geom_density(alpha = 0.35, linewidth = 0.9) +
  geom_vline(
    data = covid_summary,
    aes(xintercept = median / 1e6, color = period),
    linetype = "dashed", linewidth = 0.8
  ) +
  scale_fill_manual(values  = c(PALETTE["blue"], PALETTE["amber"], PALETTE["teal"])) +
  scale_color_manual(values = c(PALETTE["blue"], PALETTE["amber"], PALETTE["teal"])) +
  scale_x_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
  labs(
    title    = "Melbourne House Price Distribution: COVID Period Comparison",
    subtitle = "Dashed lines = median price for each period",
    x        = "Sale price (AUD millions)",
    y        = "Density",
    fill     = NULL,
    color    = NULL,
    caption  = "House sales only | Capped at 99th percentile"
  )
save_plot(p_covid, "08d_covid_price_shift.png", width = 11, height = 6)

# Save stats
write_csv(by_type,       file.path(DIR_TABLES, "08_stats_by_type.csv"))
write_csv(covid_summary, file.path(DIR_TABLES, "08_covid_comparison.csv"))

message("\n✅ 08_descriptive_stats.R complete")
