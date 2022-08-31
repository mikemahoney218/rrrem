#' Create a set of number of evenly spaced points along a line geometry
#'
#' @param line The line to create points along. Must be an sfc object (as
#' created by [sf::st_sfc()]) with LINESTRING geometry.
#' @param n_points The number of points along the line to create.
#'
#' @return An sfc object with POINT geometry of length `n_points`.
#'
#' @examplesIf rlang::is_interactive()
#' dem <- system.file("elevation.tiff", package = "rrrem")
#' centerline <- get_river_centerline(dem)
#' center_points <- points_along_line(centerline, n_points = n_points)
#'
#' @export
points_along_line <- function(line, n_points = 1000) {
  if (sf::st_is_longlat(line)) {
    rlang::abort(
      "'line' must be in projected coordinates.",
      i = "Use sf::st_transform() to reproject your river into a projected coordinate reference system."
    )
  }

  sf::st_cast(
    sf::st_line_sample(line, n_points),
    "POINT"
  )

}
