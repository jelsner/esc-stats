import cdsapi
import sys

# Read input arguments from R (lat, lon, year, output_file)
lat = float(sys.argv[1])
lon = float(sys.argv[2])
year = sys.argv[3]
outfile = sys.argv[4]

c = cdsapi.Client()

c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'variable': [
            '2m_temperature',
            '10m_u_component_of_wind',
            '10m_v_component_of_wind'
        ],
        'product_type': 'reanalysis',
        'year': '2020',
        'month': ['03'],
        'day': [f'{d:02d}' for d in range(1, 32)],
        'time': [f'{h:02d}:00' for h in range(24)],
        'area': [lat + 0.05, lon - 0.05, lat - 0.05, lon + 0.05],
        'format': 'netcdf',
    },
    outfile
)


