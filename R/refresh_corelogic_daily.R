# Load Corelogic daily house price index

library(readxl)
library(lubridate)
library(dplyr)
library(stringr)
library(RCurl)
library(readr)
library(fst)

todays_date <- Sys.Date()
current_year <- year(todays_date)
current_month <- str_pad(month(todays_date), 2, pad = "0")
today <- str_pad(day(todays_date), 2, pad = "0")
yesterday <- str_pad(day(todays_date - 1), 2, pad = "0")

corelogic_base_url <- "http://download.rpdata.com/asx/CoreLogic_HVI_365_days_"
corelogic_current_url <- paste0(corelogic_base_url, current_year, current_month, today, ".xlsx")
corelogic_yesterdays_url <- paste0(corelogic_base_url, current_year, current_month, yesterday, ".xlsx")

corelogic_url <- ifelse(RCurl::url.exists(corelogic_current_url),
                        corelogic_current_url,
                        corelogic_yesterdays_url)


corelogic_filepath <- here::here("data-raw", "corelogic")
latest_filepath <- file.path(corelogic_filepath, "corelogic_daily.xlsx")
archive_filepath <- file.path(corelogic_filepath, "archive", 
                              paste0("corelogic_daily_", todays_date, ".xlsx"))

download.file(url = corelogic_url, destfile = latest_filepath)

file.copy(latest_filepath,
          archive_filepath,
          overwrite = TRUE)

read_corelogic <- function(path) {
  corelogic <- readxl::read_excel(path = path,
                                  skip = 3)
  
  corelogic <- corelogic %>%
    rename(date = Date, 
           sydney = starts_with("Sydney"),
           melbourne = starts_with("Mel"),
           brisbane = starts_with("Bris"),
           adelaide = starts_with("Adel"),
           perth = starts_with("Per"),
           agg = contains("Aggregate")) %>%
    mutate(date = as.Date(date),
           obs_date = max(date)) 
  
  corelogic  
}


compile_corelogic <- function(path_to_corelogic_files) {
  
  files <- list.files(path_to_corelogic_files,
                      full.names = TRUE)
  
  df <- purrr::map_dfr(.x = files, .f = read_corelogic)
  
  df <- df %>%
    group_by(date) %>%
    filter(obs_date == max(obs_date)) %>%
    ungroup() %>%
    select(-obs_date)
  
  df
}

corelogic <- compile_corelogic(here::here(corelogic_filepath, "archive"))

fst::write_fst(corelogic,
               here::here("data", "corelogic", "corelogic_daily.fst"),
               compress = 100)

readr::read_csv(here::here("last_updated.csv")) %>%
  bind_rows(tibble(data = "corelogic", date = Sys.time())) %>%
  group_by(data) %>%
  filter(date == max(date)) %>%
  arrange(date) %>%
  distinct() %>%
  write_csv(here::here("last_updated.csv"))

