# markets
# pull market information from the odds api website. Write it locally to a csv
# file.

# requirements ------------------------------------------------------------

library(tidyverse)
library(httr2)
source('quick_rename.R')

# parameters --------------------------------------------------------------

url <- 'https://the-odds-api.com/sports-odds-data/betting-markets.html'
saveDir <- read_file(file = './saveDir.txt')

# routine -----------------------------------------------------------------

# scrape and tidy
url |>
  scrape_tables() |>
  map_dfr(.f = quick_rename) |>
  rename(id = `Market Key (use in the API)`,
         title = `Market Name`,
         description = Description,
         note = Note) %>%
  # 5 rows repeat for whatever reason
  distinct() -> markets

# write
filePath <- file.path(saveDir, 'markets.csv')
write_csv(markets, file = filePath)
