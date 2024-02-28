request_nfl_odds <- function(NFL.results){
  # request nfl historical odds

  # requirements
  source('webscrape_event_outcomes.R')
  source('identify_previous_wednesday.R')
  source('request_historical_odds.R')
  source('tidy_nfl.R')
  library(tidyverse)
  library(stringr)

  # historical odds ---------------------------------------------------------

  apiKey <- read_file(file = 'apiKey.txt')
  sport  <- 'americanfootball_nfl'
  market <- 'h2h'
  region <- c('eu', 'us')

  # identify each date in the NFL results tbl. Find the closest Wednesday before that date. Only use those Wednesday dates.

  NFL.results %>%
    mutate(PrevWed = map(Date, .f = identify_previous_wednesday)) %>%
    unnest(cols = c(PrevWed)) %>%
    pull(PrevWed) %>%
    unique() -> WednesdaysToRequest

  expand_grid(region, WednesdaysToRequest) %>%
    mutate(datetime = format_ISO8601(WednesdaysToRequest, usetz = 'Z')) -> requestTbl

  map2_dfr(.x = requestTbl$region,
           .y = requestTbl$datetime,
           .f = \(x,y) request_historical_odds(sport    = sport,
                                               market   = market,
                                               region   = x,
                                               datetime = y,
                                               apiKey   = apiKey)) -> historical.nfl.odds

  return(historical.nfl.odds)

}
