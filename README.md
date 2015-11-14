# NHL Play-by-Play Viewer using R Shiny

This repo contains my first-ever [R Shiny](http://www.rstudio.com/shiny/) project.  It's simple, and represents a minimally viable app. It's super basic, but the app allows us to query and visualize the NHL's Play-by-play event logs for a given game.  

The app also leverages a simple shot probability model that I built. 

That repo can [be found here](https://github.com/Btibert3/nhl-pbp).

## Run the app locally

I updated the app for the `2015-16` seasons.  There are a few manual updates to the code that I could refactor and allow the end-user to set, but in the short run, it works.

1.  If you haven't already, [install `R` here](http://cran.us.r-project.org/)  for your OS.
2.  Open up a terminal, and type `R`  
3.  When `R` opens, type, `install.packages('shiny')` into the command line  
4.  Assuming that runs without error, run my app by typing `shiny::runGitHub("nhl-shiny", "btibert3")`  

This should fire up your default modern browser.  It will take a few moments to load the data, and will refresh every 20 seconds or so.  When you want to quit the app, go back to the terminal and type `CONTROL-C` to kill the process.

## A quick screenshot

Clearly this is very unpolished, but just a quick highlight of the dashboard app.

![dashboard](screenshot.png)

## Notes:

-  I have noticed that sometimes the app will fail with `match` errors on the MainPanel of the dashboard.  
--  I am not sure if this is the NHL refusing a `GET` request to refresh the data or if there is a bug in `Shiny`.

## About the Model

In my previous repo, I highlight a very proof-of-concept model. It's not elegant, but very effective when estimating a player's total season goals.  With respect to the point estimates (actual probability of a shot going in), it has some room for improvement; AUC is mid .7's.

The approach I use is simple: fit a logistic regression to predict a given shot going in goal given:

- the distance,  
- shot angle,  
- the wing (left/right)  
- an interaction between distance and angle

When applying the model to every shot from a player (identified by the NHL `playerid`), and correlating the actual versus predicted goals over the course of a season, the `R-squared` is a touch under `.9`. 

## TODO:

- [ ] handle invalid gameids gracefully
- [ ] Modify / change the Forecasted Goals stepchart
- [ ] Evaluate if the model should factor in time since last shot (rebounds)
- [ ] Improve the rink plot to be interactive with mouse over detail
- [ ] Better handle games.  Need to change the `helpers.R` for each season.
