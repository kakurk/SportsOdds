tidy_historical_odds <- function(historical.odds){
  # tidy historical odds pulled from the odds api

  # identify all of the unique pfmatches in the query
  historical.odds %>%
    unnest(data) %>%
    select(-ends_with('timestamp'), -bookmakers, -sport_title) %>%
    mutate(commence_time = as_datetime(commence_time, tz = 'America/New_York')) %>%
    distinct() -> historical.odds

  historical.odds %>% 
    group_by(id) %>% 
    summarise(commence_time = min(commence_time), across(-commence_time, unique), .groups = 'drop') %>%
    separate(sport_key, into = c('sport_key', 'competition_id')) -> pfmatches

  return(pfmatches)

}

