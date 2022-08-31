#' Interpolate elevations from points along a centerline
#'
#' @details
#' The bulk of the processing time for this function involves calling
#' `gdal_grid` via [sf::gdal_utils()]. The results from this function call are
#' then written out as a TIFF file before being read back into the R session.
#'
#' You can choose to pass options to `gdal_grid`. However, passing any of
#' `-a`, `-txe`, `-tye`, `-tr`, `-outsize`, and `zfield` will cause an error.
#' Possible options to speed up processing include passing
#' `c("-co", "NUM_THREADS=ALL_CPUS")` in order to write the TIFF using multiple
#' threads, or `c("--config" "GDAL_CACHEMAX", "30%")` (or another value) to
#' increase cache utilization above the default 5%.
#'
#' @param points_on_line The output from [points_along_line()]: an sfc object
#' of points along the centerline, which will be used as data points for
#' interpolation.
#' @param gdal_options Optionally, a vector of options to pass to
#' `gdal_grid` via [sf::gdal_utils()]. See the full list of options online at
#' https://gdal.org/programs/gdal_grid.html. See Details.
#' @inheritParams make_rem
#'
#' @return A SpatRaster object (as created by [terra::rast()]), representing the
#' outputs of the interpolation process.
#'
#' @examplesIf rlang::is_interactive()
#' dem <- system.file("elevation.tiff", package = "rrrem")
#' centerline <- get_river_centerline(dem)
#' center_points <- points_along_line(centerline, n_points = n_points)
#' interpolated_raster <- calc_centerline_interpolation(
#'   center_points,
#'   dem,
#'   quiet = quiet
#' )
#'
#' @export
calc_centerline_interpolation <- function(
  points_on_line,
  dem,
  algorithm = "invdist:power=1",
  gdal_options = NULL,
  quiet = TRUE
) {
  if (!inherits(dem, "SpatRaster")) dem <- terra::rast(dem)
  if (sf::st_is_longlat(dem)) {
    rlang::abort(
      "'dem' must be in projected coordinates.",
      i = "Use terra::project() to reproject your DEM into a projected coordinate reference system."
    )
  }
  points_on_line <- sf::st_transform(points_on_line, sf::st_crs(dem))
  points_on_line <- terra::vect(points_on_line)
  point_elev <- terra::extract(
    dem,
    points_on_line,
    ID = FALSE,
    layer = 1,
    bind = TRUE
  )
  names(point_elev) <- "z"
  temp_vector <- tempfile(fileext = ".gpkg")
  temp_raster <- tempfile(fileext = ".tiff")
  suppressWarnings(
    terra::writeVector(
      point_elev,
      temp_vector
    )
  )

  res <- terra::res(dem)
  ext <- as.vector(terra::ext(dem))

  sf::gdal_utils(
    "grid",
    source = temp_vector,
    destination = temp_raster,
    quiet = quiet,
    options = c(
      "-tr", res,
      "-txe", ext[["xmin"]], ext[["xmax"]],
      "-tye", ext[["ymin"]], ext[["ymax"]],
      "-zfield", "z",
      "-a", algorithm,
      gdal_options
    )
  )

  interpolated_elevation <- terra::rast(temp_raster)

  elev_at_points <- terra::mask(
    dem,
    points_on_line
  )

  terra::cover(elev_at_points, interpolated_elevation)
}
