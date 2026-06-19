# ============================================================
# 06_anomaly_detection.R — Q5: Unrealistic Property Detection
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: Investigate properties that could not realistically
#   exist based on their features. One example per feature
#   category. Remove negative area values first.
# ============================================================

source(here::here("R", "00_setup.R"))
library(gt)

prop <- readRDS(file.path(DIR_DATA, "prop_clean.rds"))

# Note: Negative area values already removed in 01_load_clean.R
# (area < 0 → set to NA). Confirming:
stopifnot(all(is.na(prop$area) | prop$area >= 0))
message("✔ Confirmed: no negative area values in dataset")

# ============================================================
# ANOMALY CATEGORIES
# ============================================================

# ---- 1. Unrealistic beds (0 beds for house/townhouse) ------
anom_beds_zero <- prop |>
  filter(
    property_type %in% c("house", "townhouse"),
    !is.na(beds), beds == 0
  ) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Zero bedrooms (house/townhouse)",
    reason           = "A house or townhouse with 0 bedrooms cannot realistically exist"
  )

# ---- 2. Unrealistic beds (extreme high: >10 beds) -----------
anom_beds_high <- prop |>
  filter(!is.na(beds), beds > 10) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Extreme bedroom count (>10)",
    reason           = glue("Residential property with {beds} bedrooms is implausible")
  )

# ---- 3. Beds > 0, baths = 0 (house with no bathroom) -------
anom_baths_zero <- prop |>
  filter(
    property_type %in% c("house", "townhouse"),
    !is.na(beds), beds >= 2,
    !is.na(baths), baths == 0
  ) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Multi-bed house with zero bathrooms",
    reason           = glue("{beds}-bed house with 0 bathrooms is unrealistic")
  )

# ---- 4. Extreme land area for apartment/unit ----------------
anom_area_apt <- prop |>
  filter(
    property_type %in% c("apartment", "unit"),
    !is.na(area), area > 5000
  ) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Implausible land area for apartment",
    reason           = glue("Apartment with {comma(area)}m² land area (> 5,000m²) is implausible")
  )

# ---- 5. Beds + Baths combination: more baths than beds -----
anom_bath_bed_ratio <- prop |>
  filter(
    !is.na(beds), !is.na(baths),
    beds >= 1, baths > beds * 2,   # More than 2× bathrooms per bedroom
    baths >= 5
  ) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Bathrooms far exceed bedrooms",
    reason           = glue("{baths} bathrooms for only {beds} bedrooms (ratio > 2:1) is unrealistic")
  )

# ---- 6. Sold price of $1 (likely placeholder) ---------------
anom_price_dollar <- prop |>
  filter(!is.na(sold_price), sold_price <= 100) |>
  slice_head(n = 1) |>
  mutate(
    anomaly_category = "Implausible sale price ($1–$100)",
    reason           = glue("Sold price of ${sold_price} for a residential property is clearly erroneous")
  )

# ============================================================
# COMBINE ALL ANOMALIES INTO SUMMARY TABLE
# ============================================================
anomaly_cols <- c("anomaly_category", "reason", "ID", "address",
                  "suburb", "property_type", "beds", "baths",
                  "parking", "area", "sold_price")

anomaly_summary <- bind_rows(
  anom_beds_zero,
  anom_beds_high,
  anom_baths_zero,
  anom_area_apt,
  anom_bath_bed_ratio,
  anom_price_dollar
) |>
  select(any_of(anomaly_cols))

message("\n🚨 Anomaly Summary Table:")
anomaly_summary |>
  select(anomaly_category, address, beds, baths, area, sold_price, reason) |>
  print(width = Inf)

# ---- Supporting counts for each category -------------------
message("\n📊 Supporting counts:")

message(glue(
  "  Zero-bed houses/townhouses : ",
  "{nrow(filter(prop, property_type %in% c('house','townhouse'), !is.na(beds), beds==0))}"
))
message(glue(
  "  Properties with beds > 10  : ",
  "{nrow(filter(prop, !is.na(beds), beds > 10))}"
))
message(glue(
  "  Multi-bed / zero bath houses: ",
  "{nrow(filter(prop, property_type %in% c('house','townhouse'), !is.na(beds), beds>=2, !is.na(baths), baths==0))}"
))
message(glue(
  "  Apartments with area > 5000m²: ",
  "{nrow(filter(prop, property_type %in% c('apartment','unit'), !is.na(area), area > 5000))}"
))
message(glue(
  "  Bath >> beds anomalies     : ",
  "{nrow(filter(prop, !is.na(beds), !is.na(baths), beds>=1, baths > beds*2, baths>=5))}"
))
message(glue(
  "  Price <= $100              : ",
  "{nrow(filter(prop, !is.na(sold_price), sold_price <= 100))}"
))

# ---- Save results -------------------------------------------
write_csv(anomaly_summary,
          file.path(DIR_TABLES, "05_anomaly_summary.csv"))
write_csv(prop |> filter(property_type %in% c("house","townhouse"),
                          !is.na(beds), beds == 0),
          file.path(DIR_TABLES, "05_zero_bed_houses.csv"))

message("\n✅ Q5 complete.")
