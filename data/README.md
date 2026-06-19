# Data Directory

Place the dataset file here before running the analysis pipeline.

## Required file

```
data/
└── TaskC_property_victoria.csv   ← Download from Moodle
```

## Column descriptions

| Column | Type | Description |
|--------|------|-------------|
| `ID` | character | Unique property listing identifier |
| `postcode` | character | Victorian postcode |
| `suburb` | character | Suburb name |
| `sold_time` | character | Date of sale (M/D/YYYY format) |
| `sold_price` | numeric | Sale price in AUD (NA if not disclosed) |
| `address` | character | Full street address |
| `beds` | numeric | Number of bedrooms (NA if not listed) |
| `baths` | numeric | Number of bathrooms (NA if not listed) |
| `parking` | numeric | Number of parking spaces (NA if not listed) |
| `area` | numeric | Land area in m² (negative values treated as NA) |
| `property_type` | character | house / unit / townhouse / apartment / residential-land / villa |
| `description` | character | Full HTML listing description |

## Generated files (after running pipeline)

```
data/
├── prop_clean.rds       ← Cleaned full dataset
├── prop_priced.rds      ← Records with valid price
└── final_model_xgb.rds  ← Trained XGBoost model
```

> CSV data files are excluded from git tracking (see `.gitignore`).
> RDS files are also excluded as they can be regenerated from the CSV.
