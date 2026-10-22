#' Posterior predictive curve for a Beta-regression (coral cover) model
#'
#' Computes the population-level (group effects marginalized to
#' zero) mean curve, 95% credible interval, and 95% prediction interval for a
#' Beta regression of the form `link(mu) = alpha + beta * x`.
#'
#' The link is read from `attr(post, "link")` (defaulting to `"logit"` when
#' absent, so every pre-existing posterior is unaffected) -- the same
#' "attribute travels with the posterior" convention `predBinomialCurve()`
#' uses its own `link` *argument* for, except here it's carried on the
#' posterior object itself rather than passed in, since callers (including
#' the generated `pred*From*()` wrappers) call this generically without
#' knowing which link a given coral model used. As of 2026-10-15,
#' `manta_from_surf_{tow,cull,reef}` use `"loglog"`
#' (`mu = exp(-exp(-eta))`); every other Beta coral model is `"logit"`
#' (`mu = plogis(eta)`). brms has no native loglog link for Beta, so the
#' `"loglog"` posteriors were fit via a mirrored-cloglog-on-`(1-y)` trick at
#' fit time and sign-flipped (`alpha`/`beta` negated) back onto the direct
#' `loglog(y)` scale before saving. Callers never need to apply any
#' mirroring themselves; `attr(post, "link")` plus this function's dispatch
#' is the entire contract.
#'
#' @param post A posterior-samples matrix/data frame with columns `alpha`,
#'   `beta`, `phi` (one row per posterior draw), optionally carrying a
#'   `"link"` attribute (`"logit"` or `"loglog"`; see Details). This is the
#'   exact contract used by RosettaCOTS and the saved BR-04 posteriors.
#' @param x Numeric vector of predictor values (the *other* method's coral
#'   cover proportion, 0-1 scale) at which to predict.
#' @param n_draws Number of posterior draws to use (subsampled if `post` has
#'   more rows than this, for speed). Default 2000.
#' @param clip_eps Numeric clipping applied to the fitted mean before
#'   simulating prediction-interval draws, to keep Beta shape parameters
#'   finite at mu in `{0, 1}`. Default 1e-5 (matches the model-fitting clip).
#'
#' @return A tibble with columns `x`, `mean`, `lo95`, `hi95`, `pi_lo95`,
#'   `pi_hi95` (all on the 0-1 proportion scale).
#' @export
predBetaCurve <- function(post, x, n_draws = 2000, clip_eps = 1e-5) {
  check_posterior_cols(post, c("alpha", "beta", "phi"))
  alpha <- post[, "alpha"]; beta <- post[, "beta"]; phi <- post[, "phi"]
  link <- attr(post, "link"); if (is.null(link)) link <- "logit"
  inv_link <- switch(link,
    logit  = stats::plogis,
    loglog = function(eta) exp(-exp(-eta)),
    stop("predBetaCurve: unsupported link '", link, "'", call. = FALSE)
  )
  idx <- sample_draws(length(alpha), n_draws)
  mu <- sapply(x, function(xi) inv_link(alpha[idx] + beta[idx] * xi))
  mu <- matrix(mu, nrow = length(idx))
  mu_adj <- pmin(pmax(mu, clip_eps), 1 - clip_eps)
  y_pred <- matrix(
    stats::rbeta(length(mu_adj), mu_adj * phi[idx], (1 - mu_adj) * phi[idx]),
    nrow = nrow(mu_adj)
  )
  tibble::tibble(
    x = x,
    mean    = apply(mu, 2, mean, trim = 0.01),
    lo95    = apply(mu, 2, stats::quantile, 0.025),
    hi95    = apply(mu, 2, stats::quantile, 0.975),
    pi_lo95 = apply(y_pred, 2, stats::quantile, 0.025),
    pi_hi95 = apply(y_pred, 2, stats::quantile, 0.975)
  )
}

#' Posterior predictive curve for a Negative Binomial (COTS count) model
#'
#' Computes the population-level mean curve, 95% credible interval, and 95%
#' prediction interval for a NegBin(log link) regression of the form
#' `log(mu) = alpha + beta * log(x + eps) + offset`.
#'
#' The prediction interval is unioned with the credible interval
#' (`pi_lo95 <- pmin(pi_lo95, lo95)`, `pi_hi95 <- pmax(pi_hi95, hi95)`) so it
#' can never be reported as narrower than the credible interval -- zero-heavy
#' NegBin draws can otherwise collapse the raw posterior-predictive central
#' interval below the mean-curve's own CI.
#'
#' @param post A posterior-samples matrix/data frame with columns `alpha`,
#'   `beta`, `r` (NegBin shape/size parameter).
#' @param x Numeric vector of predictor values (the *other* method's COTS
#'   density, i.e. count / effort) at which to predict.
#' @param offset Scalar or length-1 numeric: the log-effort offset
#'   (`log_offset` in the original helper) to apply, e.g. `log(mean(n_tows))`
#'   for a representative cull-site/reef effort, or `log(tow_distance_m)` for
#'   a representative tow length. Default 0 (predicts the rate per unit of
#'   whatever effort unit the model's offset was fit in -- see the model's
#'   entry in [rosetta_models()] for which offset was used at fit time).
#' @param eps Small constant added to `x` before taking `log()`, matching the
#'   value used when the model was fit (see `rosetta_models()$eps`).
#'   Default 0.01.
#' @param n_draws Number of posterior draws to use. Default 2000.
#'
#' @return A tibble with columns `x`, `mean`, `lo95`, `hi95`, `pi_lo95`,
#'   `pi_hi95` (counts, on whatever effort scale `offset` implies).
#' @export
predNegBinCurve <- function(post, x, offset = 0, eps = 0.01, n_draws = 2000) {
  check_posterior_cols(post, c("alpha", "beta", "r"))
  alpha <- post[, "alpha"]; beta <- post[, "beta"]; r <- post[, "r"]
  idx <- sample_draws(length(alpha), n_draws)
  x_lin <- log(x + eps)
  mu <- sapply(x_lin, function(xi) exp(alpha[idx] + beta[idx] * xi + offset))
  mu <- matrix(mu, nrow = length(idx))
  y_pred <- matrix(stats::rnbinom(length(mu), size = r[idx], mu = mu), nrow = nrow(mu))
  lo95 <- apply(mu, 2, stats::quantile, 0.025); hi95 <- apply(mu, 2, stats::quantile, 0.975)
  pi_lo95 <- apply(y_pred, 2, stats::quantile, 0.025); pi_hi95 <- apply(y_pred, 2, stats::quantile, 0.975)
  pi_lo95 <- pmin(pi_lo95, lo95); pi_hi95 <- pmax(pi_hi95, hi95)
  tibble::tibble(
    x = x,
    mean    = apply(mu, 2, mean, trim = 0.01),
    lo95    = lo95, hi95 = hi95,
    pi_lo95 = pi_lo95, pi_hi95 = pi_hi95
  )
}

#' Posterior predictive curve for a Binomial (COTS presence/rate) model
#'
#' Computes the population-level mean curve, 95% credible interval, and 95%
#' prediction interval for a Binomial regression of the form
#' `link(mu) = alpha + beta * log(x + eps) [+ offset]`, link being `"logit"`
#' or `"cloglog"`.
#'
#' For tow-level presence models (`size = 1`, the default), the 95%
#' prediction interval for a single Bernoulli trial is genuinely
#' degenerate-looking (commonly `{0, 1}` unless `mu` is extreme) -- this is
#' mathematically correct, not a bug. For cull-site/reef rate models, pass a
#' representative trial count via `size` (e.g. the median `n_tows` backing
#' one row); see that model's entry in [rosetta_models()] (`pi_size` column)
#' for the convention used when the model was fit/plotted.
#'
#' @inheritParams predNegBinCurve
#' @param offset Scalar log-effort offset, or `NULL` (default) for models fit
#'   with no separate offset term (i.e. exposure captured via `size`/
#'   `trials()` instead -- see `rosetta_models()$has_offset`).
#' @param link `"logit"` (default) or `"cloglog"`.
#' @param size Number of trials backing one new observation being predicted.
#'   Default 1 (a single tow's presence/absence outcome).
#'
#' @return A tibble with columns `x`, `mean`, `lo95`, `hi95`, `pi_lo95`,
#'   `pi_hi95` (all on the 0-1 proportion scale), with a `"pi_size"`
#'   attribute recording the `size` used.
#' @export
predBinomialCurve <- function(post, x, offset = NULL, eps = 0.01,
                               link = c("logit", "cloglog"), size = 1,
                               n_draws = 2000) {
  link <- match.arg(link)
  check_posterior_cols(post, c("alpha", "beta"))
  alpha <- post[, "alpha"]; beta <- post[, "beta"]
  idx <- sample_draws(length(alpha), n_draws)
  x_lin <- log(x + eps)
  linv <- function(lp) if (link == "cloglog") 1 - exp(-exp(lp)) else stats::plogis(lp)
  mu <- sapply(x_lin, function(xi) {
    lp <- alpha[idx] + beta[idx] * xi
    if (!is.null(offset)) lp <- lp + offset
    linv(lp)
  })
  mu <- matrix(mu, nrow = length(idx))
  y_pred <- matrix(stats::rbinom(length(mu), size = size, prob = mu), nrow = nrow(mu)) / size
  lo95 <- apply(mu, 2, stats::quantile, 0.025); hi95 <- apply(mu, 2, stats::quantile, 0.975)
  pi_lo95 <- apply(y_pred, 2, stats::quantile, 0.025); pi_hi95 <- apply(y_pred, 2, stats::quantile, 0.975)
  pi_lo95 <- pmin(pi_lo95, lo95); pi_hi95 <- pmax(pi_hi95, hi95)
  out <- tibble::tibble(
    x = x,
    mean    = apply(mu, 2, mean, trim = 0.01),
    lo95    = lo95, hi95 = hi95,
    pi_lo95 = pi_lo95, pi_hi95 = pi_hi95
  )
  attr(out, "pi_size") <- size
  out
}

check_posterior_cols <- function(post, needed) {
  nm <- colnames(post)
  missing <- setdiff(needed, nm)
  if (length(missing) > 0) {
    stop(
      "`post` is missing required column(s): ", paste(missing, collapse = ", "),
      ". Expected columns: ", paste(needed, collapse = ", "),
      ". See RosettaGBR's posterior-matrix contract in ?predBetaCurve / ?predNegBinCurve / ?predBinomialCurve.",
      call. = FALSE
    )
  }
}

sample_draws <- function(n, n_draws) {
  if (n_draws < n) sample.int(n, n_draws) else seq_len(n)
}
