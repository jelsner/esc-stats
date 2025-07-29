library(reticulate)
use_python("/Users/jameselsner/miniforge3/envs/era5arm/bin/python", required = TRUE)
py_config()

download_era5_city <- function(lat, lon, year = 2020, outfile = "era5_hourly.nc") {
  cmd <- glue::glue("python3 download_era5_hourly.py {lat} {lon} {year} {outfile}")
  system(cmd)
}

startTime <- Sys.time()
#download_era5_city(lat = 37.3382, lon = -121.8863, year = 2020, outfile = "data/output/sanjose_2020.nc")
#download_era5_city(lat = 30.4383, lon = -84.2807, year = 2020, outfile = "data/output/tallahassee_2020.nc")
download_era5_city(lat = 43.0389, lon = -87.9065, year = 2020, outfile = "data/output/milwaukee_2020.nc")
Sys.time() - startTime

# 2-3 minutes for a month of hourly data

#
#City	Latitude	Longitude
#San Jose, CA	37.3382	-121.8863
#Milwaukee, WI	43.0389	-87.9065
#Washington, DC	38.9072	-77.0369
#Tallahassee, FL	30.4383	-84.2807
#Scottsdale, AZ	33.4942	-111.9261
