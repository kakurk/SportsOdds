# extract NFL results

# requirements ------------------------------------------------------------

library(tidyverse)
source('match_results.R')
source('tidyTbls.R')

# parameters --------------------------------------------------------------

saveDir <- read_file(file = './saveDir.txt')

# routine -----------------------------------------------------------------
# extract NFL results 1990 - 2023 from the pro football reference website the
# NBA match results are listed on different webpages according to month. Check
# all of the months typically associated with an NBA season (Oct-June)

nba.months <- c(month(10:12, label = TRUE, abbr = FALSE), month(1:6, label = TRUE, abbr = FALSE)) %>% 
               as.character() %>%
               str_to_lower()
NBA.results <- vector(mode = 'list', length = length(nba.months))
for(m in 1:length(nba.months)){
  match_results('basketball_nba', yrs = 1990:2023, month = nba.months[[m]]) -> NBA.results[[m]]
}

# remove entires that aren't tibbles; tidy them up a bit before unnesting
NBA.results %>% 
  map(.f = \(x) filter(x, map_lgl(match.results.list, is_tibble))) %>%
  bind_rows() %>%
  mutate(match.results.list = map(match.results.list, tidyTbls)) %>%
  unnest(match.results.list) -> tmp

# add random alphanumeric id; sport, competition ids; clean up commence_time
tmp %>%
  add_column(id = ids::random_id(nrow(tmp)), .before = 'seasons') %>%
  add_column(sport = 'basketball', .after = 'id') %>%
  add_column(competition = 'nba', .after = 'sport') %>%
  mutate(Start_ET = str_replace(Start_ET, 'p', 'pm')) %>%
  mutate(Start_ET = str_replace(Start_ET, 'a', 'am')) %>%
  mutate(Start_ET = str_replace_na(Start_ET, replacement = '')) %>%
  mutate(commence_time = str_c(Date, Start_ET, sep = ' '),
         commence_time = str_trim(commence_time)) -> tmp2

# clean up commence_time
tmp2 %>%
  mutate(commence_time = case_when(Start_ET != '' ~ as_datetime(commence_time, format = "%a, %B %d, %Y %I:%M%p"),
                                   .default = as_datetime(commence_time, format = '%a, %B %d, %Y'))) -> tmp3

tmp3 %>%
  add_column(Week = NA) %>%
  select(id, sport, competition, home_team, away_team, home_team_score, away_team_score, season, Week, commence_time) %>%
  mutate(Week = as.character(Week)) -> results.nba

# write
filePath <- file.path(saveDir, 'nba_results.csv')
write_csv(results.nba, file = filePath)
