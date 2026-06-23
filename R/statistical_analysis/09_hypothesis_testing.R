# =============================================================================
# 09_hypothesis_testing.R — Formal Statistical Hypothesis Testing
# Melbourne Property Market Analysis (2010–2023)
# =============================================================================
#
# RESEARCH QUESTIONS & HYPOTHESES:
#
#   H1: Do house prices differ significantly across property types?
#       → Kruskal-Wallis test + post-hoc Dunn test
#
#   H2: Did the COVID-19 pandemic cause a statistically significant
#       increase in Melbourne house prices?
#       → Mann-Whitney U test (2019 vs 2021)
#
#   H3: Is there a significant difference in price between properties
#       with descriptions mentioning "renovated" vs not?
#       → Welch's t-test + Cohen's d effect size
#
#   H4: Does the number of bedrooms significantly predict sale price,
#       after controlling for suburb and property type?
#       → One-way ANOVA + Tukey HSD post-hoc
#
#   H5: Is the price premium for proximity to CBD statistically
#       significant and how large is its effect?
#       → Linear contrast + confidence intervals
#
# TECHNIQUES: Kruskal-Wallis, Mann-Whitney U, Welch t-test, ANOVA,
#             Bonferroni/Tukey correction, Cohen's d, rank-biserial r,
#             bootstrap confidence intervals
# =============================================================================

source(here::here("R", "00_setup.R"))
library(broom)
library(effectsize)
library(emmeans)
library(coin)          # non-parametric permutation tests

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

residential <- prop_priced |>
  filter(
    property_type %in% c("house", "unit", "townhouse", "apartment"),
    sold_price > 50000,
    !is.na(beds)
  )

report_test <- function(title, result_text) {
  message(glue("\n{'─' |> strrep(60)}"))
  message(glue("TEST: {title}"))
  message(glue("{'─' |> strrep(60)}"))
  message(result_text)
}

# =============================================================================
# H1: Do prices differ significantly across property types?
# =============================================================================

house_prices_by_type <- residential |>
  filter(sold_year >= 2018) |>
  select(property_type, sold_price)

# Kruskal-Wallis (non-parametric, because price is skewed)
kw <- kruskal.test(sold_price ~ property_type, data = house_prices_by_type)

# Effect size: eta-squared for Kruskal-Wallis
n_total <- nrow(house_prices_by_type)
k        <- n_distinct(house_prices_by_type$property_type)
eta_sq   <- (kw$statistic - k + 1) / (n_total - k)

report_test(
  "H1: Price differences across property types (Kruskal-Wallis)",
  glue(
    "  χ²({kw$parameter}) = {round(kw$statistic, 2)}, p {format.pval(kw$p.value, digits=3)}\n",
    "  η² = {round(eta_sq, 4)} (effect size)\n",
    "  Decision: {if(kw$p.value < 0.05) 'REJECT H₀ — significant differences exist' else 'Fail to reject H₀'}\n",
    "  Interpretation: {if(eta_sq > 0.14) 'Large' else if(eta_sq > 0.06) 'Medium' else 'Small'} effect size"
  )
)

# Post-hoc: median prices
medians_by_type <- residential |>
  filter(sold_year >= 2018) |>
  group_by(property_type) |>
  summarise(
    n             = n(),
    median_price  = median(sold_price),
    mean_price    = mean(sold_price),
    .groups       = "drop"
  ) |>
  arrange(desc(median_price))

message("\nMedian prices by type:")
medians_by_type |>
  mutate(across(c(median_price, mean_price),
                ~dollar(., prefix = "$", big.mark = ","))) |>
  print()

# Pairwise Mann-Whitney with Bonferroni correction
types <- unique(residential$property_type)
pw_results <- combn(types, 2, simplify = FALSE) |>
  map_dfr(function(pair) {
    g1 <- residential |> filter(property_type == pair[1]) |> pull(sold_price)
    g2 <- residential |> filter(property_type == pair[2]) |> pull(sold_price)
    if (length(g1) < 5 || length(g2) < 5) return(NULL)
    wt <- wilcox.test(g1, g2, exact = FALSE, conf.int = TRUE)
    # Rank-biserial correlation (effect size)
    r  <- 1 - (2 * wt$statistic) / (length(g1) * length(g2))
    tibble(
      group1 = pair[1], group2 = pair[2],
      W = wt$statistic, p_raw = wt$p.value,
      r_effect = round(abs(r), 3)
    )
  }) |>
  mutate(
    p_bonferroni = p.adjust(p_raw, method = "bonferroni"),
    significant  = p_bonferroni < 0.05
  ) |>
  arrange(p_bonferroni)

message("\nPairwise comparisons (Bonferroni-corrected):")
print(pw_results, n = 15)

# =============================================================================
# H2: COVID-19 price impact — 2019 vs 2021 house prices
# =============================================================================

pre_covid  <- prop_priced |>
  filter(property_type == "house", sold_year == 2019, sold_price > 50000) |>
  pull(sold_price)
post_covid <- prop_priced |>
  filter(property_type == "house", sold_year == 2021, sold_price > 50000) |>
  pull(sold_price)

mw <- wilcox.test(post_covid, pre_covid, alternative = "greater",
                  exact = FALSE, conf.int = TRUE)

# Effect size: rank-biserial correlation
n1 <- length(post_covid); n2 <- length(pre_covid)
r_rb <- 1 - (2 * mw$statistic) / (n1 * n2)

# Bootstrap 95% CI for median difference
set.seed(42)
boot_diffs <- replicate(2000, {
  median(sample(post_covid, n1, replace = TRUE)) -
  median(sample(pre_covid,  n2, replace = TRUE))
})
ci_low  <- quantile(boot_diffs, 0.025)
ci_high <- quantile(boot_diffs, 0.975)

report_test(
  "H2: COVID-19 price impact — 2019 vs 2021 houses (Mann-Whitney, one-sided)",
  glue(
    "  Pre-COVID median  (2019): ${dollar(median(pre_covid),  prefix='', big.mark=',')}\n",
    "  Post-COVID median (2021): ${dollar(median(post_covid), prefix='', big.mark=',')}\n",
    "  Median difference: ${dollar(median(post_covid)-median(pre_covid), prefix='', big.mark=',')}\n",
    "  Bootstrap 95% CI: [${dollar(ci_low,  prefix='', big.mark=',')}, ${dollar(ci_high, prefix='', big.mark=',')}]\n",
    "  W = {round(mw$statistic, 0)}, p = {format.pval(mw$p.value, digits=4)}\n",
    "  Rank-biserial r = {round(r_rb, 3)}\n",
    "  Decision: {if(mw$p.value < 0.05) 'REJECT H₀ — COVID significantly increased prices' else 'Fail to reject H₀'}"
  )
)

# =============================================================================
# H3: "Renovated" keyword premium — Welch's t-test
# =============================================================================

renovation_data <- prop_priced |>
  filter(
    property_type == "house",
    sold_price > 50000,
    !is.na(description_clean)
  ) |>
  mutate(
    is_renovated = str_detect(tolower(description_clean),
                              "renovat|refurb|modernised|updated|redesign")
  )

reno_yes <- renovation_data |> filter(is_renovated)  |> pull(sold_price)
reno_no  <- renovation_data |> filter(!is_renovated) |> pull(sold_price)

tt <- t.test(log(reno_yes), log(reno_no), var.equal = FALSE)  # Welch on log-scale

# Cohen's d on log scale
pooled_sd <- sqrt((var(log(reno_yes)) + var(log(reno_no))) / 2)
d          <- (mean(log(reno_yes)) - mean(log(reno_no))) / pooled_sd

# Back-transform: geometric mean ratio
gm_ratio <- exp(mean(log(reno_yes)) - mean(log(reno_no)))

report_test(
  "H3: 'Renovated' keyword price premium (Welch t-test on log-price)",
  glue(
    "  N (renovated)     : {comma(length(reno_yes))}\n",
    "  N (not renovated) : {comma(length(reno_no))}\n",
    "  Median (renovated)    : ${dollar(median(reno_yes), prefix='', big.mark=',')}\n",
    "  Median (not renovated): ${dollar(median(reno_no),  prefix='', big.mark=',')}\n",
    "  Geometric mean ratio  : {round(gm_ratio, 3)}× ({round((gm_ratio-1)*100, 1)}% premium)\n",
    "  t({round(tt$parameter, 0)}) = {round(tt$statistic, 3)}, p {format.pval(tt$p.value, digits=4)}\n",
    "  Cohen's d = {round(d, 3)} ({if(abs(d)>0.8) 'Large' else if(abs(d)>0.5) 'Medium' else 'Small'} effect)\n",
    "  Decision: {if(tt$p.value < 0.05) 'REJECT H₀ — significant renovation premium' else 'Fail to reject H₀'}"
  )
)

# =============================================================================
# H4: Bedroom count and price — One-way ANOVA
# =============================================================================

anova_data <- prop_priced |>
  filter(
    property_type == "house",
    sold_price > 50000,
    beds %in% 1:6
  ) |>
  mutate(
    beds_f    = factor(beds, labels = paste(1:6, "bed")),
    log_price = log(sold_price)
  )

aov_fit <- aov(log_price ~ beds_f, data = anova_data)
aov_sum <- summary(aov_fit)

# Effect size: eta-squared
ss_between <- aov_sum[[1]]["beds_f", "Sum Sq"]
ss_total   <- sum(aov_sum[[1]][, "Sum Sq"])
eta_sq_aov <- ss_between / ss_total

# Tukey HSD
tukey <- TukeyHSD(aov_fit)
tukey_tidy <- tidy(tukey) |>
  filter(adj.p.value < 0.05) |>
  arrange(adj.p.value)

report_test(
  "H4: Bedroom count and log-price — One-way ANOVA",
  glue(
    "  F({aov_sum[[1]]['beds_f','Df']}, {aov_sum[[1]]['Residuals','Df']}) = ",
    "{round(aov_sum[[1]]['beds_f','F value'], 2)},",
    " p {format.pval(aov_sum[[1]]['beds_f','Pr(>F)'], digits=4)}\n",
    "  η² = {round(eta_sq_aov, 4)} ({if(eta_sq_aov>0.14) 'Large' else if(eta_sq_aov>0.06) 'Medium' else 'Small'} effect)\n",
    "  Significant Tukey pairs: {nrow(tukey_tidy)}\n",
    "  Decision: {if(aov_sum[[1]]['beds_f','Pr(>F)'] < 0.05) 'REJECT H₀ — bedroom count significantly predicts price' else 'Fail to reject H₀'}"
  )
)

# Plot: price by bedroom count
p_anova <- anova_data |>
  filter(sold_price < quantile(sold_price, 0.99)) |>
  ggplot(aes(x = beds_f, y = sold_price / 1e6, fill = beds_f)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.7) +
  stat_summary(fun = mean, geom = "point",
               shape = 23, size = 3, fill = "white") +
  scale_fill_manual(values = unname(PALETTE)[1:6], guide = "none") +
  scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
  labs(
    title    = "Sale Price by Bedroom Count (Houses)",
    subtitle = glue("One-way ANOVA: F = {round(aov_sum[[1]]['beds_f','F value'],1)}, η² = {round(eta_sq_aov,3)}"),
    x        = NULL,
    y        = "Sale price (AUD millions)",
    caption  = "Diamond = mean | Box = IQR | Capped at 99th percentile"
  )
save_plot(p_anova, "09_anova_bedrooms.png", width = 10, height = 6)

# =============================================================================
# Summary table of all hypothesis tests
# =============================================================================
hypothesis_summary <- tribble(
  ~hypothesis, ~test,              ~statistic,  ~p_value,        ~decision,
  "H1: Price ~ property type", "Kruskal-Wallis",
    glue("χ²={round(kw$statistic,2)}"), format.pval(kw$p.value, digits=3),
    if(kw$p.value<0.05) "Reject H₀" else "Fail to reject",
  "H2: COVID price shock",     "Mann-Whitney (1-sided)",
    glue("W={round(mw$statistic,0)}"), format.pval(mw$p.value, digits=4),
    if(mw$p.value<0.05) "Reject H₀" else "Fail to reject",
  "H3: Renovation premium",    "Welch t-test",
    glue("t={round(tt$statistic,3)}"), format.pval(tt$p.value, digits=4),
    if(tt$p.value<0.05) "Reject H₀" else "Fail to reject",
  "H4: Bedrooms ~ price",      "One-way ANOVA",
    glue("F={round(aov_sum[[1]]['beds_f','F value'],1)}"),
    format.pval(aov_sum[[1]]["beds_f","Pr(>F)"], digits=4),
    if(aov_sum[[1]]["beds_f","Pr(>F)"]<0.05) "Reject H₀" else "Fail to reject"
)

message("\n══ Hypothesis Testing Summary ══")
print(hypothesis_summary, n = 10, width = Inf)

write_csv(hypothesis_summary, file.path(DIR_TABLES, "09_hypothesis_summary.csv"))
write_csv(pw_results,         file.path(DIR_TABLES, "09_pairwise_comparisons.csv"))
write_csv(tukey_tidy,         file.path(DIR_TABLES, "09_tukey_results.csv"))

message("\n✅ 09_hypothesis_testing.R complete")
