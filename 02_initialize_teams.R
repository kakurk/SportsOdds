# initialize teams
# grab all sports teams that competed in the NBA, NFL, and the English Premier
# League from 1990-2023
# scrape this information from sports reference website

# requirements ------------------------------------------------------------

library(tidyverse)
library(httr2)
source('scrape_tables.R')


# parameters --------------------------------------------------------------

saveDir <- read_file(file = './saveDir.txt')

# routine -----------------------------------------------------------------

# NFL Teams ---------------------------------------------------------------

url <- 'https://www.pro-football-reference.com/teams/'
url |>
  scrape_tables() |>
  bind_rows() -> NFL.teams

NFL.teams %>%
  slice(1) -> header

NFL.teams %>%
  slice(2:nrow(NFL.teams)) -> NFL.teams

names(NFL.teams) <- as.character(header)

NFL.teams %>%
  select(Tm) %>%
  distinct() %>%
  rename(team_name = Tm) -> NFL.teams

# NBA Teams ---------------------------------------------------------------

url <- 'https://www.basketball-reference.com/teams/'
url |>
  scrape_tables() |>
  bind_rows() %>%
  select(Franchise) %>%
  distinct() %>%
  rename(team_name = Franchise) -> NBA.teams

# EPL Teams ---------------------------------------------------------------
# the premier league was established in 1992. the EPL is different from the NBA
# and the NFL due to its relegation system. in the relegation system, the 3
# lowest performing teams are removed from the league and are replaced with the
# 3 highest performing teams from the league below. Thus, in order to access all
# of the teams that ever competed in the Premier League, we need to scrape the
# league tables from 1992-2002

yrs   <- 1992:2022
teams <- vector(mode = 'list', length = length(yrs))
i <- 0
for(y in yrs){
  i <- i + 1
  url <- str_glue('https://fbref.com/en/comps/9/{y}-{y+1}/{y}-{y+1}-Premier-League-Stats')
  url |>
    scrape_tables() |>
    magrittr::extract2(1) %>%
    select(Squad) -> teams[[i]]
  
  # need to add a brief delay to avoid overwhelming the sports reference website server
  Sys.sleep(6)
}

bind_rows(teams) %>%
  distinct() %>%
  rename(team_name = Squad) -> EPL.teams

# bind and write ----------------------------------------------------------

bind_rows(NFL.teams, NBA.teams, EPL.teams, .id = 'sport_id') %>%
  mutate(sport_id = factor(sport_id, labels = c('americanfootball', 'basketball', 'soccer'))) -> teams

filePath <- file.path(saveDir, 'teams.csv')
write_csv(teams, file = filePath)