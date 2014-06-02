library(rjson)
library(RCurl)
library(plyr)
library(stringr)
library(lubridate)
library(jpeg)
library(ggplot2)
library(reshape2)

## source the helpers
source("helpers.R")

## read in the rink
rink = readJPEG("www/rink.jpg", native=F)

## load the shot model once as shot_model object
load("shot-model.Rdata")

shinyServer(function(input, output, session) {
  
  ## number of seconds to sleep
  NUM_SECS = 30
  NUM_MILLI_SECS = NUM_SECS * 1000
  
  ## TODO:  Selectively refresh the data depending the on the flag
  ## When I use REFRESH() with reactiveTimeer below, it yells about session even with it listed
#   REFRESH = reactive({
#     if(input$refreshFlag == TRUE) 90000
#     if(input$refreshFlag == FALSE) 60*60*1000
#   })
  
  
  ## http://stackoverflow.com/questions/18302579/r-shiny-update-graph-plot-with-fixed-interval-of-time
  #autoInvalidate <- reactiveTimer(20000, session)
  
  plays = reactive({
    invalidateLater(NUM_MILLI_SECS, session)
    buildPBP(input$gameid)
  })
  
  ## TODO:
  ## subset the data based on the selections from the user
  
  ## Output the rink plot
  output$rinkPlot <- renderPlot({
    invalidateLater(NUM_MILLI_SECS, session)
    g = ggplot(plays(), aes(x=xcoord, y=ycoord)) 
    g = g + annotation_raster(rink, -100, 100, -42.5, 42.5, interpolate=FALSE)
    g = g + aes(shape = factor(team_nick))
    g = g + geom_point(aes(colour=type), size=5, alpha=.8) 
    g = g + scale_colour_brewer(palette="Dark2")
    g = g + theme(    
      axis.line = element_blank(), axis.ticks = element_blank(),
      axis.text.x = element_blank(), axis.text.y = element_blank(), 
      axis.title.x = element_blank(), axis.title.y = element_blank(),
      legend.position = "top", 
      legend.title = element_blank(),
      panel.background = element_blank(), 
      panel.border = element_blank(), 
      panel.grid.major = element_blank(), 
      panel.grid.minor = element_blank(), 
      plot.title = element_blank())
    print(g)
  })
  
  ## out the scoreboard
  output$scoreboard = renderTable({
    invalidateLater(NUM_MILLI_SECS, session)
    sb = with(plays(), table(team_nick, type))
    sb = as.data.frame(sb)
    sb = dcast(sb, team_nick ~ type)
    ## apply the model
    plays2 = plays()
    plays2 = transform(plays2, 
                       goal_prob = predict(shot_model, plays2, type="response"))
    plays2$goal_prob[plays2$shotind != 1] = NA
    ## a temp dataset
    tmp = ddply(plays2, .(team_nick), 
                summarise, 
                Expected_Goals = sum(goal_prob, na.rm=T))
    ## merge onto the scoreboard
    sb = merge(sb, tmp, all.x=T)
    ## cleanup
    row.names(sb) = sb$team_nick
    sb$team_nick = NULL
    ## fix the shots to be Shots + Goals
    sb = transform(sb, Shot = Goal + Shot)
    ## calculate shot quality
    sb = transform(sb, `Shot Quality` = Expected_Goals / Shot)
    ## return the object
    sb
  }, digits = 3)
  
  ## create the Step Graph for Predicted Cume Goals
  output$stepgraph = renderPlot({
    invalidateLater(NUM_MILLI_SECS, session)
    plays2 = plays()
    plays2 = transform(plays2, 
                      goal_prob = predict(shot_model, plays2, type="response"))
    plays2$goal_prob[plays2$shotind != 1] = NA
    ## filter shots
    shots = subset(plays2, type %in% c("Shot", "Goal"))
    ## a temp dataset
    tmp = ddply(shots, .(team_nick, mins_expired), 
                summarise, 
                goal_prob = sum(goal_prob))
    ## build the dataset that we will use to chart the step
    teams = unique(tmp$team_nick)
    shot_graph_tmp = data.frame()
    for (team in teams) {
      tmp_df = data.frame(team_nick = team,
                          mins_expired = 0:max(tmp$mins_expired))
      shot_graph_tmp = rbind.fill(shot_graph_tmp, tmp_df)
    }
    ## add the data
    shot_graph_tmp = merge(shot_graph_tmp, tmp, all.x=T)
    ## for each team, subset, make cume goals work properly, rebuild
    shot_graph = data.frame(stringsAsFactors=F)
    for (team  in teams) {
      tmp_df = subset(shot_graph_tmp, team_nick == team)
      tmp_df$goal_prob[is.na(tmp_df$goal_prob)] = 0
      tmp_df = transform(tmp_df, cume_goals = cumsum(goal_prob))
      shot_graph = rbind.fill(shot_graph, tmp_df)
    }
    ## arrange the data
    shot_graph = arrange(shot_graph, mins_expired)
    ## plot the data
    g = ggplot(shot_graph, aes(mins_expired, cume_goals, col=team_nick)) + geom_line()
    g = g + scale_colour_brewer(palette="Dark2")
    g = g + ylab("Predicted # of Goals") + xlab("# of Minutes Played")
    g = g + theme(      
      axis.line = element_blank(), axis.ticks = element_blank(),
      legend.position = "top", 
      legend.title = element_blank(),
      panel.background = element_blank(), 
      panel.border = element_blank(), 
      panel.grid.major = element_blank(), 
      panel.grid.minor = element_blank(), 
      plot.title = element_blank())
    print(g)

  })
  
  output$plays = renderDataTable({
    invalidateLater(NUM_MILLI_SECS, session)
    pbp = plays()
    ## apply the model
    pbp = transform(pbp, 
                    Goal_Probability = predict(shot_model, pbp, type="response"))
    pbp$Goal_Probability[pbp$shotind != 1] = NA
    ## sort the data
    pbp = arrange(pbp, desc(period), desc(time))
    pbp = subset(pbp, select = c(period, time, type, desc, Goal_Probability))
    pbp
  })

})