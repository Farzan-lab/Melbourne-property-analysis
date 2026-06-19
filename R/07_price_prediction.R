# ============================================================
# 07_price_prediction.R — Q6: Price Prediction for July 2026
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: Predicted price for July 2026 of a renovated house,
#   4 beds, 2 baths, close to shopping centre + primary school,
#   in each of: Mulgrave, Vermont South, Doncaster East,
#   Rowville, Glen Waverley, Wheelers Hill.
#   Model trained ONLY on provided dataset (2010–2023).
# ============================================================

source(here::here("R", "00_setup.R"))
library(tidymodels)
library(xgboost)

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

TARGET_SUBURBS <- c(
  "Mulgrave", "Vermont South", "Doncaster East",
  "Rowville", "Glen Waverley", "Wheelers Hill"
)

# ============================================================
# 1. FEATURE ENGINEERING
# ============================================================
model_data <- prop_priced |>
  filter(
    property_type == "house",
    !is.na(beds), !is.na(baths),
    !is.na(sold_price), sold_price > 50000,
    !is.na(sold_date)
  ) |>
  mutate(
    # Temporal features
    sold_year_num  = as.numeric(sold_year),
    sold_month_num = as.numeric(sold_month),
    years_since_2010 = (sold_year - 2010) + (sold_month - 1) / 12,

    # NLP-based binary flags from description
    is_renovated   = str_detect(tolower(description_clean),
                                "renovat|refurb|modernised|updated|redesign"),
    near_shopping  = str_detect(tolower(description_clean),
                                "shopping centre|shopping center|supermarket|mall"),
    near_school    = str_detect(tolower(description_clean),
                                "primary school|primary college|primary"),

    # Target: log-transform to handle skewed prices
    log_price      = log(sold_price),

    # Numeric features
    beds           = pmin(beds, 10),     # Cap extreme values
    baths          = pmin(baths, 8),
    parking        = pmin(coalesce(parking, 0), 6),
    area_log       = log1p(coalesce(area, median(area, na.rm = TRUE)))
  ) |>
  # Focus on suburbs with enough data
  group_by(suburb) |>
  filter(n() >= 20) |>
  ungroup()

message(glue("🏠 Model training data: {nrow(model_data):,} house records"))

# ============================================================
# 2. TRAIN / TEST SPLIT (temporal — test on 2022–2023)
# ============================================================
train_data <- model_data |> filter(sold_year < 2022)
test_data  <- model_data |> filter(sold_year >= 2022)

message(glue("  Training: {nrow(train_data):,} | Test: {nrow(test_data):,}"))

# ============================================================
# 3. MODEL RECIPE
# ============================================================
rec <- recipe(log_price ~ suburb + beds + baths + parking +
                area_log + sold_year_num + sold_month_num +
                is_renovated + near_shopping + near_school,
              data = train_data) |>
  step_unknown(suburb) |>
  step_dummy(suburb, one_hot = TRUE) |>
  step_impute_median(all_numeric_predictors()) |>
  step_zv(all_predictors())

# ============================================================
# 4. MODEL SPECIFICATIONS
# ============================================================
spec_xgb <- boost_tree(
  trees          = 500,
  tree_depth     = 6,
  min_n          = 10,
  learn_rate     = 0.05,
  loss_reduction = 0.01,
  sample_size    = 0.8
) |>
  set_engine("xgboost") |>
  set_mode("regression")

spec_rf <- rand_forest(trees = 300) |>
  set_engine("ranger") |>
  set_mode("regression")

# ============================================================
# 5. CROSS-VALIDATION
# ============================================================
set.seed(2024)
folds <- vfold_cv(train_data, v = 5)

wf_xgb <- workflow() |> add_recipe(rec) |> add_model(spec_xgb)
wf_rf  <- workflow() |> add_recipe(rec) |> add_model(spec_rf)

message("\n⏳ Running 5-fold cross-validation (XGBoost)...")
cv_xgb <- fit_resamples(wf_xgb, folds,
                         metrics = metric_set(rmse, rsq, mae))

message("⏳ Running 5-fold cross-validation (Random Forest)...")
cv_rf  <- fit_resamples(wf_rf,  folds,
                         metrics = metric_set(rmse, rsq, mae))

cv_results <- bind_rows(
  collect_metrics(cv_xgb) |> mutate(model = "XGBoost"),
  collect_metrics(cv_rf)  |> mutate(model = "Random Forest")
)

message("\n📊 Cross-validation results:")
cv_results |>
  select(model, .metric, mean, std_err) |>
  filter(.metric %in% c("rmse", "rsq")) |>
  arrange(.metric, model) |>
  print()

# ============================================================
# 6. FIT FINAL MODEL ON ALL TRAINING DATA
# ============================================================
final_fit <- fit(wf_xgb, data = train_data)

# Evaluate on test set
test_preds <- augment(final_fit, test_data) |>
  mutate(
    pred_price   = exp(.pred),
    actual_price = exp(log_price)
  )

rmse_test <- rmse_vec(test_preds$actual_price, test_preds$pred_price)
mae_test  <- mae_vec(test_preds$actual_price, test_preds$pred_price)
r2_test   <- rsq_vec(test_preds$actual_price, test_preds$pred_price)

message(glue("\n📈 Test set performance (XGBoost):"))
message(glue("  RMSE = ${scales::comma(round(rmse_test))}"))
message(glue("  MAE  = ${scales::comma(round(mae_test))}"))
message(glue("  R²   = {round(r2_test, 3)}"))

# ============================================================
# 7. PREDICT JULY 2026 FOR 6 SUBURBS
# ============================================================
# Chris's criteria: renovated house, 4 bed, 2 bath,
# near shopping centre, near primary school

prediction_input <- tibble(
  suburb         = TARGET_SUBURBS,
  beds           = 4,
  baths          = 2,
  parking        = 2,
  area_log       = log1p(500),     # Assume ~500m² typical land size
  sold_year_num  = 2026,
  sold_month_num = 7,              # July 2026
  is_renovated   = TRUE,
  near_shopping  = TRUE,
  near_school    = TRUE
)

predictions_2026 <- augment(final_fit, new_data = prediction_input) |>
  mutate(
    predicted_price = exp(.pred),
    suburb          = factor(suburb, levels = TARGET_SUBURBS[order(exp(.pred))])
  ) |>
  select(suburb, predicted_price)

message("\n🏡 Predicted July 2026 prices (Chris's criteria):")
predictions_2026 |>
  mutate(price_fmt = scales::dollar(predicted_price, prefix = "$",
                                     big.mark = ",", accuracy = 1000)) |>
  arrange(desc(predicted_price)) |>
  print()

# ============================================================
# 8. VISUALISE PREDICTIONS
# ============================================================
p7 <- predictions_2026 |>
  mutate(suburb = fct_reorder(suburb, predicted_price)) |>
  ggplot(aes(x = suburb, y = predicted_price / 1e6)) +
  geom_col(fill = PALETTE["blue"], width = 0.65) +
  geom_text(
    aes(label = scales::dollar(predicted_price / 1e6,
                               prefix = "$", suffix = "M",
                               accuracy = 0.01)),
    hjust = -0.1, size = 4, fontface = "bold",
    color = PALETTE["blue"]
  ) +
  scale_y_continuous(
    labels  = dollar_format(prefix = "$", suffix = "M"),
    expand  = expansion(mult = c(0, 0.2))
  ) +
  coord_flip() +
  labs(
    title    = "Predicted Property Price — July 2026",
    subtitle = "4-bed / 2-bath renovated house near shopping centre & primary school\nModel: XGBoost trained on 2010–2023 Victorian transactions",
    x        = NULL,
    y        = "Predicted price (AUD millions)",
    caption  = "Source: Victorian Property Transaction Dataset. Forecast extrapolated from 2023 data."
  )

save_plot(p7, "06_predicted_prices_2026.png", width = 10, height = 6)

# ============================================================
# 9. SAVE RESULTS
# ============================================================
write_csv(predictions_2026,
          file.path(DIR_TABLES, "06_predictions_july2026.csv"))
write_csv(cv_results,
          file.path(DIR_TABLES, "06_cv_model_comparison.csv"))

saveRDS(final_fit, file.path(DIR_DATA, "final_model_xgb.rds"))

message("\n✅ Q6 complete. Model saved to data/final_model_xgb.rds")
