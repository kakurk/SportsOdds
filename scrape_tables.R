scrape_tables <- function(url){
  # scrape all tables on the select URL page. Returns them as a list.
  require(httr2)
  require(rvest)
  require(xml2)
  req  <- request(url)
  resp <- req_perform(req)
  resp |>
    resp_body_html() |>
    xml_find_all(".//table") |>
    html_table()
}