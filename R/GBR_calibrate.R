#' Predicts measurements from one GBR monitoring tool in another monitoring tool
#'
#' @description
#' This function predicts one measurement from another, for Great Barrier
#' Reef (GBR) monitoring tools, together with confidence and prediction
#' intervals. The tools that measure Crown-of-Thorns Starfish (COTS) are:
#' Manta Tow, ReefScan Surface (Transom), ReefScan Deep, eDNA (concentration)
#' and eDNA (proportion positive). The tools that measure coral cover are:
#' Manta Tow, ReefScan Surface (Transom) and ReefScan Deep. The predictions
#' come from pairwise Bayesian GLMMs (Beta for coral cover, Negative Binomial
#' and Binomial for COTS) fitted to 2025/2026 Reef Joint Field Management
#' Program (RJFMP) data at three spatial levels: individual manta tow, cull
#' site and reef. The posterior draws for every model are bundled with the
#' package.
#'
#' @param from A string giving the type of measurement to be converted.
#'   Options are `"Manta"`, `"RS_surface"`, `"RS_deep"`, `"eDNA_conc"`,
#'   `"eDNA_prop"` (COTS) and `"coral_manta"`, `"coral_surface"`,
#'   `"coral_deep"` (coral cover). Capitalisation does not matter, but the
#'   underscores do. `"transom"` may be used in place of `"surface"` (e.g.
#'   `"RS_transom"`, `"coral_transom"`). See Details.
#' @param to A string giving the type of the output measurement. Options are
#'   the same as `from`. If `from` and `to` are the same, the (aggregated)
#'   `from` data are returned with a warning.
#' @param level The spatial level at which observations are combined and
#'   predictions are made: `"tow"` (one observation is one manta tow
#'   segment), `"cull_site"` (observations are combined within a cull site) or
#'   `"reef"` (observations are combined within a reef). Default `"reef"`.
#'   Every pair of tools exists at reef level; the eDNA tools exist at reef
#'   level only.
#' @param from.metric The observation values for the `from` measurement, in
#'   the units the tool is usually reported in. See Details.
#' @param from.effort The amount of effort behind each `from.metric`
#'   observation. Only used for `from = "RS_surface"` and `"RS_deep"`, where it
#'   is the number of tows each count was collected over. If `NULL` (default)
#'   each observation is assumed to be one tow.
#' @param from.scars Only used for `from = "Manta"`: the feeding-scar code for
#'   each tow, one of `"a"` (absent), `"p"` (present) or `"c"` (common), or
#'   numeric 0/1. Must be the same length as `from.metric`.
#' @param to.effort The amount of effort assumed for the prediction, when the
#'   `to` tool needs one. For `to = "Manta"` at tow level it is the tow
#'   distance in metres; for `to = "eDNA_conc"` it is the number of PCR assays;
#'   for `to = "eDNA_prop"` it is the number of samples. If `NULL` (default)
#'   a typical value from the BR-04 data is used, and a message says which.
#' @param to.nTows The number of tows the prediction is made for, at
#'   `"cull_site"` and `"reef"` level (ignored at tow level, where it is 1).
#'   If `NULL` (default) the median from the BR-04 data is used (3 tows for a
#'   cull site, 27 for a reef).
#' @param to.type Only used for `to = "Manta"`, where there are two kinds of
#'   prediction: `"presence"` (default), the probability that a tow (or the
#'   proportion of tows) has a scar present or at least one COTS observed;
#'   and `"count"`, the combined COTS-plus-scar count. Manta counts can only be
#'   predicted from the ReefScan tools, not from eDNA.
#' @param sites A character or factor saying which observations belong to
#'   which site (a cull site or reef, depending on `level`). One row of output
#'   is produced per site. When data come from several reefs, make sure the
#'   labels are unique. At `level = "tow"` every observation is its own unit
#'   and `sites` is only used as a label.
#' @param intLevel A scalar between 0.5 and 1, usually 0.95 or 0.9, giving the
#'   level of the confidence and prediction intervals.
#'
#' @details
#' The prediction can only occur within COTS measurements and within coral
#' cover measurements; there is no scope for predicting COTS from coral or
#' vice-versa. Not every pair of tools exists at every level: if the
#' requested combination has no model, the error lists what is available.
#'
#' The `from.metric` (and `from.effort`, `from.scars`) should be, for the
#' different `from` tools:
#'
#' \describe{
#'   \item{Manta}{`from.metric` is the number of COTS seen on each tow and
#'     `from.scars` the scar code of each tow. The predictor is the combined
#'     density (COTS seen plus number of tows with scars, per tow).}
#'   \item{RS_surface, RS_deep}{`from.metric` is the number of COTS detected
#'     in the images; `from.effort` is the number of tows it was collected
#'     over (default one per observation). Values that share a site label are
#'     summed, and the predictor is the density (COTS per tow).}
#'   \item{eDNA_conc}{`from.metric` is the concentration of each PCR assay
#'     (replicate); the predictor is the total concentration per assay.
#'     Missing assays are ignored.}
#'   \item{eDNA_prop}{`from.metric` is either a 0/1 detection for each sample,
#'     or the proportion of positive samples. The proportion is taken
#'     internally.}
#'   \item{coral_manta}{The proportion (0-1) of hard coral cover for each tow,
#'     or the manta ordinal category as a character (`"0"`, `"1-"`, `"1+"`,
#'     ..., `"5+"`), which is converted to the category midpoint. Multiple
#'     observations per site are averaged.}
#'   \item{coral_surface, coral_deep}{The proportion (0-1) of hard coral cover.
#'     Multiple observations per site are averaged.}
#' }
#'
#' The scale of the prediction depends on the `to` tool. Coral cover is a
#' proportion. For COTS counts (`"RS_surface"`, `"RS_deep"`, `"eDNA_conc"`,
#' `to.type = "count"` Manta) it is the expected count for the assumed effort
#' (`to.nTows` tows, or `to.effort` assays for eDNA concentration, which is
#' the sum of assay concentrations). For presence (`to.type = "presence"`
#' Manta, `"eDNA_prop"`) it is a probability or proportion; at cull-site and
#' reef level the prediction interval is for the proportion of `to.nTows`
#' tows (or `to.effort` samples).
#'
#' All predictions are for the average reef (random effects are set to zero).
#' Confidence intervals show how far the mean prediction may vary; prediction
#' intervals show how far a new observation may vary. For the reef-level
#' presence models, which carry an observation-level reef effect, the
#' prediction interval is for a new reef. The prediction intervals are
#' simulated, so call [set.seed()] first for reproducible results.
#'
#' Some pairs involving ReefScan Deep (and ReefScan Deep tow level) are based
#' on very few reefs. These are flagged with a message and should be treated
#' as exploratory.
#'
#' @return A data.frame with one row per site, containing the summary of the
#'   input data for that site, the effort assumed for the prediction (where
#'   relevant), and the predicted values: `mean_<to>`, `lowerCI_<to>`,
#'   `upperCI_<to>`, `lowerPI_<to>` and `upperPI_<to>`. The model used is
#'   recorded in `attr(, "model")`.
#'
#' @examples
#' set.seed(2718)
#'
#' # Coral cover: predict manta tow cover from ReefScan Surface cover, by reef
#' surf <- data.frame(
#'   reef = rep(c("reefA", "reefB"), each = 5),
#'   cover = c(0.10, 0.15, 0.20, 0.12, 0.18, 0.40, 0.45, 0.35, 0.50, 0.42)
#' )
#' GBR_calibrate(
#'   from = "coral_surface", to = "coral_manta", level = "reef",
#'   from.metric = surf$cover, sites = surf$reef
#' )
#'
#' # COTS: predict the number of ReefScan Surface COTS seen over 27 tows from
#' # manta tow counts and scars
#' manta <- data.frame(
#'   reef = rep(c("reefA", "reefB"), each = 6),
#'   cots = c(0, 0, 1, 0, 0, 0, 0, 2, 1, 0, 3, 1),
#'   scars = c("a", "a", "p", "a", "a", "a", "p", "p", "p", "a", "c", "p")
#' )
#' GBR_calibrate(
#'   from = "Manta", to = "RS_surface", level = "reef",
#'   from.metric = manta$cots, from.scars = manta$scars, sites = manta$reef
#' )
#'
#' # Probability that a manta tow detects COTS, from eDNA detections at a reef
#' GBR_calibrate(
#'   from = "eDNA_prop", to = "Manta", level = "reef",
#'   from.metric = c(rep(1, 6), rep(0, 18)), sites = rep("reefA", 24)
#' )
#' @export
GBR_calibrate <- function(from, to, level = c("reef", "cull_site", "tow"),
                          from.metric, from.effort = NULL, from.scars = NULL,
                          to.effort = NULL, to.nTows = NULL,
                          to.type = c("presence", "count"),
                          sites = NULL, intLevel = 0.95) {
  level <- match.arg(level)
  to.type <- match.arg(to.type)
  if (missing(from) || missing(to)) stop("Both `from` and `to` must be specified.", call. = FALSE)
  if (missing(from.metric) || is.null(from.metric)) stop("from.metric must be specified.", call. = FALSE)
  if (!is.numeric(intLevel) || length(intLevel) != 1L || intLevel < 0.5 || intLevel >= 1) {
    stop("intLevel must be a single number between 0.5 and 1.", call. = FALSE)
  }
  if (!is.null(to.effort) && length(to.effort) != 1L) {
    stop("Multiple values of to.effort supplied. Please provide a single scalar.", call. = FALSE)
  }
  if (!is.null(to.nTows) && length(to.nTows) != 1L) {
    stop("Multiple values of to.nTows supplied. Please provide a single scalar.", call. = FALSE)
  }

  from_key <- normaliseTool(from, "from")
  to_key <- normaliseTool(to, "to")
  if (isCoral(from_key) != isCoral(to_key)) {
    stop("Predictions can only be made within COTS measurements or within coral measurements, ",
         "not between the two.", call. = FALSE)
  }

  n_obs <- length(from.metric)
  if (is.null(sites)) {
    if (level == "tow") {
      sites <- paste0("tow_", seq_len(n_obs))
    } else {
      warning("No sites argument supplied. Assuming that all data come from a single site ",
              "(aggregated over all observations).", call. = FALSE)
      sites <- rep("1", n_obs)
    }
  }
  if (length(sites) != n_obs) {
    stop("Number of values in from.metric is different to the number of labels in sites. Please check.",
         call. = FALSE)
  }
  if (level == "tow" && anyDuplicated(sites)) {
    stop("At level = \"tow\" every observation is a separate tow, so site labels must be unique.",
         call. = FALSE)
  }
  if (!is.null(from.effort) && length(from.effort) != n_obs) {
    stop("Number of values in from.metric is different to the number of values in from.effort. Please check.",
         call. = FALSE)
  }
  sites <- factor(as.character(sites), levels = unique(as.character(sites)))

  agg <- aggregateFrom(from_key, from.metric, from.effort, from.scars, sites)

  if (from_key == to_key) {
    warning("`from` and `to` are the same. Returning the aggregated input data.", call. = FALSE)
    return(agg$out)
  }

  model <- findModel(from_key, to_key, level, to.type)
  if (model$exploratory) {
    message("Note: the model used (", model$model_name, ") is based on very few reefs and is exploratory.")
  }

  eff <- resolveToEffort(model, to_key, level, to.effort, to.nTows)
  post <- loadPosterior(model$model_name)
  pred <- predictModel(model, post, x = agg$x, effort = eff$effort,
                       size = eff$size, intLevel = intLevel)

  label <- toLabel(to_key, model, to.type)
  out <- agg$out
  if (!is.na(eff$column)) out[[paste0(label, "_", eff$column)]] <- eff$value
  out[[paste0("mean_", label)]] <- pred[, "mean"]
  out[[paste0("lowerCI_", label)]] <- pred[, "lowerCI"]
  out[[paste0("upperCI_", label)]] <- pred[, "upperCI"]
  out[[paste0("lowerPI_", label)]] <- pred[, "lowerPI"]
  out[[paste0("upperPI_", label)]] <- pred[, "upperPI"]
  rownames(out) <- NULL
  attr(out, "model") <- model$model_name
  out
}
