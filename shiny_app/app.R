# ============================================================
# shiny_app/app.R — Melbourne Property Dashboard
# ============================================================

library(shiny)
library(bslib)
library(tidyverse)
library(plotly)
library(leaflet)
library(DT)
library(scales)
library(here)

# ---- Source modules ----------------------------------------
source(here("shiny_app", "modules", "mod_trends.R"))
source(here("shiny_app", "modules", "mod_predict.R"))
source(here("shiny_app", "modules", "mod_map.R"))

# ---- Load pre-processed data -------------------------------
# (Run analysis scripts 01–07 first to generate these files)
tryCatch({
  prop        <<- readRDS(here("data", "prop_clean.rds"))
  prop_priced <<- readRDS(here("data", "prop_priced.rds"))
  final_model <<- readRDS(here("data", "final_model_xgb.rds"))
  message("✅ Data loaded successfully")
}, error = function(e) {
  message("⚠ Could not load data files. Run analysis scripts first.")
  prop        <<- tibble()
  prop_priced <<- tibble()
  final_model <<- NULL
})

# ============================================================
# UI
# ============================================================
ui <- page_navbar(
  title = "🏠 Melbourne Property Analytics",
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#185FA5",
    font_scale = 0.95
  ),

  # ---- Tab 1: Market Trends --------------------------------
  nav_panel(
    title = "Market Trends",
    icon  = icon("chart-line"),
    mod_trends_ui("trends")
  ),

  # ---- Tab 2: Price Predictor ------------------------------
  nav_panel(
    title = "Price Predictor",
    icon  = icon("calculator"),
    mod_predict_ui("predict")
  ),

  # ---- Tab 3: Property Map ---------------------------------
  nav_panel(
    title = "Suburb Map",
    icon  = icon("map"),
    mod_map_ui("map")
  ),

  # ---- Tab 4: Data Explorer --------------------------------
  nav_panel(
    title = "Data Explorer",
    icon  = icon("table"),
    card(
      card_header("🔍 Explore the Dataset"),
      layout_sidebar(
        sidebar = sidebar(
          selectInput("dt_suburb", "Suburb",
                      choices  = c("All", sort(unique(prop_priced$suburb))),
                      selected = "All"),
          selectInput("dt_type", "Property type",
                      choices  = c("All", sort(unique(prop_priced$property_type))),
                      selected = "All"),
          sliderInput("dt_year", "Year range",
                      min = 2010, max = 2023, value = c(2018, 2023), step = 1,
                      sep = "")
        ),
        DTOutput("data_table")
      )
    )
  ),

  # ---- Footer ----------------------------------------------
  nav_spacer(),
  nav_item(
    tags$a(
      href = "https://github.com/yourusername/melbourne-property-analysis",
      icon("github"), "GitHub",
      target = "_blank"
    )
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {

  mod_trends_server("trends", prop_priced)
  mod_predict_server("predict", prop_priced, final_model)
  mod_map_server("map", prop_priced)

  # ---- Data table ------------------------------------------
  filtered_dt <- reactive({
    d <- prop_priced
    if (input$dt_suburb != "All") d <- filter(d, suburb == input$dt_suburb)
    if (input$dt_type   != "All") d <- filter(d, property_type == input$dt_type)
    d |>
      filter(sold_year >= input$dt_year[1], sold_year <= input$dt_year[2]) |>
      select(address, suburb, property_type, sold_date, sold_price,
             beds, baths, parking, area) |>
      mutate(sold_price = dollar(sold_price, prefix = "$", big.mark = ","))
  })

  output$data_table <- renderDT({
    datatable(
      filtered_dt(),
      options = list(pageLength = 15, scrollX = TRUE),
      rownames = FALSE
    )
  })
}

shinyApp(ui, server)
