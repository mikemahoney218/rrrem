#' Get the "centerline" of the longest river along the DEM
#'
#' @inheritParams make_rem
#'
#' @return An sfc object (as created by [sf::st_sfc()]), with LINESTRING
#' geometry, representing the center of the river within the DEM area.
#'
#' @examplesIf rlang::is_interactive()
#' dem <- system.file("elevation.tiff", package = "rrrem")
#' centerline <- get_river_centerline(dem)
#'
#' @export
get_river_centerline <- function(dem, quiet = TRUE) {
  if (!inherits(dem, "SpatRaster")) dem <- terra::rast(dem)
  if (sf::st_is_longlat(dem)) {
    rlang::abort(
      "'dem' must be in projected coordinates.",
      i = "Use terra::project() to reproject your DEM into a projected coordinate reference system."
    )
  }
  bbox <- sf::st_as_sfc(
    sf::st_bbox(dem),
    crs = sf::st_crs(dem)
  )

  query <- osmdata::opq(bbox = sf::st_transform(bbox, 4326))
  query <- osmdata::add_osm_feature(
    query,
    "waterway",
    c('river', 'stream', 'tidal channel')
  )
  rivers <- tryCatch(
    osmdata::osmdata_sf(query, quiet = quiet)$osm_lines,
    error = function(e) {
      rlang::abort(
        c(
          "An error was encountered while trying to download the river centerline.",
          i = "For more information, set `quiet = FALSE`."
        ),
        call = rlang::caller_env(2)
      )
    }
  )
  if (nrow(rivers) == 0) {
    rlang::abort(
      c(
        "No rivers found within the DEM domain.",
        i = "Ensure the target river is on OpenStreetMap and contains 'waterway' and 'name' tags.",
        i = "https://www.openstreetmap.org/edit"
      )
    )
  }
  rivers <- sf::st_transform(rivers, sf::st_crs(dem))

  rivers <- rivers[!is.na(rivers$name), ]
  if (nrow(rivers) == 0) {
    rlang::abort(
      c(
        "Found (at least one) river, but it does not have a listed name.",
        i = "Ensure the target river segment(s) contain 'name' tags.",
        i = "https://www.openstreetmap.org/edit"
      )
    )
  }

  rivers <- sf::st_geometry(rivers)
  rivers <- sf::st_crop(rivers, sf::st_bbox(bbox))

  sf::st_cast(rivers[which.max(sf::st_length(rivers))], "LINESTRING")
}
