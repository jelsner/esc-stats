# download_era5_hourly_by_month.py

import cdsapi
import sys
import os

# Get command-line arguments
lat = float(sys.argv[1])
lon = float(sys.argv[2])
year = sys.argv[3]
output_dir = sys.argv[4]

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

c = cdsapi.Client()

for month in range(1, 13):
    month_str = f"{month:02d}"
    outfile = os.path.join(output_dir, f"data_{year}_{month_str}.nc")

    print(f"Requesting data for {year}-{month_str}...")

    c.retrieve(
        'reanalysis-era5-single-levels',
        {
            'variable': [
                '2m_temperature',
                '10m_u_component_of_wind',
                '10m_v_component_of_wind'
            ],
            'product_type': 'reanalysis',
            'year': year,
            'month': [month_str],
            'day': [f'{d:02d}' for d in range(1, 32)],
            'time': [f'{h:02d}:00' for h in range(24)],
            'area': [lat + 0.05, lon - 0.05, lat - 0.05, lon + 0.05],
            'format': 'netcdf',
        },
        outfile
    )
