library(ncdf4)
library(dplyr)
library(lubridate)
library(suncalc)
library(purrr)

analyze_ddc_file <- function(file_path, lat, lon) {
  nc <- nc_open(file_path)
  
  time_raw <- ncvar_get(nc, "valid_time")
  timestamps <- as.POSIXct(time_raw, origin = "1970-01-01", tz = "UTC")
  
  temp_c <- ncvar_get(nc, "t2m") - 273.15
  u <- ncvar_get(nc, "u10")
  v <- ncvar_get(nc, "v10")
  wind_mps <- sqrt(u^2 + v^2)
  
  nc_close(nc)
  
  df <- tibble(datetime = timestamps, temp_c, wind_mps) %>%
    mutate(date = as.Date(datetime),
           month = month(date, label = TRUE, abbr = TRUE))  # Add month
  
  sun <- getSunlightTimes(date = unique(df$date), lat = lat, lon = lon)
  
  df_joined <- df %>%
    left_join(sun, by = "date") %>%
    filter(datetime >= sunrise & datetime <= sunset)
  
  df_ddc <- df_joined %>%
    filter(temp_c > 10, wind_mps < 2.57)  # < 5 knots
  
  tibble(
    month = df_joined$month[1],
    n_total_daylight = nrow(df_joined),
    n_ddc_optimal = nrow(df_ddc)
  )
}


# === Loop through monthly files ===

analyze_ddc_year <- function(folder, lat, lon) {
  files <- list.files(folder, pattern = "^data_2020_\\d{2}\\.nc$", full.names = TRUE)
  summary_df <- map_dfr(files, analyze_ddc_file, lat = lat, lon = lon)
  
  summary_monthly <- summary_df %>%
    group_by(month) %>%
    summarise(
      n_total_daylight = sum(n_total_daylight),
      n_ddc_optimal = sum(n_ddc_optimal),
      frac_ddc_optimal = n_ddc_optimal / n_total_daylight
    ) %>%
    arrange(month)
  
  print(summary_monthly)
  return(summary_monthly)
}

analyze_ddc_all_years <- function(folder, lat, lon, years = 2020:2022) {
  # Build file pattern for all years
  pattern <- paste0("^data_(", paste(years, collapse = "|"), ")_\\d{2}\\.nc$")
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  
  # Analyze each file and return raw daylight and DDC-optimal counts with month label
  summary_df <- purrr::map_dfr(files, function(file) {
    result <- analyze_ddc_file(file, lat, lon)
    return(result)
  })
  
  # Ensure month is a factor with correct order
  summary_df$month <- factor(summary_df$month, levels = month.abb)
  
  # Aggregate over all years by month only
  summary_monthly <- summary_df %>%
    group_by(month) %>%
    summarise(
      n_total_daylight = sum(n_total_daylight),
      n_ddc_optimal = sum(n_ddc_optimal),
      frac_ddc_optimal = n_ddc_optimal / n_total_daylight,
      .groups = "drop"
    ) %>%
    arrange(match(month, month.abb))
  
  print(summary_monthly)
  return(summary_monthly)
}


# City	Latitude	Longitude
# San Jose, CA	37.3382	-121.8863
# Milwaukee, WI	43.0389	-87.9065
# Washington, DC	38.9072	-77.0369
# Tallahassee, FL	30.4383	-84.2807
# Scottsdale, AZ	33.4942	-111.9261
# Sofia, BG  42.6975 23.3242
# Fredericksburg, VA 38.3032 -77.4605

# === Example ===
Optimal_DDC <- analyze_ddc_year(
  folder = "data/output/tallahassee", 
  lat = 30.4383, 
  lon = -84.2807)

Optimal_DDC <- analyze_ddc_all_years(
  folder = "data/output/tallahassee",
  lat = 30.4383,
  lon = -84.2807,
  years = 2020:2022)

