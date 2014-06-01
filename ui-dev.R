shinyUI(fluidPage(
  titlePanel("NHL Play by Play Event Viewer"),
  fluidRow(column= 12, 
           plotOutput('rinkPlot')), 
  fluidRow(column= 12, 
           tableOutput('scoreboard')), 
  fluidRow(column= 12, 
           plotOutput('stepgraph'))
  )
)



# RESIZE THE stepgraph to be much smaller scale
# TODO:  DATA TABLE BELOW