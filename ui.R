shinyUI(fluidPage(
  titlePanel("NHL Play by Play Event Viewer"),
  sidebarLayout(
    sidebarPanel(
      h2("About this App"),
      p("This is a simple app to visualize the events of a live NHL game."),
      p("For more information, check out my blog post ",
        a("here. ",
          href = "http://www.brocktibert.com/posthere")),
      p("Use the options below to you change what is shown on the rink and how often the data are refreshed."),
      hr(),
      textInput("gameid", label = h5("The NHL.com gameid"), value = "2013030326"),
      #       checkboxInput("refreshFlag", label = h5("Auto-refresh?"), value = TRUE),
      #       checkboxGroupInput("periodShow", label = h5("Filter the Periods to display"), 
      #                          choices = list("Period 1" = 1, "Period 2" = 2, "Period 3" = 3, "1st OT" = 4, "2nd OT" = 5),
      #                          selected = c(1, 2, 3, 4, 5)),
      #       checkboxGroupInput("eventShow", label = h5("Filter the events to display"), 
      #                          choices = list("Shots" = 1, "Goals" = 2, "Hits" = 3, "Penalties / Fights" = 4),
      #                          selected = c(1, 2, 3, 4)),
      br()
    ),
#     mainPanel(
#       plotOutput('rinkPlot'), 
#       fluidRow(
#         column(7,
#                tableOutput("scoreboard")),
#         column(5,
#                plotOutput("stepgraph")))
      mainPanel(
        plotOutput('rinkPlot'), 
        tableOutput("scoreboard"),
        plotOutput("stepgraph"))
    )
    
  ))


# RESIZE THE stepgraph to be much smaller scale
# TODO:  DATA TABLE BELOW