# scrapes data on sports and compeitions/leagues from the odds api and writes
# that data to a local csv for later importing into sql

# requirements ------------------------------------------------------------

library(httr2)
library(tidyverse)
source('scrape_tables.R')

# parameters --------------------------------------------------------------
# saveDir = directory to write .csv files for later import in MySQL database.
# Typically this directory is the '.../MySQL/Uploads' directory of your MySQL
# installation. I put the full path to my installation in a local text file.

saveDir <- read_file(file = './saveDir.txt')
url     <- 'https://the-odds-api.com/sports-odds-data/sports-apis.html'

# routine -----------------------------------------------------------------

# scrape sports information from odds api website and tidy it up.
url |>
  scrape_tables() |>
  bind_rows() |>
  rename(sport       = `Group`,
         title       = `League / Tournament`,
         id          = `Sport Key (use in the API)`) |>
  mutate() %>%
  select(-`Scores & Results`) -> competition

# the table on the sports api website contains information about available
# leagues/competitions. I would like to create a seperate table for sport. A
# sport can have multiple leagues/compeitions. For example, soccer has multiple
# leagues (e.g., English Premier League, Spanish La Liga, German Bundesliga) and
# multiple competitions (e.g., Champions League, Europa League, FA Cup). The
# sports table has the sports (e.g., soccer, basketball, football). The
# compeitions table has the leagues/compeitions (e.g., FA Cup, NBA)
competition %>%
  select(id, sport) %>%
  mutate(id = str_extract(id, '^[a-z]*(?>\\_)')) %>%
  mutate(id = str_remove(id, '_')) %>%
  distinct() %>%
  rename(title = sport) -> sport

# competition
competition %>%
  mutate(id_sport = str_extract(id, '^([a-z]*)(\\_)(.*)$', group = 1)) %>%
  mutate(id       = str_extract(id, '^([a-z]*)(\\_)(.*)$', group = 3)) %>%
  rename(title_sport = sport) %>%
  select(id, title, id_sport) %>%
  arrange(id) %>%
  group_by(id) %>%
  mutate(count = n()) %>%
  ungroup() %>%
  mutate(id = case_when(count == 2 ~ str_c(id, id_sport, sep = '_'),
                        .default = id)) %>%
  select(-count) -> competition

# write
filePath <- file.path(saveDir, 'sports.csv')
write_csv(sport, file = filePath)

filePath <- file.path(saveDir, 'competitions.csv')
write_csv(competition, file = filePath)