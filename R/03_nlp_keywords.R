# ============================================================
# 03_nlp_keywords.R — Q2: NLP Keyword Analysis
# Melbourne Property Market Analysis (2010–2023)
# ============================================================
# Question: What are the 3 most important keywords in the
#   description column that impact property prices?
#   Use a 10% sample from the original dataset.
# ============================================================

source(here::here("R", "00_setup.R"))
library(tidytext)
library(tm)
library(SnowballC)

prop_priced <- readRDS(file.path(DIR_DATA, "prop_priced.rds"))

# ---- 1. 10% stratified sample (by property_type) -----------
set.seed(42)
sample_10pct <- prop_priced |>
  filter(!is.na(description_clean), nchar(description_clean) > 50) |>
  slice_sample(prop = 0.10)

message(glue("📝 10% sample size: {nrow(sample_10pct):,} records"))

# ---- 2. Custom stopwords -----------------------------------
property_stopwords <- c(
  stopwords("en"),
  "property", "home", "house", "bedroom", "bathroom", "living",
  "room", "area", "space", "feature", "include", "also", "great",
  "perfect", "ideal", "offers", "located", "just", "will", "can",
  "offer", "boasts", "featuring", "including", "well", "close",
  "minutes", "street", "contact", "call", "inspect", "vic",
  "victoria", "melbourne", "don't", "won't", "one", "two", "three"
)

# ---- 3. Tokenise & clean -----------------------------------
tokens <- sample_10pct |>
  select(ID, sold_price, description_clean) |>
  unnest_tokens(word, description_clean) |>
  filter(
    !word %in% property_stopwords,
    !str_detect(word, "^\\d+$"),
    str_length(word) > 3
  ) |>
  mutate(word = wordStem(word, language = "english"))

# ---- 4. TF-IDF per document ---------------------------------
tfidf <- tokens |>
  count(ID, word) |>
  bind_tf_idf(word, ID, n)

# ---- 5. Merge with prices & regress --------------------------
word_price <- tfidf |>
  left_join(sample_10pct |> select(ID, sold_price), by = "ID") |>
  filter(!is.na(sold_price))

# For each word: mean price in listings that contain it vs those that don't
word_impact <- word_price |>
  group_by(word) |>
  summarise(
    n_listings     = n_distinct(ID),
    mean_price_with = mean(sold_price, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(n_listings >= 30) |>
  left_join(
    sample_10pct |>
      summarise(overall_mean = mean(sold_price, na.rm = TRUE)),
    by = character()
  ) |>
  mutate(
    price_lift_pct = (mean_price_with - overall_mean) / overall_mean * 100
  ) |>
  arrange(desc(price_lift_pct))

# ---- 6. Top & bottom keywords ------------------------------
top_keywords    <- word_impact |> slice_head(n = 20)
bottom_keywords <- word_impact |> slice_tail(n = 10)

message("\n🔑 Top 3 price-boosting keywords:")
top_keywords |>
  slice_head(n = 3) |>
  select(word, n_listings, mean_price_with, price_lift_pct) |>
  mutate(across(where(is.numeric), round, 0)) |>
  print()

# ---- 7. Plot: keyword price impact -------------------------
p3 <- top_keywords |>
  slice_head(n = 15) |>
  mutate(word = fct_reorder(word, price_lift_pct)) |>
  ggplot(aes(x = word, y = price_lift_pct, fill = price_lift_pct)) +
  geom_col(width = 0.7) +
  scale_fill_gradient(low = PALETTE["amber"], high = PALETTE["teal"],
                      guide = "none") +
  scale_y_continuous(labels = function(x) paste0("+", round(x, 0), "%")) +
  coord_flip() +
  labs(
    title    = "Top 15 Keywords by Property Price Impact",
    subtitle = "Percentage lift in mean sale price vs. dataset average (10% sample)",
    x        = NULL,
    y        = "Price lift (%)",
    caption  = "Source: Victorian Property Transaction Dataset. Stemmed tokens, min. 30 listings."
  )

save_plot(p3, "02_keyword_price_impact.png", width = 10, height = 7)

# ---- 8. Save results ----------------------------------------
write_csv(word_impact |> slice_head(n = 50),
          file.path(DIR_TABLES, "02_keyword_impact.csv"))

message("\n✅ Q2 complete.")
