library(ncdf4)
library(dplyr)
library(lubridate)
library(purrr)
library(ggplot2)
library(suncalc)

# Extracts data and computes hours since sunrise
analyze_ddc_file <- function(file_path, lat, lon) {
  nc <- nc_open(file_path)
  
  time_raw <- ncvar_get(nc, "valid_time")
  timestamps_utc <- as.POSIXct(time_raw, origin = "1970-01-01", tz = "UTC")
  timestamps_local <- with_tz(timestamps_utc, tzone = "America/New_York")  # adjust as needed
  
  temp_c <- ncvar_get(nc, "t2m") - 273.15
  u <- ncvar_get(nc, "u10")
  v <- ncvar_get(nc, "v10")
  wind_mps <- sqrt(u^2 + v^2)
  
  nc_close(nc)
  
  df <- tibble(datetime_utc = timestamps_utc,
               datetime_local = timestamps_local,
               date = as.Date(timestamps_local),
               temp_c, wind_mps)
  
  sun <- getSunlightTimes(date = unique(df$date), lat = lat, lon = lon, keep = c("sunrise", "sunset"))
  
  df <- df %>%
    left_join(sun, by = "date") %>%
    filter(datetime_local >= sunrise & datetime_local <= sunset) %>%
    mutate(
      hrs_since_sunrise = as.numeric(difftime(datetime_local, sunrise, units = "hours")),
      hour_bin = floor(hrs_since_sunrise) + 1,  # Bin 0–1hr as 1, 1–2hr as 2, etc.
      ddc_ok = temp_c > 10 & wind_mps < 5
    )
  
  return(df)
}

# Accumulate data across months and plot
analyze_ddc_by_sunrise <- function(folder, lat, lon, city) {
  files <- list.files(folder, pattern = "^data_2020_\\d{2}\\.nc$", full.names = TRUE)
  df_all <- map_dfr(files, analyze_ddc_file, lat = lat, lon = lon)
  
  df_summary <- df_all %>%
    group_by(hour_bin) %>%
    summarise(
      total = n(),
      optimal = sum(ddc_ok),
      pct_optimal = 100 * optimal / total
    ) %>%
    ungroup()
  
  ggplot(df_summary, aes(x = hour_bin, y = pct_optimal)) +
    geom_line(size = 1.2) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = df_summary$hour_bin) +
    labs(
      title = glue::glue("{city} – % of DDC-Optimal Hours by Hour Since Sunrise (2020)"),
      x = "Hours After Sunrise",
      y = "Percent of Daylight Hours DDC-Optimal"
    ) +
    theme_minimal()
}

analyze_ddc_by_sunrise("data/output/milwaukee", lat = 43.0389, lon = -87.9065, city = "Milwaukee")

