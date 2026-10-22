#' The full calibration curve between two GBR monitoring tools
#'
#' @description
#' Returns the whole calibration curve for a pair of tools, rather than
#' predictions for particular observations: the expected value of the `to`
#' tool over a grid of values of the `from` tool, with confidence and
#' prediction intervals. The result is a data.frame that can be passed
#' straight to a plotting function (it also has its own [plot()] method), and
#' is useful for looking at the shape of a calibration, comparing pairs or
#' levels, or overlaying your own observations.
#'
#' It uses the same models, tool names and defaults as [GBR_calibrate()].
#'
#' @inheritParams GBR_calibrate
#' @param x The values of the `from` predictor at which to evaluate the curve,
#'   on the scale described in the `xlab` attribute of the result (a
#'   proportion for coral cover, a density for COTS, and so on; see Details).
#'   If `NULL` (default), `nPoints` values are spread over the range of the
#'   predictor in the BR-04 data: evenly for coral cover and `eDNA_prop`, and
#'   closer together at the low end (even on the square-root scale) for COTS
#'   densities and `eDNA_conc`, where the curve changes fastest.
#' @param nPoints The number of points in the default grid for `x`.
#'
#' @details
#' `x` is the predictor exactly as the model was fitted, which is what
#' [GBR_calibrate()] works out from your raw observations:
#' \describe{
#'   \item{coral_manta, coral_surface, coral_deep}{Hard coral cover, a
#'     proportion between 0 and 1.}
#'   \item{Manta}{The combined density: (COTS seen + number of tows with
#'     scars) per tow.}
#'   \item{ReefScan_surface, ReefScan_deep}{COTS per tow.}
#'   \item{eDNA_conc}{Total concentration per PCR assay.}
#'   \item{eDNA_prop}{The proportion of positive samples.}
#' }
#' The scale of the prediction is described in the `ylab` attribute. As in
#' [GBR_calibrate()], COTS counts are expected counts over `to.nTows` tows
#' (or `to.effort` assays), presence is a probability or a proportion of
#' `to.nTows` tows (or `to.effort` samples), and the effort defaults to
#' typical values from the BR-04 data. Predictions are for the average reef.
#'
#' The column `observed` is `TRUE` where `x` lies inside the range of that
#' predictor in the BR-04 data at this level, and `FALSE` where the curve is an
#' extrapolation. The prediction intervals are simulated, so call [set.seed()]
#' first for reproducible results.
#'
#' @return A data.frame of class `"GBR_curve"` with columns `x`, `mean`,
#'   `lowerCI`, `upperCI`, `lowerPI`, `upperPI` and `observed`. Attributes
#'   record the model (`model`), the tools and level, axis labels (`xlab`,
#'   `ylab`) and the effort assumed (`effort`).
#'
#' @examples
#' set.seed(8153)
#'
#' # How manta tow coral cover relates to ReefScan Surface cover, by reef
#' curve <- GBR_curve("coral_surface", "coral_manta", level = "reef")
#' head(curve)
#' plot(curve)
#'
#' # The probability that a manta tow finds COTS as ReefScan Surface density rises
#' curve <- GBR_curve("ReefScan_surface", "Manta", level = "tow", to.type = "presence")
#' plot(curve)
#'
#' # Your own grid of predictor values
#' GBR_curve("eDNA_prop", "Manta", level = "reef", x = c(0, 0.1, 0.25, 0.5))
#' @export
GBR_curve <- function(from, to, level = c("reef", "cull_site", "tow"),
                      x = NULL, nPoints = 100,
                      to.effort = NULL, to.nTows = NULL,
                      to.type = c("presence", "count"), intLevel = 0.95) {
  level <- match.arg(level)
  to.type <- match.arg(to.type)
  if (missing(from) || missing(to)) stop("Both `from` and `to` must be specified.", call. = FALSE)
  if (!is.numeric(intLevel) || length(intLevel) != 1L || intLevel < 0.5 || intLevel >= 1) {
    stop("intLevel must be a single number between 0.5 and 1.", call. = FALSE)
  }
  if (!is.null(to.effort) && length(to.effort) != 1L) {
    stop("Multiple values of to.effort supplied. Please provide a single scalar.", call. = FALSE)
  }
  if (!is.null(to.nTows) && length(to.nTows) != 1L) {
    stop("Multiple values of to.nTows supplied. Please provide a single scalar.", call. = FALSE)
  }
  if (!is.numeric(nPoints) || length(nPoints) != 1L || nPoints < 2) {
    stop("nPoints must be a single number, at least 2.", call. = FALSE)
  }

  from_key <- normaliseTool(from, "from")
  to_key <- normaliseTool(to, "to")
  if (isCoral(from_key) != isCoral(to_key)) {
    stop("Predictions can only be made within COTS measurements or within coral measurements, ",
         "not between the two.", call. = FALSE)
  }
  if (from_key == to_key) stop("`from` and `to` are the same tool.", call. = FALSE)

  model <- findModel(from_key, to_key, level, to.type)
  if (model$exploratory) {
    message("Note: the model used (", model$model_name, ") is based on very few reefs and is exploratory.")
  }
  rng <- observedRange(from_key, level)

  if (is.null(x)) {
    if (anyNA(rng)) stop("No default grid is available for this predictor; please supply `x`.", call. = FALSE)
    x <- if (isCoral(from_key) || from_key == "edna_prop") {
      seq(rng[1], rng[2], length.out = nPoints)
    } else {
      seq(0, sqrt(rng[2]), length.out = nPoints)^2
    }
  } else {
    if (!is.numeric(x) || anyNA(x) || any(x < 0)) stop("`x` must be non-negative numbers.", call. = FALSE)
    if ((isCoral(from_key) || from_key == "edna_prop") && any(x > 1)) {
      stop("For this predictor `x` must be a proportion between 0 and 1.", call. = FALSE)
    }
    x <- sort(x)
  }

  eff <- resolveToEffort(model, to_key, level, to.effort, to.nTows)
  post <- loadPosterior(model$model_name)
  pred <- predictModel(model, post, x = x, effort = eff$effort, size = eff$size, intLevel = intLevel)

  out <- data.frame(
    x = x,
    mean = pred[, "mean"], lowerCI = pred[, "lowerCI"], upperCI = pred[, "upperCI"],
    lowerPI = pred[, "lowerPI"], upperPI = pred[, "upperPI"],
    observed = if (anyNA(rng)) NA else x >= rng[1] - 1e-12 & x <= rng[2] + 1e-12
  )
  attr(out, "model") <- model$model_name
  attr(out, "from") <- displayName[[from_key]]
  attr(out, "to") <- toLabel(to_key, model, to.type)
  attr(out, "level") <- level
  attr(out, "intLevel") <- intLevel
  attr(out, "effort") <- if (is.na(eff$column)) NULL else stats::setNames(eff$value, eff$column)
  attr(out, "xlab") <- xLabel(from_key, level)
  attr(out, "ylab") <- yLabel(to_key, model, eff)
  class(out) <- c("GBR_curve", "data.frame")
  out
}

#' Plot a calibration curve
#'
#' Base-graphics plot of the output of [GBR_curve()]: the mean curve, the
#' confidence band (darker) and the prediction band (lighter). Where the curve
#' is an extrapolation beyond the range of the predictor in the BR-04 data, the
#' mean line is dashed.
#'
#' @param x A `"GBR_curve"` object.
#' @param ... Further arguments passed to [plot()], e.g. `main`, `xlab`,
#'   `ylab`, `xlim`, `ylim`.
#' @return `x`, invisibly.
#' @export
plot.GBR_curve <- function(x, ...) {
  args <- list(...)
  if (is.null(args$xlab)) args$xlab <- attr(x, "xlab")
  if (is.null(args$ylab)) args$ylab <- attr(x, "ylab")
  if (is.null(args$main)) args$main <- paste(attr(x, "from"), "->", attr(x, "to"), paste0("(", attr(x, "level"), ")"))
  if (is.null(args$ylim)) args$ylim <- range(x$lowerPI, x$upperPI, na.rm = TRUE)
  if (is.null(args$xlim)) args$xlim <- range(x$x)
  if (is.null(args$cex.main)) args$cex.main <- 1
  if (is.null(args$cex.lab)) args$cex.lab <- 0.9
  do.call(plot, c(list(x = range(x$x), y = args$ylim, type = "n"), args))

  band <- function(lo, hi, col) {
    graphics::polygon(c(x$x, rev(x$x)), c(lo, rev(hi)), col = col, border = NA)
  }
  band(x$lowerPI, x$upperPI, grDevices::adjustcolor("grey60", 0.35))
  band(x$lowerCI, x$upperCI, grDevices::adjustcolor("steelblue", 0.5))

  obs <- x$observed
  if (is.null(obs) || anyNA(obs)) obs <- rep(TRUE, nrow(x))
  graphics::lines(x$x[obs], x$mean[obs], lwd = 2)
  if (any(!obs)) {
    # Draw the extrapolated part dashed, joined to the solid part
    ext <- !obs | c(FALSE, !obs[-length(obs)]) | c(!obs[-1], FALSE)
    graphics::lines(x$x[ext], x$mean[ext], lwd = 2, lty = 2)
  }
  invisible(x)
}
