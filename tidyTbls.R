tidyTbls <- function(x){
  # tidy tables scraped from sports-reference.com's nba match results URL
  
  # some of the NBA seasons in the 1990s only have 10 column tables
  if(length(names(x)) == 10){
    names(x) <- c('Date', 'away_team', 'away_team_score', 'home_team', 'home_team_score', 'box score', 'OT', 'Attend', 'Arena', 'Notes')
    x %>%
      add_column(`Start_ET` = NA) %>%
      select(Date, `Start_ET`, everything()) %>%
      mutate(away_team_score = as.integer(away_team_score),
             home_team_score = as.integer(home_team_score),
             Start_ET = as.character(Start_ET),
             away_team = as.character(away_team),
             home_team = as.character(home_team),
             `box score` = as.character(`box score`),
             OT = as.character(OT),
             Attend = as.character(Attend),
             Arena = as.character(Arena),
             Notes = as.character(Notes)) %>%
      filter(Date != 'Playoffs') %>%
      filter(!is.na(away_team_score))
  } else if(length(names(x)) == 11){
    set_names(x, c('Date', 'Start_ET', 'away_team', 'away_team_score', 'home_team', 'home_team_score', 'box score', 'OT', 'Attend', 'Arena', 'Notes')) %>%
      mutate(away_team_score = as.integer(away_team_score),
             home_team_score = as.integer(home_team_score),
             Start_ET = as.character(Start_ET),
             away_team = as.character(away_team),
             home_team = as.character(home_team),
             `box score` = as.character(`box score`),
             OT = as.character(OT),
             Attend = as.character(Attend),
             Arena = as.character(Arena),
             Notes = as.character(Notes)) %>%
      filter(Date != 'Playoffs') %>%
      filter(!is.na(away_team_score))
  } else {
    browser()
  }
}