#' Load a bundled BR-04 posterior
#'
#' RosettaGBR ships the saved posterior draws for all 52 BR-04 calibration
#' models (see [rosetta_models()]), so every `pred*From*()` wrapper works
#' out of the box. This function returns the bundled posterior for one model,
#' e.g. to inspect it, summarise it, or pass it to a prediction function
#' explicitly.
#'
#' Each posterior is a numeric matrix with one row per draw and only the
#' population-level columns needed for prediction: `alpha`, `beta` and `phi`
#' (Beta models), `alpha`, `beta` and `r` (Negative Binomial models), or
#' `alpha` and `beta` (Binomial models). Random-effect draws and sampler
#' internals are not included. Where relevant the matrix carries a `"link"`
#' attribute (`"loglog"`, `"cloglog"` or `"logit"`) and, for the reef-level
#' Binomial models, an `"obs_re_sd"` attribute naming the column that holds
#' the observation-level reef standard deviation draws.
#'
#' @param model_name One of `rosetta_models(source = "br04")$model_name`.
#'
#' @return A numeric matrix of posterior draws.
#' @examples
#' post <- rosetta_posterior("manta_from_surf_tow")
#' dim(post)
#' attr(post, "link")
#' @export
rosetta_posterior <- function(model_name) {
  if (!is.character(model_name) || length(model_name) != 1L) {
    stop("`model_name` must be a single string.", call. = FALSE)
  }
  path <- system.file("extdata", "posteriors", paste0(model_name, ".RDS"),
                      package = "RosettaGBR")
  if (!nzchar(path)) {
    stop("No bundled posterior for '", model_name, "'. ",
         "See rosetta_models(source = \"br04\") for valid names.", call. = FALSE)
  }
  readRDS(path)
}

# Observation-level reef SD draws, if the posterior carries them.
obs_re_sd_draws <- function(post) {
  col <- attr(post, "obs_re_sd")
  if (is.null(col)) NULL else as.numeric(post[, col])
}
