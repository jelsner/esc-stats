library(shiny)
library(igraph)
library(ggraph)
library(tidygraph)
library(dplyr)

# Load DDC data
ddc_data <- read.csv("ddc_team_data.csv", stringsAsFactors = FALSE)

# Keep the default endpoint in sync with the latest event's calendar date.
latest_event_end <- max(as.Date(ddc_data$EventEndDate), na.rm = TRUE)
latest_data_year <- as.integer(format(latest_event_end, "%Y"))
late_december_day <- 15L
latest_year_is_partial <- format(latest_event_end, "%m") != "12" ||
  as.integer(format(latest_event_end, "%d")) < late_december_day
default_year_start <- 2010L
default_year_end <- latest_data_year

# UI
ui <- fluidPage(
  titlePanel("Double Disc Court Network (ego) Viewer"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("division", "Division:", choices = c("Any", "Open", "Women"), selected = "Open"),
      helpText("Only players active in the selected year range and division will appear."),
      helpText(paste0(
        "Latest available year: ", latest_data_year,
        " (latest event ended ", format(latest_event_end, "%Y-%m-%d"),
        if (latest_year_is_partial) "; this year may be incomplete)." else ")."
      )),
      sliderInput("year_range", "Year range:",
                  min = min(ddc_data$Year, na.rm = TRUE),
                  max = latest_data_year,
                  value = c(default_year_start, default_year_end), sep = "", step = 1),
      selectInput("player", "Select a player:", choices = NULL),
      numericInput("level", "Network depth (1 = teammates only, 2 = teammates-of-teammates):",
                   value = 2, min = 1, max = 3)
    ),
    
    mainPanel(
      plotOutput("egoPlot", height = "700px")
    )
  )
)

# SERVER
server <- function(input, output, session) {
  
  # Reactive: Filter data by division and year
  filtered_data <- reactive({
    df <- ddc_data %>%
      filter(Year >= input$year_range[1], Year <= input$year_range[2])
    
    if (input$division != "Any") {
      df <- df %>% filter(Division == input$division)
    }
    
    df
  })
  
  # Reactive: update player list based on filtered data
  
  observe({
    players <- sort(unique(c(filtered_data()$Player1, filtered_data()$Player2)))
    current <- input$player
    default <- "Jim Elsner"
    
    selected <- if (!is.null(current) && current %in% players) {
      current
    } else if (default %in% players) {
      default
    } else {
      players[1]
    }
    
    updateSelectInput(session, "player", choices = players, selected = selected)
  })
 
  # Reactive: Build graph
  graph_data <- reactive({
    df <- filtered_data()
    
    df %>%
      mutate(
        player_a = pmin(Player1, Player2),
        player_b = pmax(Player1, Player2)
      ) %>%
      distinct(player_a, player_b)
  })
  
  g <- reactive({
    graph_from_data_frame(graph_data(), directed = FALSE)
  })
  
  output$egoPlot <- renderPlot({
    req(input$player)
    net <- g()
    ego_id <- which(V(net)$name == input$player)
    
    if (length(ego_id) == 0) return(NULL)
    
    # Ego network subgraph
    sub_nodes <- ego(net, order = input$level, nodes = ego_id, mode = "all")[[1]]
    subg <- induced_subgraph(net, vids = sub_nodes)
    tg <- as_tbl_graph(subg)
    
    # Plot
    ggraph(tg, layout = "fr") +
      geom_edge_link(color = "gray70", alpha = 0.6) +
      geom_node_point(aes(color = name == input$player), size = 5) +
      geom_node_text(aes(label = name), repel = TRUE, size = 3) +
      scale_color_manual(values = c("steelblue", "tomato"), guide = "none") +
      labs(title = paste("Ego Network for", input$player)) +
      theme_void()
  })
}

# Run the app
shinyApp(ui = ui, server = server)

