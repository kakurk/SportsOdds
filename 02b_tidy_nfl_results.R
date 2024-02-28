# tidy NFL results
# Assumes that you already ran 02a_scrape_nfl_results.R

# requirements ------------------------------------------------------------

library(tidyverse)
source('match_results.R')
source('fix_table_names.R')

# parameters --------------------------------------------------------------

saveDir <- read_file(file = './saveDir.txt')

# routine -----------------------------------------------------------------

# the column names from the sports reference website require changing to be R compatible
NFL.results %>%
  mutate(match.results.list = map(match.results.list, fix_table_names)) -> NFL.results
  
# unnest the results
NFL.results %>%
  unnest(cols = c(match.results.list)) -> NFL.results

# remove blank and intermediate header rows
NFL.results %>% 
  filter(Week != "") %>%
  filter(Week != "Week") -> NFL.results

# misc tidying
NFL.results %>%
  add_column(sport = 'americanfootball', competition = 'nfl') %>%
  mutate(home_team = case_when(...6 == '@' ~ Loser.tie,
                               .default = Winner.tie),
         away_team = case_when(...6 == '@' ~ Winner.tie,
                               .default = Loser.tie)) %>%
  mutate(home_team_score = case_when(...6 == '@' ~ PtsL,
                                     .default = PtsW),
         away_team_score = case_when(...6 == '@' ~ PtsW,
                                     .default = PtsL)) %>%
  mutate(commence_time = parse_date_time(str_c(Date, Time, sep = ' '), orders = 'ymd H:Mp', tz = 'America/New_York')) %>%
  select(sport, competition, home_team, away_team, home_team_score, away_team_score, season, Week, commence_time) -> NFL.results

# format the table
NFL.results %>%
  mutate(home_team_score = as.integer(home_team_score),
         away_team_score = as.integer(away_team_score)) %>%
  mutate(Week = as.character(Week)) %>%
  add_column(id = ids::random_id(nrow(.)), .before = 'sport') -> NFL.results

# write
filePath <- file.path(saveDir, 'nfl_results.csv')
write_csv(NFL.results, file = filePath)
