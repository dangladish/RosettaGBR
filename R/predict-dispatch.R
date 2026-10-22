#' Predict from any BR-04 calibration model by name
#'
#' Generic dispatcher: looks up a model's family/link/eps conventions in
#' [rosetta_models()] and calls the matching curve engine
#' ([predBetaCurve()] / [predNegBinCurve()] / [predBinomialCurve()]). Most
#' users will find the per-model `pred*From*()` wrapper functions (e.g.
#' [predMantaFromSurfTow()]) more convenient -- this function exists for
#' programmatic use (e.g. looping over many models) and is what every
#' wrapper function calls internally.
#'
#' @param model_name One of `rosetta_models()$model_name`.
#' @param post Posterior-samples matrix for that model (see
#'   `?predBetaCurve`/`?predNegBinCurve`/`?predBinomialCurve` for the column
#'   contract).
#' @param x Numeric vector of predictor values.
#' @param offset Log-effort offset, for `"negbin"` models or `"binomial"`
#'   models fit with `has_offset = TRUE` (see `rosetta_models()`). Ignored
#'   (with a warning if non-default) for models with no offset term.
#' @param size Representative trial count, for `"binomial"` models with
#'   `has_offset = FALSE` (trials()-form rate models). Ignored otherwise.
#' @param eps Override the model's registry `eps` default if supplied;
#'   otherwise taken from `rosetta_models()`.
#' @param n_draws Number of posterior draws to use. Default 2000.
#'
#' @return A tibble as described in [predBetaCurve()] / [predNegBinCurve()] /
#'   [predBinomialCurve()].
#' @export
rosetta_predict <- function(model_name, post, x, offset = 0, size = 1,
                             eps = NULL, n_draws = 2000) {
  reg <- rosetta_models(include_diagnostic = TRUE, source = "br04")
  row <- reg[reg$model_name == model_name, ]
  if (nrow(row) == 0) {
    d02_reg <- rosetta_models(source = "d02")
    if (model_name %in% d02_reg$model_name) {
      stop("'", model_name, "' is a D-02 model (see rosetta_models(source = \"d02\")) -- ",
           "call its wrapper function directly, e.g. ", model_name, "(...); it has no ",
           "posterior-matrix/x contract and is not dispatched through rosetta_predict().",
           call. = FALSE)
    }
    stop("Unknown model_name '", model_name, "'. See rosetta_models() for valid names.", call. = FALSE)
  }
  if (isTRUE(row$is_diagnostic)) {
    stop("'", model_name, "' is a one-off diagnostic/QA posterior, not a calibration model -- ",
         "no prediction contract is defined for it.", call. = FALSE)
  }
  eps_val <- if (is.null(eps)) row$eps else eps

  switch(row$family,
    beta = predBetaCurve(post, x, n_draws = n_draws),
    negbin = predNegBinCurve(post, x, offset = offset, eps = eps_val, n_draws = n_draws),
    binomial = predBinomialCurve(
      post, x,
      offset = if (isTRUE(row$has_offset)) offset else NULL,
      eps = eps_val, link = row$link,
      size = if (isTRUE(row$has_offset)) 1 else size,
      n_draws = n_draws
    ),
    stop("Unrecognized family '", row$family, "' in registry for '", model_name, "'.", call. = FALSE)
  )
}
