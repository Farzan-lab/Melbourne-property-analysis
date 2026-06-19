# ============================================================
# 01_load_clean.R — Data Loading & Cleaning
# Melbourne Property Market Analysis (2010–2023)
# ============================================================

source(here::here("R", "00_setup.R"))

# ---- 1. Load raw data ---------------------------------------
message("Loading dataset...")

raw <- read_csv(
  file.path(DIR_DATA, "TaskC_property_victoria.csv"),
  col_types = cols(
    ID            = col_character(),
    postcode      = col_character(),
    suburb        = col_character(),
    sold_time     = col_character(),
    sold_price    = col_double(),
    address       = col_character(),
    beds          = col_double(),
    baths         = col_double(),
    parking       = col_double(),
    area          = col_double(),
    property_type = col_character(),
    description   = col_character()
  ),
  show_col_types = FALSE
)

message(glue("✔ Loaded {nrow(raw):,} rows × {ncol(raw)} columns"))

# ---- 2. Parse dates -----------------------------------------
prop <- raw |>
  mutate(
    sold_date  = mdy(sold_time),
    sold_year  = year(sold_date),
    sold_month = month(sold_date),
    sold_ym    = floor_date(sold_date, "month")
  )

# ---- 3. Clean text fields -----------------------------------
prop <- prop |>
  mutate(
    suburb        = str_to_title(str_trim(suburb)),
    property_type = str_to_lower(str_trim(property_type)),
    # Strip HTML tags from description
    description_clean = description |>
      str_remove_all("<[^>]+>") |>
      str_remove_all("&[a-zA-Z]+;") |>
      str_squish()
  )

# ---- 4. Remove negative area values (per Q5 instructions) --
prop <- prop |>
  mutate(area = if_else(area < 0, NA_real_, area))

# ---- 5. Flag missing values ---------------------------------
prop <- prop |>
  mutate(
    has_price     = !is.na(sold_price),
    has_area      = !is.na(area),
    has_beds      = !is.na(beds),
    has_sold_date = !is.na(sold_date)
  )

# ---- 6. Filter to valid price records for modelling ---------
prop_priced <- prop |>
  filter(has_price, sold_price > 0)

# ---- 7. Summary ---------------------------------------------
message("\n📊 Dataset summary:")
message(glue("  Total records     : {nrow(prop):,}"))
message(glue("  With price        : {nrow(prop_priced):,}"))
message(glue("  Date range        : {min(prop$sold_date, na.rm=TRUE)} → {max(prop$sold_date, na.rm=TRUE)}"))
message(glue("  Unique suburbs    : {n_distinct(prop$suburb, na.rm=TRUE):,}"))
message(glue("  Property types    : {paste(sort(unique(prop$property_type)), collapse=', ')}"))

# ---- 8. Save cleaned data -----------------------------------
saveRDS(prop,        file.path(DIR_DATA, "prop_clean.rds"))
saveRDS(prop_priced, file.path(DIR_DATA, "prop_priced.rds"))
message("\n✅ Cleaned data saved to data/")
