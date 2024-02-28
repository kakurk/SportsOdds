# Create CSV Files for the SQL Database
# initialize a SQL table for potential future matches

# requirements ------------------------------------------------------------

library(tidyverse)
library(httr2)
source('scrape_tables.R')

# parameters --------------------------------------------------------------

saveDir <- read_file(file = './saveDir.txt')

# routine -----------------------------------------------------------------

# Matches SQL Table -------------------------------------------------------

NFL.results     <- read_rds('intermediate/NFL_results.Rds')
historical.odds <- read_rds('intermediate/historical_nfl_odds.Rds')

historical.odds %>%
  unnest(cols = c(data)) %>%
  select(id, sport_key, sport_title, commence_time, home_team, away_team) %>%
  mutate(commence_time = as_datetime(commence_time))  -> odds.Games

NFL.results %>%
  mutate(Date = as.character(Date),
         Time = as.character(Time)) %>%
  mutate(commence_time = str_c(Date, Time, sep = ' ')) %>%
  mutate(commence_time = ymd_hms(commence_time)) %>%
  select(-Date, -Time, -Day) -> NFL.results

NFL.results %>%
  group_by(season, Week) %>%
  summarise(early = min(commence_time), late = max(commence_time), .groups = 'drop') %>%
  mutate(early = floor_date(early, unit = 'day'), late = ceiling_date(late, unit = 'day')) -> seasonWkIntervals

# manually setting the interval for week 13 of the 2020 season. The Thursday night game between 
# the Baltimore Ravens and the Dallas Cowboys was pushed back due to Covid.
seasonWkIntervals$early[13] <- as_datetime('2020-12-04 UTC')

# manually setting the interval for week 17 of the 2023 season. The game between the Bengals and the Bills was suspended 
# indefinitely due to a severely injured players
which(seasonWkIntervals$season == '2022' & seasonWeekIntervals$Week == 17) -> idx
seasonWkIntervals$late[idx] <- as_datetime('2023-01-03 UTC')

seasonWkIntervals %>%
  mutate(seasonWkInterval = interval(start = early, end = late)) %>%
  select(-early, -late) -> seasonWkIntervals

# something is wrong here

for(i in 1:nrow(odds.Games)){
  floor_date(odds.Games$commence_time[[i]], unit = 'day') %within% seasonWkIntervals$seasonWkInterval -> booleanFilter
  assertthat::assert_that(sum(booleanFilter) == 1, msg = 'ERROR')
}

powerjoin::power_left_join(odds.Games, seasonWkIntervals, 
                           by = c(~floor_date(.x$commence_time, unit = 'day') %within% .y$seasonWkInterval)) -> odds.Games

odds.Games %>%
  distinct() -> odds.Games

anti_join(odds.Games, NFL.results, by = c('home_team', 'away_team', 'season', 'Week')) %>%

odds.Games %>%
  select(id, sport_key,commence_time_oddsapi:away_team,season,Week,commence_time_pfr,`Winner/tie`,`Loser/tie`, PtsW:TOL) %>%
  nrow() -> matches

filePath <- file.path(saveDir, 'matches.csv')
write_csv(matches, file = filePath)
