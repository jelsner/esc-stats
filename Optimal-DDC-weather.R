library(ncdf4)
library(raster)
library(lubridate)
library(dplyr)
library(suncalc)

# Open NetCDF file
nc <- nc_open("data/output/tallahassee_2020.nc")

# Inspect variable names
names(nc$var)  # should include "t2m", "u10", "v10"

# Read in the time vector
time_raw <- ncvar_get(nc, "valid_time")
timestamps <- as.POSIXct(time_raw, origin = "1970-01-01", tz = "UTC")

# Read point data (1D vectors)
temp_c <- ncvar_get(nc, "t2m") - 273.15
u <- ncvar_get(nc, "u10")
v <- ncvar_get(nc, "v10")
wind_mps <- sqrt(u^2 + v^2)

# Build time series data frame
df <- tibble(datetime = timestamps, temp_c, wind_mps) %>%
  mutate(date = as.Date(datetime))

# Get sunrise/sunset for San Jose
sun <- getSunlightTimes(date = unique(df$date), lat = 37.3382, lon = -121.8863)

# Join and filter for DDC-ideal hours
df_ddc <- df %>%
  left_join(sun, by = "date") %>%
  filter(datetime >= sunrise & datetime <= sunset,
         temp_c > 10, wind_mps < 5)

# Output result
cat("Tallahassee — DDC-ideal daylight hours during March 2020:", nrow(df_ddc), "\n")

