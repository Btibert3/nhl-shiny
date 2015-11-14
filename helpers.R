## load the packages
library(rjson)
library(RCurl)
library(plyr)
library(stringr)


###############################################################################
## Main function to get the data
###############################################################################
buildPBP = function(gameid = "2015020230") {
  ## bring in the game
  game_raw = getPBP(gameid)
  ## parse the game events
  plays = parsePBP(game_raw)
  ## predicts shot location based on periods 1/3
  plays = shotLOC(plays) 
  # calculate the angle relative to the goal -- calc is +/- for the wing
  plays = transform(plays, angle = calcAngle(xcoord, ycoord, gx))
  ## convert the shots to same half of ice and standardize the angle
  plays = transform(plays,
                    xcoord_all = ifelse(gx == -89, -1*xcoord, xcoord),
                    ycoord_all = ifelse(gx == -89, -1*ycoord, ycoord), 
                    angle_all = ifelse(angle < 0 , -1* angle, angle),
                    wing = ifelse(angle < 0 , "R", "L"),
                    styp2 = stype)
  # time expired etc
  plays = transform(plays, mins_expired = period * (minute(ms(time))+1))
  # team nickname for each event
  plays = transform(plays, team_nick = ifelse(teamid==hometeamid, hometeamnick, awayteamnick))
  ## make the event types a factor
  plays$type = factor(plays$type, 
                      levels = c("Goal",
                                 "Shot",
                                 "Hit",
                                 "Penalty",
                                 "Fight"))
  ## return the dataset
  return(plays)
}


###############################################################################
## Function to get the game specified and return the data as a list
###############################################################################
getPBP = function(gameid="2015020230") {
  ## build the parameters that should be inputs later
  SEASON = '20152016'
  BASE = "http://live.nhl.com/GameData/"
  URL = paste0(BASE, SEASON, "/", gameid, "/PlayByPlay.json")
  ## get the data
  raw_pbp = tryCatch(getURL(URL), 
                     error=function(e) e)
  if (inherits(raw_pbp, "error")) {
    return(list())
  }
  ## parse the data
  raw_pbp = tryCatch(fromJSON(raw_pbp), 
                     error=function(e) e)
  if (inherits(raw_pbp, "error")) {
    return(list())
  }
  ## assert that raw_pbp is a list
  if(!mode(raw_pbp) == "list") {
    return(list())
  }
  ## add the gameid to the 
  raw_pbp = c(raw_pbp, gameid = gameid)
  ## return the data
  return(raw_pbp)
}
#tmp = getPBP()



###############################################################################
## parse the gameinfo into a dataframe
## returns a dataframe with the game info if it exists
## need to check for the "base" dataframe if the game hasnt started yet
###############################################################################
parsePBP = function(x) {
  tmp <- x$data$game
  # extract the teams
  team = data.frame(awayteamid = tmp$awayteamid,
                    awayteamname = tmp$awayteamname,
                    awayteamnick = tmp$awayteamnick,
                    hometeamname = tmp$hometeamname,
                    hometeamnick = tmp$hometeamnick,
                    hometeamid = tmp$hometeamid,
                    gameid = x$gameid,
                    stringsAsFactors=F)
  # parse the pbp data
  tmp = tmp$plays$play
  df = data.frame(stringsAsFactors=F)
  if (length(tmp) == 0) {
    return(team)
    next
  }
  for(i in 1:length(tmp)) {
    z = tmp[[i]]  
    # parse the data into a data frame
    df.temp <- as.data.frame(t(unlist(z)), stringsAsFactors=F)  
    df.temp$seqnum <- i
    # append the data
    df = rbind.fill(df, df.temp)
  }
  # join on the metadata about the game
  df = cbind(df, team)
  df$homeind = as.numeric(df$teamid == df$hometeamid)
  df$gameid = x$gameid
  df$seasonid = x$season
  # fix the columns with the helper function
  fixCols = function(df) {
    # fix the data types
    COLS = c('hsog','asog','xcoord','ycoord','period','teamid')
    for (COL in COLS) {
      if (COL %in% colnames(df)) {
        df[,COL] = as.numeric(df[,COL])
      }
    }
    # shot data
    df$shotind = as.numeric(df$type %in% c('Shot','Goal'))
    df$goalind[df$shotind==1] = as.numeric(df$type[df$shotind==1] == 'Goal')
    return(df)
  }
  # fix the columns
  df = fixCols(df)
  ## extract the shot type
  shotType = function(x) {
    require(stringr)
    pattern = "[A-Za-z]+ Shot|Backhand|Tip-In|Wrap-Around|Deflection"
    tmp = str_extract(x, pattern)
    return(tmp)
  }
  df = transform(df, stype = shotType(df$desc))
  df$stype = as.character(df$stype)
  df$emptynet = NA
  ## return the data frame
  return(df)
}



###############################################################################
## put some location data onto the shots for reference
###############################################################################
## Function to predict the goal location (x/y coords) for each team in a game
shotLOC = function(df) {
  ## set goal locations by using the min shot distance for home team periods 1/3
  ## home goal periods 1/3 = see wikipedia distance below of 11 feet
  G1 =  -89
  G2 = 89
  ## subset the df to include only periods 1/3
  tmp = subset(df, period %in% c(1,3) & shotind==1 & teamid==hometeamid)
  tmp = mutate(tmp, 
               dist1 = sqrt( (xcoord-G1)^2 + (ycoord-0)^2 ),
               dist2 = sqrt( (xcoord-G2)^2 + (ycoord-0)^2 ),
               goalpos = ifelse(dist1 < dist2, "G1", "G2"),
               glocx = ifelse(goalpos=='G1', -89, 89),
               glocy = 0)
  ## for each game, where does the home team shoot for periods 1/3
  home = ddply(tmp, .(gameid), summarise,
               goal_pos = ifelse(mean(dist1) < mean(dist2), "G1", "G2"),
               glocx = ifelse(mean(dist1) < mean(dist2), -89, 89),
               glocy = 0)
  ## merge the home locations for periods 1/3 to all events
  m = merge(df, home, all.x=T)
  ## assing the goal loc and distance for every event
  m$gx = NA
  R = which(m$homeind==1 & m$period %in% c(1,3,5,7))
  m$gx[R] = m$glocx[R]
  R = which(m$homeind==0 & m$period %in% c(1,3,5,7))
  m$gx[R] = m$glocx[R] * -1
  R = which(m$homeind==1 & m$period %in% c(2,4,6,8))
  m$gx[R] = m$glocx[R] * -1
  R = which(m$homeind==0 & m$period %in% c(2,4,6,8))
  m$gx[R] = m$glocx[R]
  # append the data
  m = mutate(m,
             gy = 0, 
             gdist = sqrt( (xcoord-gx)^2 + (ycoord-gy)^2 ))
  ## cleanup the temp calcs that we dont need
  m$goal_pos = NULL
  m$glocx = NULL
  m$glocy = NULL
  m$gy = NULL
  ## return the data frame with the extra calcs
  return(m)
}  





###############################################################################
## calculate the angle of the shot relative to goal
###############################################################################
calcAngle = function(ex, ey, gx) {
  ## http://goo.gl/EQE5K
  ## uses site above, but adjusts slightly to make calc easier 
  ex = ifelse(gx==89, ex, -ex)
  ey = ifelse(gx==89, ey, -ey)
  deltaY = abs(ey) - 0  ## abs(ey) keeps lw/rw shots/events at the same angle
  #deltaY = ey - 0  
  deltaX = 89 - ex
  #angleInDegrees = atan(deltaY / deltaX) * 180 / pi
  angleInDegrees = atan2(deltaY, deltaX) * 180 / pi
  angleAdj = angleInDegrees
  return(angleAdj)
}

# calcAngle = function(ex, ey, gx, makeEqual=F) {
#   ## http://goo.gl/EQE5K
#   ## uses site above, but adjusts slightly to make calc easier 
#   ex = ifelse(gx==89, ex, -ex)
#   ey = ifelse(gx==89, ey, -ey)
#   #deltaY = abs(ey) - 0  ## abs(ey) keeps lw/rw shots the same angle
#   ## makeEqual = FALSE allows negative angles to keep lw/rw angles, TRUE = same
#   deltaY = ifelse(makeEqual==F, ey - 0, abs(ey) - 0)  
#   deltaX = 89 - ex
#   angleInDegrees = atan(deltaY / deltaX) * 180 / pi
#   angleInDegrees = atan2(deltaY, deltaX) * 180 / pi
#   angleAdj = angleInDegrees
#   return(angleAdj)
# }

