# Internal helpers for GBR_calibrate(). None of these are exported.

#' @importFrom stats plogis quantile rbeta rbinom rnbinom rnorm
#' @importFrom utils read.csv
NULL

# Typical effort for a prediction when the user does not supply one: medians
# from the BR-04 data.
defaultEffort <- list(
  nTows = c(tow = 1, cull_site = 3, reef = 27),
  towDistance = 188.6,   # metres
  eDNAassays = 48,       # PCR assays per reef
  eDNAsamples = 24       # samples per reef
)

# Midpoints (proportion cover) of the manta tow ordinal coral categories
coralMidpoints <- c(
  "0" = 0, "1-" = 0.025, "1+" = 0.075, "2-" = 0.15, "2+" = 0.25,
  "3-" = 0.35, "3+" = 0.45, "4-" = 0.55, "4+" = 0.65, "5-" = 0.75, "5+" = 0.875
)

validTools <- c("manta", "rs_surface", "rs_deep", "edna_conc", "edna_prop",
                "coral_manta", "coral_surface", "coral_deep")

displayName <- c(
  manta = "Manta", rs_surface = "RS_surface", rs_deep = "RS_deep",
  edna_conc = "eDNA_conc", edna_prop = "eDNA_prop",
  coral_manta = "coral_manta", coral_surface = "coral_surface", coral_deep = "coral_deep"
)

normaliseTool <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L) {
    stop("`", arg, "` must be a single string.", call. = FALSE)
  }
  key <- gsub("transom", "surface", tolower(x), fixed = TRUE)
  if (!key %in% validTools) {
    stop("Unknown `", arg, "` value '", x, "'. Options are: ",
         paste(displayName, collapse = ", "), ".", call. = FALSE)
  }
  key
}

isCoral <- function(key) startsWith(key, "coral_")

# Tool key -> the method name used in the model registry
toMethod <- function(key) {
  switch(key,
    coral_manta = "manta", coral_surface = "rs_surface", coral_deep = "rs_deep",
    key
  )
}

# ---- aggregation of the `from` observations to one value per site ----------

siteSum <- function(v, sites) as.numeric(tapply(v, sites, sum, na.rm = TRUE))
siteMean <- function(v, sites) as.numeric(tapply(v, sites, mean, na.rm = TRUE))
siteCount <- function(v, sites) as.numeric(tapply(v, sites, function(z) sum(!is.na(z))))

aggregateFrom <- function(key, metric, effort, scars, sites) {
  out <- data.frame(site = levels(sites), stringsAsFactors = FALSE)
  nm <- displayName[[key]]

  if (isCoral(key)) {
    if (key == "coral_manta" && (is.character(metric) || is.factor(metric))) {
      m <- coralMidpoints[as.character(metric)]
      if (anyNA(m[!is.na(metric)])) {
        stop("Unrecognised manta coral category. Use one of: ",
             paste(names(coralMidpoints), collapse = ", "), ".", call. = FALSE)
      }
      metric <- as.numeric(m)
    }
    if (!is.numeric(metric)) stop("Coral cover from.metric must be numeric proportions (0-1).", call. = FALSE)
    if (any(metric < 0 | metric > 1, na.rm = TRUE)) {
      stop("Coral cover must be a proportion between 0 and 1 (not a percentage).", call. = FALSE)
    }
    x <- siteMean(metric, sites)
    out[[paste0(nm, "_cover")]] <- x
    out[[paste0(nm, "_nObs")]] <- siteCount(metric, sites)
    return(list(out = out, x = x))
  }

  if (key == "edna_prop") {
    if (!is.numeric(metric) || any(metric < 0 | metric > 1, na.rm = TRUE)) {
      stop("eDNA_prop from.metric must be 0/1 detections or proportions between 0 and 1.", call. = FALSE)
    }
    x <- siteMean(metric, sites)
    out$eDNA_prop_samples <- siteCount(metric, sites)
    out$eDNA_prop <- x
    return(list(out = out, x = x))
  }

  if (!is.numeric(metric) || any(metric < 0, na.rm = TRUE)) {
    stop("from.metric must be non-negative numbers.", call. = FALSE)
  }

  if (key == "edna_conc") {
    total <- round(siteSum(metric, sites))
    assays <- siteCount(metric, sites)
    x <- total / assays
    out$eDNA_conc_sum <- total
    out$eDNA_conc_assays <- assays
    out$eDNA_conc_rate <- x
    return(list(out = out, x = x))
  }

  if (key == "manta") {
    if (is.null(scars)) {
      stop("from = \"Manta\" needs `from.scars`: the scar code (a/p/c) of each tow, ",
           "the same length as from.metric.", call. = FALSE)
    }
    if (length(scars) != length(metric)) {
      stop("from.scars must be the same length as from.metric.", call. = FALSE)
    }
    if (is.character(scars) || is.factor(scars)) {
      s <- tolower(as.character(scars))
      if (any(!s %in% c("a", "p", "c") & !is.na(s))) {
        stop("from.scars must be \"a\", \"p\" or \"c\" (or numeric 0/1).", call. = FALSE)
      }
      present <- as.numeric(s %in% c("p", "c"))
      present[is.na(s)] <- NA
    } else {
      present <- as.numeric(scars > 0)
    }
    cots <- siteSum(metric, sites)
    scar_tows <- siteSum(present, sites)
    tows <- siteCount(metric, sites)
    x <- (cots + scar_tows) / tows
    out$Manta_COTS <- cots
    out$Manta_scars <- scar_tows
    out$Manta_tows <- tows
    out$Manta_density <- x
    return(list(out = out, x = x))
  }

  # RS_surface / RS_deep
  eff <- if (is.null(effort)) rep(1, length(metric)) else effort
  if (!is.numeric(eff) || any(eff <= 0, na.rm = TRUE)) stop("from.effort must be positive numbers.", call. = FALSE)
  eff[is.na(metric)] <- NA
  counts <- siteSum(metric, sites)
  tows <- siteSum(eff, sites)
  x <- counts / tows
  out[[paste0(nm, "_COTS")]] <- counts
  out[[paste0(nm, "_effort")]] <- tows
  out[[paste0(nm, "_density")]] <- x
  list(out = out, x = x)
}

# ---- model lookup -----------------------------------------------------------

loadRegistry <- function() {
  path <- system.file("extdata", "model_registry.csv", package = "RosettaGBR")
  if (!nzchar(path)) stop("Model registry not found; the package may be incorrectly installed.", call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE)
}

loadPosterior <- function(model_name) {
  path <- system.file("extdata", "posteriors", paste0(model_name, ".RDS"), package = "RosettaGBR")
  if (!nzchar(path)) stop("Bundled posterior for '", model_name, "' not found.", call. = FALSE)
  readRDS(path)
}

findModel <- function(from_key, to_key, level, to.type) {
  reg <- loadRegistry()
  coral <- isCoral(from_key)
  pair <- reg[reg$predictor_method == toMethod(from_key) &
                reg$response_method == toMethod(to_key) &
                (reg$family == "beta") == coral, , drop = FALSE]

  fmt_levels <- function(d) paste(unique(d$level), collapse = ", ")
  if (nrow(pair) == 0) {
    stop("There is no calibration model for ", displayName[[from_key]], " -> ",
         displayName[[to_key]], ".", call. = FALSE)
  }

  m <- pair[pair$level == level, , drop = FALSE]
  if (nrow(m) == 0) {
    stop("There is no ", displayName[[from_key]], " -> ", displayName[[to_key]],
         " model at level = \"", level, "\". Available levels: ", fmt_levels(pair), ".",
         call. = FALSE)
  }

  if (!coral && to_key == "manta") {
    want <- if (to.type == "count") "negbin" else "binomial"
    mm <- m[m$family == want, , drop = FALSE]
    if (nrow(mm) == 0) {
      stop("Manta ", to.type, " cannot be predicted from ", displayName[[from_key]],
           " at level = \"", level, "\". Available: to.type = \"",
           if (want == "negbin") "presence" else "count", "\".", call. = FALSE)
    }
    m <- mm
  }
  if (nrow(m) != 1L) stop("Internal error: ambiguous model lookup.", call. = FALSE)
  as.list(m)
}

toLabel <- function(to_key, model, to.type) {
  if (to_key == "manta") paste0("Manta_", to.type) else displayName[[to_key]]
}

# ---- effort assumed for the prediction -------------------------------------

resolveToEffort <- function(model, to_key, level, to.effort, to.nTows) {
  none <- list(effort = NA_real_, size = NA_real_, column = NA_character_, value = NA_real_)
  if (model$family == "beta") return(none)

  nTows_default <- unname(defaultEffort$nTows[level])
  getTows <- function() {
    if (level == "tow") return(1)
    if (is.null(to.nTows)) {
      message("Predictions are made using ", nTows_default, " tows (median of the BR-04 data at this level).")
      return(nTows_default)
    }
    to.nTows
  }

  if (to_key == "manta") {
    if (level == "tow") {
      d <- to.effort
      if (is.null(d)) {
        d <- defaultEffort$towDistance
        message("Predictions are made using ", d, " metre tows (median of the BR-04 data).")
      }
      return(list(effort = d, size = 1, column = "distance_m", value = d))
    }
    n <- getTows()
    if (model$family == "negbin") {
      return(list(effort = n, size = NA_real_, column = "nTows", value = n))
    }
    return(list(effort = NA_real_, size = n, column = "nTows", value = n))
  }

  if (to_key %in% c("rs_surface", "rs_deep")) {
    n <- getTows()
    return(list(effort = n, size = NA_real_, column = "nTows", value = n))
  }

  if (to_key == "edna_conc") {
    a <- to.effort
    if (is.null(a)) {
      a <- defaultEffort$eDNAassays
      message("Predictions are made using ", a, " PCR assays (median per reef in the BR-04 data).")
    }
    return(list(effort = a, size = NA_real_, column = "assays", value = a))
  }

  if (to_key == "edna_prop") {
    s <- to.effort
    if (is.null(s)) {
      s <- defaultEffort$eDNAsamples
      message("Predictions are made using ", s, " samples (median per reef in the BR-04 data).")
    }
    return(list(effort = NA_real_, size = s, column = "samples", value = s))
  }

  none
}

# ---- prediction engine -----------------------------------------------------

# Returns a matrix (one row per site) with columns mean, lowerCI, upperCI,
# lowerPI, upperPI. `x` is the predictor value for each site; `effort` is the
# log-offset effort (negbin / offset binomial) and `size` the trial count
# (trials-form binomial).
predictModel <- function(model, post, x, effort, size, intLevel, nDraws = 2000) {
  probs <- c((1 - intLevel) / 2, 1 - (1 - intLevel) / 2)
  nd <- nrow(post)
  idx <- if (nd > nDraws) sample.int(nd, nDraws) else seq_len(nd)
  n <- length(idx)
  alpha <- post[idx, "alpha"]
  beta <- post[idx, "beta"]

  ns <- length(x)
  eps <- model$eps

  if (model$family == "beta") {
    link <- attr(post, "link")
    if (is.null(link)) link <- "logit"
    inv_link <- switch(link,
      logit = plogis,
      loglog = function(eta) exp(-exp(-eta)),
      stop("Unsupported link '", link, "' for ", model$model_name, ".", call. = FALSE)
    )
    phi <- post[idx, "phi"]
    mu <- inv_link(outer(beta, x) + alpha)
    mu_adj <- pmin(pmax(mu, 1e-5), 1 - 1e-5)
    y_pred <- suppressWarnings(matrix(rbeta(length(mu_adj), mu_adj * phi, (1 - mu_adj) * phi), nrow = n))
    union_ci <- FALSE
  } else if (model$family == "negbin") {
    r <- post[idx, "r"]
    mu <- exp(outer(beta, log(x + eps)) + alpha + log(effort))
    y_pred <- suppressWarnings(matrix(rnbinom(length(mu), size = r, mu = mu), nrow = n))
    union_ci <- TRUE
  } else {
    link <- model$link
    linv <- if (link == "cloglog") function(l) 1 - exp(-exp(l)) else plogis
    lp <- outer(beta, log(x + eps)) + alpha
    if (isTRUE(model$has_offset)) lp <- lp + log(effort)
    mu <- linv(lp)
    obs_col <- attr(post, "obs_re_sd")
    lp_new <- if (is.null(obs_col)) lp else lp + rnorm(n, 0, post[idx, obs_col])
    sz <- if (isTRUE(model$has_offset)) 1 else size
    y_pred <- suppressWarnings(matrix(rbinom(length(mu), size = sz, prob = linv(lp_new)), nrow = n)) / sz
    union_ci <- TRUE
  }

  q <- function(m) apply(m, 2, quantile, probs = probs, na.rm = TRUE)
  ci <- q(mu)
  pi <- q(y_pred)
  if (union_ci) {
    pi[1, ] <- pmin(pi[1, ], ci[1, ])
    pi[2, ] <- pmax(pi[2, ], ci[2, ])
  }
  cbind(
    mean = apply(mu, 2, mean, trim = 0.01),
    lowerCI = ci[1, ], upperCI = ci[2, ],
    lowerPI = pi[1, ], upperPI = pi[2, ]
  )
}
