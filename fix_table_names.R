fix_table_names <- function(x){
  # fix table names
  
  require(vctrs)
  require(magrittr)
  
  # use the vctrs package to automatically fix table names
  names(x) %>%
    vec_as_names(repair = 'universal') -> repaired_column_names
  
  # overwrite the existing table names with the repaired ones
  x %>%
    set_names(repaired_column_names) -> x
  
  return(x)
  
}