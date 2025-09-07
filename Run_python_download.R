library(reticulate)

# Set Python environment
use_python("/Users/jameselsner/miniforge3/envs/era5arm/bin/python", required = TRUE)

# Function to run the download script using reticulate
download_era5_city_year <- function(lat, lon, year, city_name) {
  output_dir <- file.path("data/output", city_name)
  py_run_string(glue::glue("
import sys
sys.argv = ['', '{lat}', '{lon}', '{year}', '{output_dir}']
exec(open('download_era5_hourly_by_month.py').read())
"))
}

# Example
startTime <- Sys.time()
download_era5_city_year(lat = 30.4383, lon = -84.2807, year = 2023, city_name = "tallahassee")
Sys.time() - startTime

# ~30 minutes for 12 months

#30.4383	-84.2807