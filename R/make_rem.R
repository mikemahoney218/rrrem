#' Make a Relative Elevation Model (REM)
#'
#' This function creates a relative elevation model, or REM, based off an
#' input digital elevation model (DEM) and the trajectory of a river. Simple
#' inverse distance weighting is used to calculate "base" elevations at all
#' pixels within the DEM, which are then subtracted to produce the output REM.
#'
#' @param dem Either a SpatRaster (created via [terra::rast()]) or an object
#' that [terra::rast()] can read to create a SpatRaster.
#' @param centerline Optionally, an sfc object (as created via [sf::sfc()])
#' representing the center of the target river to base the relative elevation
#' model on. If `NULL`, the default, the longest river in the bounding box with
#' a name in OpenStreetMap will be used instead.
#' @param n_points The number of sample points along the river to base
#' interpolation on. More points will make interpolation take longer.
#' @param algorithm A string to control the interpolation algorithm.
#' See the gdal_grid documentation at <https://gdal.org/programs/gdal_grid.html>
#' for the available algorithms and customization options.
#' @param quiet Boolean: should execution proceed "quietly", without messages
#' (`TRUE`) or should progress updates be posted during centerline download and
#' interpolation (`FALSE`)?
#'
#' @return A SpatRaster object (as created by [terra::rast()]), representing the
#' difference between elevations in `dem` and the interpolated elevation
#'
#' @examplesIf rlang::is_interactive()
#' make_rem(system.file("elevation.tiff", package = "rrrem"))
#'
#' @export
make_rem <- function(dem, centerline = NULL, n_points = 1000, algorithm = "invdist:power=1", quiet = TRUE) {
  if (!inherits(dem, "SpatRaster")) dem <- terra::rast(dem)
  if (sf::st_is_longlat(dem)) {
    rlang::abort(
      "'dem' must be in projected coordinates.",
      i = "Use terra::project() to reproject your DEM into a projected coordinate reference system."
    )
  }

  if (is.null(centerline)) {
    centerline <- get_river_centerline(dem, quiet = quiet)
  }

  center_points <- points_along_line(centerline, n_points = n_points)

  interpolated_raster <- calc_centerline_interpolation(
    center_points,
    dem,
    algorithm = algorithm,
    quiet = quiet
  )

  dem - interpolated_raster
}
