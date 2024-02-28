match_results <- function(compeition, yrs, month = NA){

  require(httr2)
  require(xml2)

  # create a database of match results for this competition
  if(compeition == 'americanfootball_nfl'){
    url_glue_str <- 'https://www.pro-football-reference.com/years/{yrs[[y]]}/games.htm' 
  } else if(compeition == 'icehockey_nhl'){
    url_glue_str <- 'https://www.hockey-reference.com/leagues/NHL_{yrs[[y]]}_games.html'
  } else if(compeition == 'basketball_nba'){
    url_glue_str <- 'https://www.basketball-reference.com/leagues/NBA_{yrs[[y]]}_games-{month}.html'
  } else if(compeition == 'soccer_epl'){
    url_glue_str <- 'https://fbref.com/en/comps/9/{yrs[[y]]}-{yrs[[y]]+1}/schedule/{yrs[[y]]}-{yrs[[y]]+1}-Premier-League-Scores-and-Fixtures'
  } else if(compeition == 'baseball_mlb'){
    url_glue_str <- ''
  }

  match.results.list <- vector(mode = 'list', length = length(yrs))

  for(y in 1:length(yrs)){
    tryCatch(
      {
        str_glue(url_glue_str) %>%
          request() |>
          req_perform() |>
          resp_body_html() |>
          xml_find_all(".//table") |>
          rvest::html_table() |>
          magrittr::extract2(1)
        },
      error = function(e){
        return(NA)
      }
    ) -> match.results.list[[y]]
   Sys.sleep(10)
  }

  tibble(season = yrs, match.results.list)

}