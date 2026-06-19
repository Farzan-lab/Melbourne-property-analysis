# ============================================================
# 05_capital_gains.R — Q4: Highest Capital Gains
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: Which properties have experienced the highest price
#   increases since their first sale?
#   Exclude properties where time between first and last sale
#   exceeds 5 years. List top 5 with address, capital gain,
#   and duration.
# ============================================================

source(here::here("R", "00_setup.R"))

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# ---- 1. Find properties sold multiple times -----------------
# Group by address to track same property over time
multi_sold <- prop_priced |>
  filter(!is.na(address), !is.na(sold_date), !is.na(sold_price)) |>
  group_by(address) |>
  filter(n() >= 2) |>            # Must have at least 2 sales
  arrange(sold_date) |>
  summarise(
    first_sale_date  = first(sold_date),
    last_sale_date   = last(sold_date),
    first_sale_price = first(sold_price),
    last_sale_price  = last(sold_price),
    suburb           = first(suburb),
    property_type    = first(property_type),
    n_sales          = n(),
    .groups = "drop"
  )

message(glue("🔁 Properties with multiple sales: {nrow(multi_sold):,}"))

# ---- 2. Calculate duration and apply 5-year filter ----------
capital_gains <- multi_sold |>
  mutate(
    duration_days  = as.numeric(last_sale_date - first_sale_date),
    duration_years = duration_days / 365.25
  ) |>
  filter(
    duration_years <= 5,           # Exclude >5 years
    duration_years > 0,            # Must have some time gap
    first_sale_price > 0,
    last_sale_price  > 0
  ) |>
  mutate(
    capital_gain     = last_sale_price - first_sale_price,
    capital_gain_pct = capital_gain / first_sale_price * 100
  ) |>
  filter(capital_gain > 0) |>      # Only positive gains
  arrange(desc(capital_gain))

message(glue("📈 Properties after 5-year filter: {nrow(capital_gains):,}"))

# ---- 3. Top 5 properties ------------------------------------
top5 <- capital_gains |>
  slice_head(n = 5) |>
  select(
    address, suburb, property_type,
    first_sale_date, first_sale_price,
    last_sale_date,  last_sale_price,
    capital_gain, capital_gain_pct,
    duration_years, n_sales
  ) |>
  mutate(
    duration_label   = glue("{round(duration_years, 1)} years"),
    capital_gain_fmt = scales::dollar(capital_gain, prefix = "$", big.mark = ","),
    gain_pct_fmt     = paste0("+", round(capital_gain_pct, 1), "%")
  )

message("\n🏆 Top 5 properties by capital gain:")
top5 |>
  select(address, capital_gain_fmt, gain_pct_fmt, duration_label) |>
  print(width = Inf)

# ---- 4. Plot: top 5 properties ------------------------------
p5 <- top5 |>
  mutate(
    short_address = str_trunc(address, 45),
    short_address = fct_reorder(short_address, capital_gain)
  ) |>
  ggplot(aes(x = short_address, y = capital_gain / 1e6)) +
  geom_col(fill = PALETTE["teal"], width = 0.65) +
  geom_text(aes(label = glue("${round(capital_gain/1e6,2)}M\n({gain_pct_fmt})")),
            hjust = -0.1, size = 3.5, lineheight = 1.2) +
  scale_y_continuous(
    labels = dollar_format(prefix = "$", suffix = "M"),
    expand = expansion(mult = c(0, 0.3))
  ) +
  coord_flip() +
  labs(
    title    = "Top 5 Properties by Capital Gain",
    subtitle = "Sales within 5 years of first purchase — highest absolute price increase",
    x        = NULL,
    y        = "Capital gain (AUD millions)",
    caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
  )

save_plot(p5, "04_top5_capital_gains.png", width = 11, height = 6)

# ---- 5. Timeline plot: price journey -----------------------
timeline_data <- prop_priced |>
  filter(address %in% top5$address) |>
  mutate(
    short_address = str_trunc(address, 45)
  ) |>
  arrange(address, sold_date)

p5b <- ggplot(timeline_data, aes(x = sold_date, y = sold_price / 1e6,
                                  color = str_trunc(address, 35),
                                  group = address)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
  scale_color_manual(values = unname(PALETTE)) +
  labs(
    title    = "Price Journey — Top 5 Capital Gain Properties",
    subtitle = "Each line tracks one property from first to last sale",
    x        = NULL,
    y        = "Sale price (AUD millions)",
    color    = "Property",
    caption  = "Source: Victorian Property Transaction Dataset 2010–2023"
  ) +
  theme(legend.text = element_text(size = 8))

save_plot(p5b, "04b_capital_gains_timeline.png", width = 11, height = 6)

# ---- 6. Save results ----------------------------------------
write_csv(top5, file.path(DIR_TABLES, "04_top5_capital_gains.csv"))
write_csv(capital_gains |> slice_head(n = 50),
          file.path(DIR_TABLES, "04_all_capital_gains.csv"))

message("\n✅ Q4 complete.")
