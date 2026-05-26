ddc_results_url <- function(id) {
  paste0("https://doubledisccourt.com/results/tournament.html?id=", id)
}

check_ddc_scraper_packages <- function() {
  required <- c("chromote", "rvest", "stringr", "dplyr")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing) > 0) {
    stop(
      "Install required packages before scraping: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

read_rendered_html <- function(url, delay_seconds = 5) {
  browser <- chromote::ChromoteSession$new()
  on.exit(browser$close(), add = TRUE)

  browser$Page$navigate(url)
  Sys.sleep(delay_seconds)

  html_doc <- browser$DOM$getDocument()
  browser$DOM$getOuterHTML(nodeId = html_doc$root$nodeId)[["outerHTML"]]
}

extract_ddc_event <- function(html, id) {
  page <- rvest::read_html(html)

  title_node <- rvest::html_node(page, "title")
  title_text <- if (length(title_node) > 0) {
    rvest::html_text(title_node)
  } else {
    NA_character_
  }

  year_match <- stringr::str_extract(title_text, "\\b(19|20)\\d{2}\\b")
  event_year <- ifelse(is.na(year_match), NA_integer_, as.integer(year_match))
  tournament_name <- stringr::str_trim(title_text)

  description_text <- rvest::html_text(rvest::html_nodes(page, "div.description"))
  level_match <- stringr::str_extract(description_text, "(?<=Tournament level: )([A-D])")
  tournament_level <- level_match[!is.na(level_match)][1]
  if (length(tournament_level) == 0) tournament_level <- NA_character_

  page_text <- rvest::html_text(page)
  format_type <- if (grepl("King of the Court|Monarch of the Court|Solo format", page_text, ignore.case = TRUE)) {
    "King of the Court"
  } else {
    "Standard Doubles"
  }

  location_text <- rvest::html_text(rvest::html_nodes(page, "div.location"), trim = TRUE)
  location_name <- stringr::str_trim(stringr::str_extract(location_text, "^[^,]+"))

  date_matches <- stringr::str_extract_all(location_text, "[A-Za-z]+\\s+\\d{1,2}")[[1]]
  event_start_date <- if (!is.na(event_year) && length(date_matches) >= 1) {
    as.Date(paste(date_matches[1], event_year), format = "%B %d %Y")
  } else {
    as.Date(NA)
  }
  event_end_date <- if (!is.na(event_year) && length(date_matches) >= 2) {
    as.Date(paste(date_matches[2], event_year), format = "%B %d %Y")
  } else {
    event_start_date
  }

  headers <- rvest::html_nodes(page, "div.header")
  result_lists <- rvest::html_nodes(page, "ul.form")

  if (length(headers) == 0 || length(headers) != length(result_lists)) {
    return(NULL)
  }

  all_divisions <- vector("list", length(headers))

  for (i in seq_along(headers)) {
    div_name <- rvest::html_text(headers[[i]], trim = TRUE)
    teams <- rvest::html_nodes(result_lists[[i]], "li")
    if (length(teams) < 2) next

    team_data <- lapply(teams[-1], function(team) {
      cells <- rvest::html_nodes(team, "div.dataCell")
      if (length(cells) < 2) return(NULL)

      place <- rvest::html_text(cells[[1]], trim = TRUE)
      names <- rvest::html_text(rvest::html_nodes(cells[[2]], "a"), trim = TRUE)
      if (length(names) == 0) return(NULL)

      data.frame(
        Year = event_year,
        TournamentName = tournament_name,
        Location = location_name,
        EventStartDate = event_start_date,
        EventEndDate = event_end_date,
        Level = tournament_level,
        Format = format_type,
        Division = div_name,
        Place = place,
        Player1 = names[1],
        Player2 = ifelse(length(names) >= 2, names[2], NA_character_),
        TournamentID = id,
        stringsAsFactors = FALSE
      )
    })

    all_divisions[[i]] <- dplyr::bind_rows(team_data)
  }

  event <- dplyr::bind_rows(all_divisions)
  if (nrow(event) == 0) return(NULL)
  event
}

scrape_ddc_event <- function(id, delay_seconds = 5) {
  check_ddc_scraper_packages()
  message("Scraping tournament ID ", id)

  html <- read_rendered_html(ddc_results_url(id), delay_seconds = delay_seconds)
  extract_ddc_event(html, id)
}

scrape_ddc_events <- function(ids, delay_seconds = 5) {
  events <- lapply(ids, function(id) {
    tryCatch(
      scrape_ddc_event(id, delay_seconds = delay_seconds),
      error = function(error) {
        message("Skipping tournament ID ", id, ": ", conditionMessage(error))
        NULL
      }
    )
  })

  dplyr::bind_rows(events)
}
