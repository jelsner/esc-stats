#!/usr/bin/env Rscript

source("R/ddc_scraper.R")

parse_cli_args <- function(args) {
  values <- list(
    output = "data/output/ddc_full_tournament_data_auto.csv",
    team_output = "data/output/ddc_team_data.csv",
    start_id = NULL,
    end_id = NULL,
    max_empty = 10,
    delay = 5,
    full_refresh = FALSE,
    write_team_output = TRUE
  )

  for (arg in args) {
    if (arg == "--full-refresh") {
      values$full_refresh <- TRUE
    } else if (arg == "--no-team-output") {
      values$write_team_output <- FALSE
    } else if (grepl("^--output=", arg)) {
      values$output <- sub("^--output=", "", arg)
    } else if (grepl("^--team-output=", arg)) {
      values$team_output <- sub("^--team-output=", "", arg)
    } else if (grepl("^--start-id=", arg)) {
      values$start_id <- as.integer(sub("^--start-id=", "", arg))
    } else if (grepl("^--end-id=", arg)) {
      values$end_id <- as.integer(sub("^--end-id=", "", arg))
    } else if (grepl("^--latest-id=", arg)) {
      values$end_id <- as.integer(sub("^--latest-id=", "", arg))
    } else if (grepl("^--max-empty=", arg)) {
      values$max_empty <- as.integer(sub("^--max-empty=", "", arg))
    } else if (grepl("^--delay=", arg)) {
      values$delay <- as.numeric(sub("^--delay=", "", arg))
    } else if (arg %in% c("--help", "-h")) {
      print_usage()
      quit(status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  values
}

print_usage <- function() {
  cat(
    "Usage: Rscript scripts/update_ddc_tournament_data.R [options]\n\n",
    "Defaults append new tournaments after the highest TournamentID in the output CSV.\n\n",
    "Options:\n",
    "  --full-refresh          Rebuild output from tournament ID 1.\n",
    "  --start-id=N            First tournament ID to scrape.\n",
    "  --end-id=N              Last tournament ID to scrape. If omitted, stop after max-empty misses.\n",
    "  --latest-id=N           Alias for --end-id=N.\n",
    "  --max-empty=N           Stop after N consecutive empty IDs when end-id is omitted. Default: 10.\n",
    "  --delay=N               Seconds to wait for each rendered page. Default: 5.\n",
    "  --output=PATH           Full tournament CSV path. Default: data/output/ddc_full_tournament_data_auto.csv.\n",
    "  --team-output=PATH      Team-only CSV path. Default: data/output/ddc_team_data.csv.\n",
    "  --no-team-output        Do not write the team-only CSV.\n",
    "  --help                  Show this help.\n",
    sep = ""
  )
}

read_existing_data <- function(path) {
  if (!file.exists(path)) return(NULL)
  normalize_tournament_data(read.csv(path, stringsAsFactors = FALSE))
}

next_start_id <- function(existing, full_refresh) {
  if (full_refresh || is.null(existing) || nrow(existing) == 0 || !"TournamentID" %in% names(existing)) {
    return(1L)
  }

  max(existing$TournamentID, na.rm = TRUE) + 1L
}

scrape_until_empty <- function(start_id, max_empty, delay_seconds) {
  all_tournaments <- list()
  consecutive_empty <- 0L
  current_id <- start_id

  while (consecutive_empty < max_empty) {
    event <- tryCatch(
      scrape_ddc_event(current_id, delay_seconds = delay_seconds),
      error = function(error) {
        message("No data for tournament ID ", current_id, ": ", conditionMessage(error))
        NULL
      }
    )

    if (!is.null(event) && nrow(event) > 0) {
      all_tournaments[[length(all_tournaments) + 1L]] <- event
      consecutive_empty <- 0L
    } else {
      consecutive_empty <- consecutive_empty + 1L
    }

    current_id <- current_id + 1L
  }

  dplyr::bind_rows(all_tournaments)
}

format_date_column <- function(x) {
  if (inherits(x, "Date")) return(as.character(x))
  if (is.numeric(x)) return(as.character(as.Date(x, origin = "1970-01-01")))

  x <- as.character(x)
  parsed <- as.Date(x)
  ifelse(is.na(parsed), x, as.character(parsed))
}

normalize_tournament_data <- function(data) {
  if (is.null(data) || nrow(data) == 0) return(data)

  character_cols <- c(
    "TournamentName",
    "Location",
    "EventStartDate",
    "EventEndDate",
    "Level",
    "Format",
    "Division",
    "Place",
    "Player1",
    "Player2"
  )

  for (col in intersect(character_cols, names(data))) {
    data[[col]] <- as.character(data[[col]])
  }

  for (col in intersect(c("EventStartDate", "EventEndDate"), names(data))) {
    data[[col]] <- format_date_column(data[[col]])
  }

  for (col in intersect(c("Year", "TournamentID"), names(data))) {
    data[[col]] <- as.integer(data[[col]])
  }

  data
}

dedupe_tournament_rows <- function(data) {
  key_cols <- c("TournamentID", "Division", "Place", "Player1", "Player2")
  if (!all(key_cols %in% names(data))) return(dplyr::distinct(data))

  data |>
    dplyr::arrange(
      .data$TournamentID,
      .data$Division,
      .data$Place,
      .data$Player1,
      .data$Player2
    ) |>
    dplyr::distinct(dplyr::across(dplyr::all_of(key_cols)), .keep_all = TRUE)
}

write_tournament_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(data, path, row.names = FALSE)
}

make_team_data <- function(data) {
  cols <- c("Year", "Division", "Place", "Player1", "Player2", "TournamentID")
  missing <- setdiff(cols, names(data))
  if (length(missing) > 0) {
    stop("Cannot write team output. Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  data[, cols]
}

main <- function() {
  args <- parse_cli_args(commandArgs(trailingOnly = TRUE))
  existing <- read_existing_data(args$output)
  start_id <- if (is.null(args$start_id)) next_start_id(existing, args$full_refresh) else args$start_id

  if (!is.null(args$end_id) && args$end_id < start_id) {
    stop("--end-id must be greater than or equal to --start-id", call. = FALSE)
  }

  new_data <- if (!is.null(args$end_id)) {
    scrape_ddc_events(seq.int(start_id, args$end_id), delay_seconds = args$delay)
  } else {
    scrape_until_empty(start_id, args$max_empty, delay_seconds = args$delay)
  }

  new_data <- normalize_tournament_data(new_data)

  if (is.null(new_data) || nrow(new_data) == 0) {
    message("No new tournament rows found.")
    return(invisible(NULL))
  }

  combined <- if (args$full_refresh || is.null(existing)) {
    new_data
  } else {
    dplyr::bind_rows(existing, new_data)
  }

  combined <- dedupe_tournament_rows(normalize_tournament_data(combined))
  write_tournament_csv(combined, args$output)
  message("Wrote ", nrow(combined), " rows to ", args$output)

  if (args$write_team_output) {
    team_data <- make_team_data(combined)
    write_tournament_csv(team_data, args$team_output)
    message("Wrote ", nrow(team_data), " rows to ", args$team_output)
  }
}

called_as_script <- any(grepl("update_ddc_tournament_data\\.R$", commandArgs(trailingOnly = FALSE)))

if (called_as_script) {
  main()
}
