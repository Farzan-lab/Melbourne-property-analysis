# ============================================================
# shiny_app/modules/mod_trends.R — Market Trends Module
# ============================================================

mod_trends_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # ---- Sidebar controls --------------------------------
      card(
        card_header("📊 Filters"),
        selectInput(ns("suburbs"), "Select suburbs",
                    choices  = NULL,
                    multiple = TRUE),
        sliderInput(ns("year_range"), "Year range",
                    min = 2010, max = 2023, value = c(2015, 2023),
                    sep = "", step = 1),
        selectInput(ns("prop_type"), "Property type",
                    choices = c("All", "house", "unit", "townhouse", "apartment"),
                    selected = "house"),
        radioButtons(ns("granularity"), "Time granularity",
                     choices = c("Monthly" = "month", "Quarterly" = "quarter",
                                 "Yearly" = "year"),
                     selected = "month")
      ),

      # ---- Main plots ------------------------------------
      layout_columns(
        col_widths = c(12, 12),
        card(
          card_header("Transaction volume over time"),
          plotlyOutput(ns("volume_plot"), height = "300px")
        ),
        card(
          card_header("Median sale price over time"),
          plotlyOutput(ns("price_plot"), height = "300px")
        )
      )
    )
  )
}

mod_trends_server <- function(id, prop_priced) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Populate suburb choices dynamically
    observe({
      top_suburbs <- prop_priced |>
        count(suburb, sort = TRUE) |>
        slice_head(n = 30) |>
        pull(suburb)
      updateSelectInput(session, "suburbs",
                        choices  = top_suburbs,
                        selected = top_suburbs[1:4])
    })

    # Filter data reactively
    filtered <- reactive({
      req(input$suburbs)
      d <- prop_priced |>
        filter(
          suburb    %in% input$suburbs,
          sold_year >= input$year_range[1],
          sold_year <= input$year_range[2]
        )
      if (input$prop_type != "All") {
        d <- filter(d, property_type == input$prop_type)
      }
      d |>
        mutate(
          period = floor_date(sold_date, input$granularity)
        )
    })

    # Transaction volume plot
    output$volume_plot <- renderPlotly({
      d <- filtered() |>
        count(suburb, period) |>
        filter(!is.na(period))

      p <- ggplot(d, aes(x = period, y = n, color = suburb)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 1.5, alpha = 0.7) +
        scale_y_continuous(labels = comma) +
        scale_color_brewer(palette = "Set2") +
        labs(x = NULL, y = "Transactions", color = NULL) +
        theme_minimal(base_size = 12) +
        theme(legend.position = "bottom")

      ggplotly(p, tooltip = c("x", "y", "color")) |>
        layout(legend = list(orientation = "h"))
    })

    # Median price plot
    output$price_plot <- renderPlotly({
      d <- filtered() |>
        filter(!is.na(sold_price)) |>
        group_by(suburb, period) |>
        summarise(median_price = median(sold_price, na.rm = TRUE),
                  n = n(), .groups = "drop") |>
        filter(n >= 3, !is.na(period))

      p <- ggplot(d, aes(x = period, y = median_price / 1e6,
                         color = suburb)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 1.5, alpha = 0.7) +
        scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
        scale_color_brewer(palette = "Set2") +
        labs(x = NULL, y = "Median price (AUD)", color = NULL) +
        theme_minimal(base_size = 12) +
        theme(legend.position = "bottom")

      ggplotly(p, tooltip = c("x", "y", "color")) |>
        layout(legend = list(orientation = "h"))
    })
  })
}
