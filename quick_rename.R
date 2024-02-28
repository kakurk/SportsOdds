quick_rename <- function(x){
  # rename a column IFF the dataframe x has the column
  if('Market Names' %in% names(x)){
    x %>%
      rename(`Market Name` = `Market Names`) -> x
    return(x)
  } else {
    return(x)
  }
}