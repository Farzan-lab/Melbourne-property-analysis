# ============================================================
# shiny_app/modules/mod_predict.R — Price Predictor Module
# ============================================================

mod_predict_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(4, 8),
      card(
        card_header("🏡 Property Details"),
        selectInput(ns("suburb"), "Suburb",
                    choices = c("Mulgrave", "Vermont South", "Doncaster East",
                                "Rowville", "Glen Waverley", "Wheelers Hill")),
        numericInput(ns("beds"),    "Bedrooms",  value = 4, min = 1, max = 10),
        numericInput(ns("baths"),   "Bathrooms", value = 2, min = 1, max = 8),
        numericInput(ns("parking"), "Parking",   value = 2, min = 0, max = 6),
        numericInput(ns("area"),    "Land area (m²)", value = 500, min = 50),
        checkboxInput(ns("renovated"),     "Recently renovated", value = TRUE),
        checkboxInput(ns("near_shopping"), "Near shopping centre", value = TRUE),
        checkboxInput(ns("near_school"),   "Near primary school", value = TRUE),
        sliderInput(ns("pred_year"), "Prediction year",
                    min = 2024, max = 2030, value = 2026, step = 1, sep = ""),
        sliderInput(ns("pred_month"), "Prediction month",
                    min = 1, max = 12, value = 7, step = 1),
        actionButton(ns("predict_btn"), "Predict price",
                     class = "btn-primary w-100")
      ),
      card(
        card_header("💰 Predicted Price"),
        uiOutput(ns("prediction_output")),
        plotlyOutput(ns("suburb_comparison"), height = "350px")
      )
    )
  )
}

mod_predict_server <- function(id, prop_priced, model) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    prediction <- eventReactive(input$predict_btn, {
      req(model)

      input_data <- tibble(
        suburb         = input$suburb,
        beds           = input$beds,
        baths          = input$baths,
        parking        = input$parking,
        area_log       = log1p(input$area),
        sold_year_num  = input$pred_year,
        sold_month_num = input$pred_month,
        is_renovated   = input$renovated,
        near_shopping  = input$near_shopping,
        near_school    = input$near_school
      )

      tryCatch({
        pred <- predict(model, new_data = input_data)
        exp(pred$.pred)
      }, error = function(e) NA_real_)
    })

    output$prediction_output <- renderUI({
      pred <- prediction()
      if (is.null(pred) || is.na(pred)) {
        tags$p("Run analysis scripts first to train the model.",
               class = "text-muted")
      } else {
        tagList(
          tags$h2(dollar(pred, prefix = "$", big.mark = ",", accuracy = 1000),
                  class = "text-primary text-center mt-3"),
          tags$p(
            glue::glue("Predicted for {input$suburb} — ",
                       "{month.name[input$pred_month]} {input$pred_year}"),
            class = "text-muted text-center"
          )
        )
      }
    })

    # Comparison across all 6 Chris suburbs
    output$suburb_comparison <- renderPlotly({
      req(model)

      suburbs_6 <- c("Mulgrave", "Vermont South", "Doncaster East",
                     "Rowville", "Glen Waverley", "Wheelers Hill")

      comp_data <- tibble(
        suburb         = suburbs_6,
        beds           = input$beds,
        baths          = input$baths,
        parking        = input$parking,
        area_log       = log1p(input$area),
        sold_year_num  = input$pred_year,
        sold_month_num = input$pred_month,
        is_renovated   = input$renovated,
        near_shopping  = input$near_shopping,
        near_school    = input$near_school
      )

      tryCatch({
        preds <- predict(model, new_data = comp_data)
        comp_data$predicted_price <- exp(preds$.pred)

        p <- comp_data |>
          mutate(suburb = fct_reorder(suburb, predicted_price),
                 highlight = suburb == input$suburb) |>
          ggplot(aes(x = suburb, y = predicted_price / 1e6,
                     fill = highlight,
                     text = paste0(suburb, "\n$",
                                   scales::comma(round(predicted_price, -3))))) +
          geom_col(width = 0.7) +
          scale_fill_manual(values = c("FALSE" = "#B5D4F4",
                                       "TRUE"  = "#185FA5"),
                            guide = "none") +
          scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "M")) +
          coord_flip() +
          labs(x = NULL, y = "Predicted price (AUD millions)") +
          theme_minimal(base_size = 11)

        ggplotly(p, tooltip = "text")
      }, error = function(e) {
        plotly_empty() |>
          layout(title = "Train the model first (run 07_price_prediction.R)")
      })
    })
  })
}
