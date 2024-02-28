## master script
# This script initializes a MySQL database of betting odds
# The steps of this process include:
# Step 01 -- initialize MYSQL Tables
# Step 02 -- create csv uploads
# Step 03 -- upload csv to MYSQL Tables

library(RMariaDB)
library(httr2)
source('scrape_tables.R')
source('add_entry_to_pfmatches.R')

# Step 01 -----------------------------------------------------------------
# OPEN MySQL Workbench and run 01_initialize_tables.sql

# Step 02 -----------------------------------------------------------------
# Generate csv files to upload to MySQL

source('02_initialize_bookies.R')
source('02_initialize_competition_sport_tables.R')
source('02_initialize_markets.R')
source('02_initialize_teams.R')
source('02a_scrape_nfl_results.R')
source('02b_tidy_nfl_results.R')
source('02_initialize_epl_results.R')
source('02_initialize_nba_results.R')

# compile NFL, NBA, and EPL results into a single csv for later uploading to SQL database

# intermediate, league specific results files generated in previous steps
saveDir      <- read_file(file = './saveDir.txt')
resultsFiles <- c('epl_results.csv', 'nba_results.csv', 'nfl_results.csv')

# compile
str_c(saveDir, resultsFiles, sep = '/') %>%
  map_dfr(\(x) read_csv(x, col_types = cols(Week = 'c'))) %>%
  mutate(commence_time = format(commence_time, format = '%Y-%m-%d %H:%M:%S', tz = 'US/Eastern')) %>%
  filter(!is.na(home_team_score)) -> results

# write
filePath <- file.path(saveDir, 'results.csv')
write_csv(results, file = filePath)

# Step 03 -----------------------------------------------------------------
# OPEN MySQL Workbench and run 03_load_data_from_csv.sql

# Step 04 -----------------------------------------------------------------
# Add potential future matches to the database

# setup code
source('tidy_historical_odds.R')
source('add_pfmatches.R')

# hiding the username and password from the public in ignored local text files
dbPass <- read_file(file = 'user.txt')
dbUser <- read_file(file = 'password.txt')

oddsDB <- dbConnect(MariaDB(), 
                    user = dbUser,
                    password = dbPass, 
                    dbname = 'oddsDB', 
                    host = 'localhost')

hist.odds.file  <- file.choose()
historical.odds <- read_rds(file = hist.odds.file)
tidy_historical_odds(historical.odds) -> pfmatches
add_pfmatches(pfmatches)

# Step 05 Add Bets to Database --------------------------------------------

# we need to see if any pf matches link to an actual match result
dbReadTable(oddsDB, name = 'bets') %>% 
  as_tibble() -> bets.in.DB

historical.odds %>%
  mutate(timestamp = as_datetime(timestamp),
         timestamp = with_tz(timestamp, tzore = 'US/Eastern')) %>%
  unnest(cols = c(data)) %>%
  rename(pfmatch_id = id) %>%
  select(timestamp, pfmatch_id, bookmakers) %>%
  unnest(cols = c(bookmakers)) %>%
  select(timestamp, pfmatch_id, key, markets) %>%
  rename(bookie_id = key) %>%
  unnest(cols = c(markets), names_sep = '_') %>%
  select(-markets_last_update) %>%
  unnest(cols = c(markets_outcomes)) %>%
  distinct() %>%
  add_column(id = ids::random_id(nrow(.))) -> bets

anti_join(bets, bets.in.DB) -> bets.to.add

dbAppendTable(oddsDB, name = 'bets', bets.to.add)

# Analysis 1 --------------------------------------------------------------

rmarkdown::render(input = '04_glmPredict.Rmd')

# Analysis 2 --------------------------------------------------------------

rmarkdown::render(input = '05_longshot_favorite_bias_simulation.Rmd')
