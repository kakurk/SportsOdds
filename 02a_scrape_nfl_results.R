# scrape NFL results from the sports reference website. see match_results
# function for more details. Note: this script takes about 10 minutes or so to
# run.

# requirements ------------------------------------------------------------

library(tidyverse)
source('match_results.R')

# routine -----------------------------------------------------------------

# extract NFL results 1990 - 2023 from the pro football reference website
match_results('americanfootball_nfl', yrs = 1990:2023) -> NFL.results
