# ============================================================
# shiny_app/modules/mod_map.R — Leaflet Map Module
# ============================================================

mod_map_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(3, 9),
      card(
        card_header("🗺️ Map Controls"),
        selectInput(ns("map_year"), "Year",
                    choices = 2010:2023, selected = 2022),
        selectInput(ns("map_type"), "Property type",
                    choices = c("All", "house", "unit", "townhouse", "apartment"),
                    selected = "house"),
        selectInput(ns("map_metric"), "Colour by",
                    choices = c("Median price" = "median_price",
                                "Transaction count" = "n"),
                    selected = "median_price"),
        p(class = "text-muted small",
          "Bubble size = number of transactions. Hover for details.")
      ),
      card(
        card_header("Property activity by suburb"),
        leafletOutput(ns("map"), height = "550px")
      )
    )
  )
}

mod_map_server <- function(id, prop_priced) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Approximate suburb centroids (Victoria)
    # In production, join with a proper postcode/suburb geocoding table
    suburb_coords <- tibble(
      suburb = c("Melbourne", "Richmond", "Fitzroy", "Carlton",
                 "St Kilda", "South Yarra", "Toorak", "Hawthorn",
                 "Glen Waverley", "Doncaster East", "Rowville",
                 "Mulgrave", "Vermont South", "Wheelers Hill",
                 "Frankston", "Dandenong", "Ringwood", "Berwick",
                 "Sunshine", "Werribee"),
      lat  = c(-37.814, -37.826, -37.800, -37.801,
               -37.867, -37.839, -37.842, -37.820,
               -37.882, -37.779, -37.925,
               -37.915, -37.862, -37.903,
               -38.145, -37.987, -37.816, -38.032,
               -37.786, -37.900),
      lng  = c(144.963, 145.000, 144.977, 144.966,
               144.975, 145.000, 145.012, 145.038,
               145.166, 145.128, 145.234,
               145.173, 145.200, 145.167,
               145.120, 145.215, 145.234, 145.352,
               144.832, 144.660)
    )

    # Aggregate by suburb
    map_data <- reactive({
      d <- prop_priced |>
        filter(sold_year == input$map_year)

      if (input$map_type != "All") {
        d <- filter(d, property_type == input$map_type)
      }

      d |>
        filter(!is.na(sold_price)) |>
        group_by(suburb) |>
        summarise(
          n            = n(),
          median_price = median(sold_price, na.rm = TRUE),
          mean_price   = mean(sold_price, na.rm = TRUE),
          .groups = "drop"
        ) |>
        inner_join(suburb_coords, by = "suburb")
    })

    output$map <- renderLeaflet({
      d <- map_data()

      metric_col <- input$map_metric
      pal_domain <- d[[metric_col]]

      pal <- colorNumeric(
        palette = c("#B5D4F4", "#185FA5"),
        domain  = pal_domain
      )

      leaflet(d) |>
        addProviderTiles(providers$CartoDB.Positron) |>
        setView(lng = 145.0, lat = -37.9, zoom = 10) |>
        addCircleMarkers(
          lng         = ~lng,
          lat         = ~lat,
          radius      = ~scales::rescale(sqrt(n), to = c(4, 20)),
          fillColor   = ~pal(get(metric_col)),
          fillOpacity = 0.8,
          color       = "white",
          weight      = 1,
          popup = ~paste0(
            "<b>", suburb, "</b><br>",
            "Transactions: ", comma(n), "<br>",
            "Median price: $", comma(round(median_price, -3))
          )
        ) |>
        addLegend(
          pal      = pal,
          values   = pal_domain,
          position = "bottomright",
          title    = if (metric_col == "median_price") "Median price" else "Count",
          labFormat = labelFormat(
            prefix = if (metric_col == "median_price") "$" else "",
            big.mark = ","
          )
        )
    })
  })
}
