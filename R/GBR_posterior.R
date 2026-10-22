#' The fitted posterior draws behind a calibration model
#'
#' @description
#' Returns the posterior draws of the model that [GBR_calibrate()] and
#' [GBR_curve()] use for a pair of tools, so you can work with them directly:
#' summarise or plot the parameters, compute your own predictions, or compare
#' models. The models were fitted by Bayesian GLMMs, but no Bayesian software
#' is needed to use the draws; they are an ordinary data.frame (one row per
#' draw, one column per parameter).
#'
#' @inheritParams GBR_calibrate
#' @param summary If `TRUE`, return a one-row-per-parameter table of the
#'   posterior mean, standard deviation and 2.5%, 50% and 97.5% quantiles
#'   instead of the draws.
#'
#' @details
#' The draws contain the population-level (average reef) parameters only:
#' \describe{
#'   \item{alpha, beta}{Intercept and slope of the calibration on the model's
#'     linear predictor scale.}
#'   \item{phi}{Beta models (coral cover): the precision of the Beta
#'     distribution.}
#'   \item{r}{Negative Binomial models (COTS counts): the size (dispersion)
#'     parameter, so that the variance is `mu + mu^2 / r`.}
#'   \item{obs_re_sd}{Reef-level Binomial models only: the standard deviation of
#'     an observation-level reef effect, used for prediction intervals for a new
#'     reef.}
#' }
#' The `model_info` attribute gives the model name, family, link and a plain
#' description of how the parameters combine, including the predictor `x` (the
#' same predictor as in [GBR_curve()]) and any offset. For Negative Binomial
#' and offset Binomial models the linear predictor also includes `log(effort)`;
#' see [GBR_calibrate()] for which effort that is.
#'
#' @return A data.frame of posterior draws (or, if `summary = TRUE`, a summary
#'   table) with attribute `model_info`, a list with the elements `model`,
#'   `family`, `link`, `level`, `from`, `to`, `eps` (the constant added to the
#'   predictor before taking logs, for count and binomial models), `offset`
#'   (whether the model uses a log-effort offset) and `equation`.
#'
#' @examples
#' draws <- GBR_posterior("coral_surface", "coral_manta", level = "reef")
#' head(draws)
#' attr(draws, "model_info")$equation
#'
#' GBR_posterior("coral_surface", "coral_manta", level = "reef", summary = TRUE)
#'
#' # Your own prediction from the draws: manta cover at 30% ReefScan Surface cover
#' link <- attr(draws, "model_info")$link
#' eta <- draws$alpha + draws$beta * 0.3
#' mu <- if (link == "loglog") exp(-exp(-eta)) else plogis(eta)
#' quantile(mu, c(0.025, 0.5, 0.975))
#' @export
GBR_posterior <- function(from, to, level = c("reef", "cull_site", "tow"),
                          to.type = c("presence", "count"), summary = FALSE) {
  level <- match.arg(level)
  to.type <- match.arg(to.type)
  if (missing(from) || missing(to)) stop("Both `from` and `to` must be specified.", call. = FALSE)
  from_key <- normaliseTool(from, "from")
  to_key <- normaliseTool(to, "to")
  if (isCoral(from_key) != isCoral(to_key)) {
    stop("Predictions can only be made within COTS measurements or within coral measurements, ",
         "not between the two.", call. = FALSE)
  }
  if (from_key == to_key) stop("`from` and `to` are the same tool.", call. = FALSE)

  model <- findModel(from_key, to_key, level, to.type)
  post <- loadPosterior(model$model_name)
  draws <- as.data.frame(unclass(post), stringsAsFactors = FALSE)

  link <- attr(post, "link")
  if (is.null(link)) link <- model$link
  info <- list(
    model = model$model_name,
    family = model$family,
    link = link,
    level = level,
    from = displayName[[from_key]],
    to = toLabel(to_key, model, to.type),
    eps = if (model$family == "beta") NA_real_ else model$eps,
    offset = isTRUE(model$has_offset) || model$family == "negbin",
    equation = describeModel(model, from_key, level, post)
  )

  if (!summary) {
    attr(draws, "model_info") <- info
    return(draws)
  }
  q <- function(v) stats::quantile(v, c(0.025, 0.5, 0.975), names = FALSE)
  tab <- do.call(rbind, lapply(names(draws), function(p) {
    v <- draws[[p]]
    data.frame(parameter = p, mean = mean(v), sd = stats::sd(v),
               q2.5 = q(v)[1], q50 = q(v)[2], q97.5 = q(v)[3])
  }))
  rownames(tab) <- NULL
  attr(tab, "model_info") <- info
  tab
}
