adjustment <- function(x){
  require(implied)
  implied_probabilities(x, method = 'power') %>% 
    magrittr::extract2('probabilities') %>%
    as.vector()
}