# ============================================================
# 04_correlation.R — Q3: Price vs Land Size Correlations
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: Compute correlation between price and land size
#   for each of the top 3 suburbs × property types
#   (house, unit, townhouse, apartment). Skip if no data.
# ============================================================

source(here::here("R", "00_setup.R"))
library(ggcorrplot)

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# ---- 1. Top 3 suburbs (from Q1 results or recompute) --------
top3_suburbs <- prop_priced |>
  count(suburb, sort = TRUE) |>
  slice_head(n = 3) |>
  pull(suburb)

message(glue("Top 3 suburbs: {paste(top3_suburbs, collapse=', ')}"))

# ---- 2. Compute Pearson correlation per suburb × type -------
property_types <- c("house", "unit", "townhouse", "apartment")

corr_results <- crossing(
  suburb        = top3_suburbs,
  property_type = property_types
) |>
  pmap_dfr(function(suburb, property_type) {
    sub_data <- prop_priced |>
      filter(
        suburb        == !!suburb,
        property_type == !!property_type,
        has_area, has_price,
        !is.na(sold_price), !is.na(area),
        area > 0, sold_price > 0
      )

    if (nrow(sub_data) < 10) return(NULL)  # Skip if too few records

    cor_val  <- cor(sub_data$sold_price, sub_data$area,
                    method = "pearson", use = "complete.obs")
    cor_test <- cor.test(sub_data$sold_price, sub_data$area,
                         method = "pearson")

    tibble(
      suburb        = suburb,
      property_type = property_type,
      n             = nrow(sub_data),
      correlation   = round(cor_val, 4),
      p_value       = round(cor_test$p.value, 4),
      significant   = cor_test$p.value < 0.05
    )
  })

message("\n📊 Correlation results (price vs land area):")
print(corr_results)

# ---- 3. Scatter plots for significant correlations ----------
plots <- corr_results |>
  filter(significant) |>
  pmap(function(suburb, property_type, n, correlation, ...) {
    plot_data <- prop_priced |>
      filter(
        suburb        == !!suburb,
        property_type == !!property_type,
        has_area, has_price,
        area > 0, sold_price > 0
      )

    ggplot(plot_data, aes(x = area, y = sold_price)) +
      geom_point(alpha = 0.3, color = PALETTE["blue"], size = 1.5) +
      geom_smooth(method = "lm", se = TRUE, color = PALETTE["coral"],
                  fill = "grey90", linewidth = 1) +
      scale_y_continuous(labels = dollar_format(prefix = "$",
                                                 suffix = "",
                                                 big.mark = ",")) +
      scale_x_continuous(labels = comma) +
      labs(
        title    = glue("{suburb} — {str_to_title(property_type)}"),
        subtitle = glue("r = {correlation} | n = {n:,}"),
        x        = "Land area (m²)",
        y        = "Sale price (AUD)"
      )
  })

# Combine into one patchwork figure
if (length(plots) > 0) {
  library(patchwork)
  p4_combined <- wrap_plots(plots, ncol = 2) +
    plot_annotation(
      title    = "Price vs Land Area by Suburb & Property Type",
      subtitle = "Pearson correlation (significant pairs only, p < 0.05)",
      caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
    )
  save_plot(p4_combined, "03_price_area_correlations.png",
            width = 12, height = max(6, length(plots) * 3))
}

# ---- 4. Heatmap of correlations ----------------------------
corr_wide <- corr_results |>
  select(suburb, property_type, correlation) |>
  pivot_wider(names_from = property_type, values_from = correlation)

p4_heat <- corr_results |>
  ggplot(aes(x = property_type, y = suburb, fill = correlation)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(
    label = if_else(!is.na(correlation),
                    as.character(round(correlation, 2)), "–")),
    size = 4, fontface = "bold") +
  scale_fill_gradient2(
    low = PALETTE["coral"], mid = "white", high = PALETTE["teal"],
    midpoint = 0, na.value = "grey90",
    name = "Pearson r"
  ) +
  labs(
    title    = "Price–Area Correlation by Suburb & Property Type",
    subtitle = "Grey = insufficient data (<10 records)",
    x        = "Property type",
    y        = NULL,
    caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
  ) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

save_plot(p4_heat, "03b_correlation_heatmap.png", width = 9, height = 5)

# ---- 5. Save results ----------------------------------------
write_csv(corr_results, file.path(DIR_TABLES, "03_correlations.csv"))

message("\n✅ Q3 complete.")
