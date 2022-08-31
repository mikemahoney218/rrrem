#' Interpolate elevations from points along a centerline
#'
#' @param points_on_line The output from [points_along_line()]: an sfc object
#' of points along the centerline, which will be used as data points for
#' interpolation.
#' @param algorithm A string to control the interpolation algorithm.
#' See the gdal_grid documentation at <https://gdal.org/programs/gdal_grid.html>
#' for the available algorithms and customization options.
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
calc_centerline_interpolation <- function(points_on_line, dem, algorithm = "invdist:power=1", quiet = TRUE) {
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
      "-a", algorithm
    )
  )

  interpolated_elevation <- terra::rast(temp_raster)

  elev_at_points <- terra::mask(
    dem,
    points_on_line
  )

  terra::cover(elev_at_points, interpolated_elevation)
}
