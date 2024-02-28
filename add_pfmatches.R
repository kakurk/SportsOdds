add_pfmatches <- function(pfmatches, oddsDB){

  require(RMariaDB)
  require(tidyverse)

  # this section would contain code to 1.) obtain 2.) tidy pfmatches from the odds api

  # we need to see if any pf matches link to an actual match result
  dbReadTable(oddsDB, name = 'results') %>% as_tibble() -> results
  dbReadTable(oddsDB, name = 'pfmatches') %>% as_tibble() -> pfmatches.alreadyInDB

  # for each pfmatch try and find a result that occurred within 4 
  # days of the originally scheduled time
  pfmatches %>%
    add_column(results_id = NA) -> pfmatches

  for(i in 1:nrow(pfmatches)){

    pfmatches$home_team[[i]] -> home_team.pf
    pfmatches$away_team[[i]] -> away_team.pf
    pfmatches$commence_time[[i]] -> commence_time.pf

    results %>%
      filter(home_team == home_team.pf & away_team == away_team.pf) %>%
      mutate(diff = commence_time - commence_time.pf) %>%
      filter(abs(diff) < days(4)) -> find.df

    if(nrow(find.df) == 1){
      pfmatches$results_id[[i]] <- find.df$id
    } else if(nrow(find.df) > 1){
      browser()
    }

  }

  # add data to pfmatches
  anti_join(pfmatches, pfmatches.alreadyInDB) -> pfmatches.not.in.table

  dbAppendTable(oddsDB, name = 'pfmatches', pfmatches.not.in.table)

}