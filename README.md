# esc-stats
Escape!! frisbee game stats

## Update DDC Tournament Data

The reusable scraper lives in `R/ddc_scraper.R`. Run this command whenever new tournaments have been added to doubledisccourt.com:

```sh
Rscript scripts/update_ddc_tournament_data.R
```

By default, the updater reads `data/output/ddc_full_tournament_data_auto.csv`, starts at the next tournament ID after the highest existing `TournamentID`, and keeps checking IDs until it finds 10 consecutive empty pages. It writes:

- `data/output/ddc_full_tournament_data_auto.csv`
- `data/output/ddc_team_data.csv`

Useful variants:

```sh
# Rebuild everything from tournament ID 1.
Rscript scripts/update_ddc_tournament_data.R --full-refresh

# Scrape a known range.
Rscript scripts/update_ddc_tournament_data.R --start-id=625 --end-id=630

# Scrape up to the latest tournament ID shown on the website.
Rscript scripts/update_ddc_tournament_data.R --latest-id=636

# Wait longer for rendered pages if the website is slow.
Rscript scripts/update_ddc_tournament_data.R --delay=8
```
