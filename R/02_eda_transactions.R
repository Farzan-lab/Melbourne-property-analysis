# ============================================================
# 02_eda_transactions.R — Q1: Top Suburbs & Monthly Trends
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: Identify top 3 suburbs by transaction volume.
#   Plot monthly counts for 2022. Include Toorak if not in top 3.
# ============================================================

source(here::here("R", "00_setup.R"))
prop <- readRDS(file.path(DIR_DATA, "prop_clean.rds"))

# ---- 1. Transaction count per suburb (all years) ------------
suburb_counts <- prop |>
  filter(!is.na(suburb), !is.na(sold_date)) |>
  count(suburb, name = "total_transactions") |>
  arrange(desc(total_transactions))

top3_suburbs <- suburb_counts |>
  slice_head(n = 3) |>
  pull(suburb)

message("🏆 Top 3 suburbs by transaction volume:")
suburb_counts |> slice_head(n = 5) |> print()

# ---- 2. Add Toorak if not already in top 3 ------------------
focus_suburbs <- if ("Toorak" %in% top3_suburbs) {
  top3_suburbs
} else {
  c(top3_suburbs, "Toorak")
}

message(glue("\n📍 Focus suburbs: {paste(focus_suburbs, collapse=', ')}"))

# ---- 3. Monthly transactions in 2022 for focus suburbs ------
monthly_2022 <- prop |>
  filter(
    suburb %in% focus_suburbs,
    sold_year == 2022,
    !is.na(sold_ym)
  ) |>
  count(suburb, sold_ym, name = "transactions")

# ---- 4. Plot ------------------------------------------------
suburb_colors <- setNames(
  unname(PALETTE[c("blue", "teal", "amber", "coral")]),
  focus_suburbs
)

p1 <- ggplot(monthly_2022, aes(x = sold_ym, y = transactions, color = suburb)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_color_manual(values = suburb_colors) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b") +
  scale_y_continuous(labels = comma) +
  labs(
    title    = "Monthly Property Transactions in 2022",
    subtitle = glue("Top 3 suburbs by total volume (2010–2023){if('Toorak' %in% top3_suburbs) '' else ' + Toorak'}"),
    x        = NULL,
    y        = "Number of transactions",
    color    = NULL,
    caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
  )

save_plot(p1, "01_monthly_transactions_top3_2022.png", width = 11, height = 6)

# ---- 5. Bar chart: all-time totals --------------------------
p1b <- suburb_counts |>
  slice_head(n = 15) |>
  mutate(suburb = fct_reorder(suburb, total_transactions)) |>
  ggplot(aes(x = suburb, y = total_transactions, fill = suburb %in% focus_suburbs)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = c("FALSE" = "grey80", "TRUE" = PALETTE["blue"]),
                    guide = "none") +
  scale_y_continuous(labels = comma) +
  coord_flip() +
  labs(
    title    = "Top 15 Suburbs by Total Transactions (2010–2023)",
    subtitle = "Highlighted: focus suburbs for 2022 monthly analysis",
    x        = NULL,
    y        = "Total transactions",
    caption  = "Source: Victorian Property Transaction Dataset"
  )

save_plot(p1b, "01b_top15_suburbs_alltime.png", width = 10, height = 7)

# ---- 6. Save results table ----------------------------------
write_csv(suburb_counts |> slice_head(n = 20),
          file.path(DIR_TABLES, "01_top_suburbs.csv"))
write_csv(monthly_2022,
          file.path(DIR_TABLES, "01_monthly_2022.csv"))

message("\n✅ Q1 complete.")
