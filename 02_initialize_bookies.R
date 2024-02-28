# scrapes data on bookies from the odds api and writes that data to a local csv
# for later importing into sql

# requirements ------------------------------------------------------------

library(httr2)
library(tidyverse)
source('scrape_tables.R')

# parameters --------------------------------------------------------------
# saveDir = directory to write .csv files for later import in MySQL database.
# Typically this directory is the '.../MySQL/Uploads' directory of your MySQL
# installation. I put the full path to my installation in a local text file.

saveDir <- read_file(file = './saveDir.txt')
url     <- 'https://the-odds-api.com/sports-odds-data/bookmaker-apis.html'

# routine -----------------------------------------------------------------

# scrape the information and tidy it up
url |>
  scrape_tables() |>
  bind_rows() |>
  rename(region = `Region key`,
         id = `Bookmaker key`,
         title = `Bookmaker`) |>
  mutate(title = str_remove(title, '\n.*$')) %>%
  select(id, title, region) %>%
  arrange(id) -> bookies

# a couple of the bookies listed on the odds api have the same bookie id. these
# entries are usually the same company having books open in multiple countries.
# For example bet365 in the US; bet365 in the EU sql requires bookie ids to be
# unique. this code identifies the entries with matching ids and makes them
# unique by appending the region to the end of the id. For example, bet365 -->
# bet365_us; bet365_eu
bookies %>%
  group_by(id) %>%
  mutate(count = n()) %>%
  ungroup() %>%
  mutate(id = case_when(count == 2 ~ str_c(id, region, sep = '_'),
                            .default = id)) %>%
  select(-count) -> bookies

# write locally
filePath <- file.path(saveDir, 'bookies.csv')
write_csv(bookies, file = filePath)