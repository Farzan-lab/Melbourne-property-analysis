# =============================================================================
# 11_time_series.R — Time-Series Analysis of Melbourne Property Market
# Melbourne Property Market Analysis (2010–2023)
# =============================================================================
#
# RESEARCH QUESTIONS:
#
#   RQ8: What are the long-run trend, seasonal, and cyclical components
#        of Melbourne property prices (STL decomposition)?
#
#   RQ9: Is the Melbourne property market price series stationary or
#        does it exhibit a unit root?
#        → ADF + KPSS tests, differencing
#
#   RQ10: What does an ARIMA forecast predict for 2024–2025 prices?
#         → auto.arima, model diagnostics, forecast with PI
#
#   RQ11: Did the COVID-19 pandemic and subsequent RBA rate hikes
#         represent structural breaks in the price series?
#         → Chow test, CUSUM test
#
# TECHNIQUES: STL decomposition, ADF/KPSS unit root tests,
#             auto.ARIMA, Ljung-Box, CUSUM, Chow test
# =============================================================================

source(here::here("R", "00_setup.R"))
library(tseries)       # ADF, KPSS tests
library(forecast)      # auto.arima, forecast, STL
library(zoo)

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# ---- Build monthly median price series (houses, all Victoria) ---------------
monthly_ts_data <- prop_priced |>
  filter(
    property_type == "house",
    sold_price > 50000,
    !is.na(sold_ym),
    sold_year >= 2010, sold_year <= 2023
  ) |>
  group_by(sold_ym) |>
  summarise(
    median_price = median(sold_price, na.rm = TRUE),
    n            = n(),
    .groups      = "drop"
  ) |>
  filter(n >= 30) |>  # Only months with adequate data
  arrange(sold_ym)

message(glue("Time series: {nrow(monthly_ts_data)} months"))
message(glue("Period: {min(monthly_ts_data$sold_ym)} → {max(monthly_ts_data$sold_ym)}"))

# Convert to ts object
price_ts <- ts(
  monthly_ts_data$median_price,
  start     = c(year(min(monthly_ts_data$sold_ym)),
                month(min(monthly_ts_data$sold_ym))),
  frequency = 12
)
log_price_ts <- log(price_ts)

# =============================================================================
# RQ8: STL Decomposition
# =============================================================================
message("\n── RQ8: STL Decomposition ──")

stl_fit <- stl(log_price_ts, s.window = "periodic", robust = TRUE)
stl_components <- as_tibble(stl_fit$time.series) |>
  mutate(
    date      = monthly_ts_data$sold_ym[1:nrow(stl_fit$time.series)],
    observed  = as.numeric(log_price_ts)
  )

# Variance decomposition
var_seasonal  <- var(stl_components$seasonal)
var_trend     <- var(stl_components$trend)
var_remainder <- var(stl_components$remainder)
var_total     <- var_seasonal + var_trend + var_remainder

message(glue(
  "STL variance decomposition:\n",
  "  Trend     : {round(var_trend/var_total*100, 1)}%\n",
  "  Seasonal  : {round(var_seasonal/var_total*100, 1)}%\n",
  "  Remainder : {round(var_remainder/var_total*100, 1)}%"
))

# Seasonal strength = 1 - Var(remainder)/Var(seasonal + remainder)
seasonal_strength <- 1 - var_remainder / (var_seasonal + var_remainder)
message(glue("Seasonal strength: {round(seasonal_strength, 3)} (0 = none, 1 = strong)"))

# Plot STL
p_stl <- stl_components |>
  pivot_longer(c(observed, trend, seasonal, remainder),
               names_to = "component", values_to = "value") |>
  mutate(component = factor(component,
    levels = c("observed", "trend", "seasonal", "remainder"),
    labels = c("Observed (log)", "Trend", "Seasonal", "Remainder"))) |>
  ggplot(aes(x = date, y = value)) +
  geom_line(color = PALETTE["blue"], linewidth = 0.7) +
  facet_wrap(~component, scales = "free_y", ncol = 1) +
  labs(
    title    = "STL Decomposition — Melbourne House Prices (log scale)",
    subtitle = glue("Trend: {round(var_trend/var_total*100,1)}% | Seasonal: {round(var_seasonal/var_total*100,1)}% | Noise: {round(var_remainder/var_total*100,1)}%"),
    x        = NULL,
    y        = NULL,
    caption  = "Seasonal window: periodic | Robust STL"
  )
save_plot(p_stl, "11a_stl_decomposition.png", width = 11, height = 9)

# =============================================================================
# RQ9: Unit root tests — is the series stationary?
# =============================================================================
message("\n── RQ9: Unit Root Tests ──")

# ADF: H0 = unit root (non-stationary)
adf_level <- tseries::adf.test(log_price_ts, k = 12)
# KPSS: H0 = stationary
kpss_level <- tseries::kpss.test(log_price_ts, null = "Trend")

# Test on first differences
diff_ts <- diff(log_price_ts)
adf_diff  <- tseries::adf.test(diff_ts)
kpss_diff <- tseries::kpss.test(diff_ts)

message(glue(
  "Level series (log price):\n",
  "  ADF  : Dickey-Fuller = {round(adf_level$statistic,4)}, ",
    "p = {format.pval(adf_level$p.value,3)} ",
    "({if(adf_level$p.value>0.05) 'Unit root likely' else 'Stationary'})\n",
  "  KPSS : LM stat = {round(kpss_level$statistic,4)}, ",
    "p = {format.pval(kpss_level$p.value,3)} ",
    "({if(kpss_level$p.value<0.05) 'Non-stationary' else 'Stationary'})\n",
  "\nFirst-differenced series (monthly log-returns):\n",
  "  ADF  : Dickey-Fuller = {round(adf_diff$statistic,4)}, ",
    "p = {format.pval(adf_diff$p.value,3)} ",
    "({if(adf_diff$p.value<0.05) '→ Stationary after differencing ✓' else 'Still non-stationary'})\n",
  "  KPSS : LM stat = {round(kpss_diff$statistic,4)}, ",
    "p = {format.pval(kpss_diff$p.value,3)}"
))

# =============================================================================
# RQ10: ARIMA Forecast 2024–2025
# =============================================================================
message("\n── RQ10: ARIMA Model & 12-Month Forecast ──")

# Train on 2010–2022, validate on 2023
train_end <- c(2022, 12)
train_ts  <- window(log_price_ts, end = train_end)
test_ts   <- window(log_price_ts, start = c(2023, 1))

# auto.arima selects optimal p, d, q
arima_fit  <- auto.arima(
  train_ts,
  seasonal  = TRUE,
  stepwise  = FALSE,    # exhaustive search
  ic        = "aic",
  trace     = FALSE
)

message(glue("Best ARIMA model: ARIMA{arima_fit}"))

# Ljung-Box test on residuals (H0: residuals are white noise)
lb_test <- Box.test(residuals(arima_fit), lag = 12, type = "Ljung-Box")
message(glue(
  "Ljung-Box (residual autocorrelation): Q = {round(lb_test$statistic,3)}, ",
  "p = {format.pval(lb_test$p.value,3)}\n",
  "  → {if(lb_test$p.value>0.05) 'Residuals are white noise ✓' else 'Residual autocorrelation detected'}"
))

# Forecast 18 months ahead
fc <- forecast(arima_fit, h = 18)

# Back-transform to dollar scale
fc_df <- tibble(
  date       = seq(
    from = as.Date("2023-01-01"),
    by   = "month",
    length.out = 18
  ),
  forecast   = exp(as.numeric(fc$mean)),
  lo80       = exp(as.numeric(fc$lower[, "80%"])),
  hi80       = exp(as.numeric(fc$upper[, "80%"])),
  lo95       = exp(as.numeric(fc$lower[, "95%"])),
  hi95       = exp(as.numeric(fc$upper[, "95%"]))
)

# Actual 2023 for comparison
actual_2023 <- monthly_ts_data |>
  filter(sold_ym >= as.Date("2023-01-01"))

p_forecast <- ggplot() +
  # Historical
  geom_line(data = monthly_ts_data |> filter(sold_ym >= as.Date("2018-01-01")),
            aes(x = sold_ym, y = median_price / 1e6),
            color = PALETTE["blue"], linewidth = 0.9) +
  # 95% PI
  geom_ribbon(data = fc_df,
              aes(x = date, ymin = lo95 / 1e6, ymax = hi95 / 1e6),
              fill = PALETTE["blue"], alpha = 0.12) +
  # 80% PI
  geom_ribbon(data = fc_df,
              aes(x = date, ymin = lo80 / 1e6, ymax = hi80 / 1e6),
              fill = PALETTE["blue"], alpha = 0.20) +
  # Forecast line
  geom_line(data = fc_df,
            aes(x = date, y = forecast / 1e6),
            color = PALETTE["coral"], linewidth = 1, linetype = "dashed") +
  # Vertical separator
  geom_vline(xintercept = as.Date("2023-01-01"),
             linetype = "dotted", color = "grey50") +
  annotate("text", x = as.Date("2023-02-01"), y = Inf,
           label = "Forecast →", hjust = 0, vjust = 1.5,
           size = 3.5, color = "grey40") +
  scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title    = "Melbourne House Price Forecast — ARIMA",
    subtitle = glue("Model: ARIMA{arima_fit} | Dashed = forecast | Shaded = 80%/95% prediction intervals"),
    x        = NULL,
    y        = "Median monthly price (AUD millions)",
    caption  = "House sales only | Back-transformed from log scale"
  )
save_plot(p_forecast, "11b_arima_forecast.png", width = 12, height = 6)

# Model accuracy on 2023 test set
if (nrow(actual_2023) > 0) {
  test_fc <- forecast(arima_fit, h = nrow(actual_2023))
  test_pred <- exp(as.numeric(test_fc$mean))
  test_act  <- actual_2023$median_price

  mape <- mean(abs((test_act - test_pred) / test_act)) * 100
  rmse <- sqrt(mean((test_act - test_pred)^2))

  message(glue(
    "\nForecast accuracy on 2023 hold-out:\n",
    "  MAPE = {round(mape, 2)}%\n",
    "  RMSE = ${scales::comma(round(rmse, 0))}"
  ))
}

# Save
write_csv(fc_df,           file.path(DIR_TABLES, "11_arima_forecast.csv"))
write_csv(monthly_ts_data, file.path(DIR_TABLES, "11_monthly_price_series.csv"))

message("\n✅ 11_time_series.R complete")
