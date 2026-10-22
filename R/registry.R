#' List available calibration models
#'
#' Returns the model registry: metadata for every calibration model this
#' package has a `pred*From*()` wrapper function for. Two distinct sources
#' are included (see `source`):
#' \itemize{
#'   \item `"br04"` -- the 52 CCIP BR-04 tow/cull-site/reef models fitted for
#'     that project (family, link, offset/eps conventions, etc.); you
#'     supply your own posterior-samples matrix (e.g.
#'     `readRDS("path/to/<model_name>.RDS")`) to these
#'     wrappers.
#'   \item `"d02"` -- the 32 CCIP D-02 site-level models, thin pass-throughs
#'     to RosettaCOTS's own (unexported) per-model functions, each reading
#'     RosettaCOTS's own bundled posterior internally -- no posterior matrix
#'     argument is needed for these; call them directly with their D-02
#'     metric arguments (see each function's own `@details`).
#' }
#' This is a metadata lookup table only -- it does not itself bundle
#' posterior samples or canonical data tables (see package Description).
#'
#' @param include_diagnostic Include the handful of one-off diagnostic/QA
#'   `"br04"` posteriors (JAGS-vs-Stan benchmark, D-02 prior spot-checks)
#'   that have no corresponding wrapper function? Default `FALSE`. Ignored
#'   for `"d02"` rows (none are diagnostic).
#' @param source Which registry/registries to return: `"br04"`, `"d02"`, or
#'   `c("br04", "d02")` (default) for both.
#'
#' @return A tibble, one row per model, with `source` (`"br04"`/`"d02"`),
#'   `model_name`, `wrapper_fun` (the name of this package's corresponding
#'   `pred*From*()` function), `response_method`, `predictor_method`,
#'   `response_variable`, `predictor_variable`, `notes`, and -- `"br04"` rows
#'   only -- `family` (`"beta"`/`"negbin"`/`"binomial"`), `level`
#'   (`"tow"`/`"cull_site"`/`"reef"`), `link`, `has_offset`, `eps`,
#'   `grouped`, `pi_size` (`NA` for `"d02"` rows, which have no such
#'   contract -- see Details).
#' @export
#'
#' @examples
#' rosetta_models()
#' rosetta_models(source = "d02")
rosetta_models <- function(include_diagnostic = FALSE, source = c("br04", "d02")) {
  source <- match.arg(source, c("br04", "d02"), several.ok = TRUE)
  out <- list()
  if ("br04" %in% source) {
    reg <- .rosetta_registry()
    if (!include_diagnostic) reg <- reg[!reg$is_diagnostic, ]
    reg$source <- "br04"
    out$br04 <- reg
  }
  if ("d02" %in% source) {
    d02 <- .rosetta_registry_d02()
    d02$source <- "d02"
    out$d02 <- d02
  }
  cols <- unique(unlist(lapply(out, names)))
  out <- lapply(out, function(d) {
    missing_cols <- setdiff(cols, names(d))
    d[missing_cols] <- NA
    d[cols]
  })
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  tibble::as_tibble(res)[, c("source", setdiff(cols, "source"))]
}

# Internal: load the D-02 registry CSV (RosettaCOTS pass-through models --
# see R/wrappers_d02.R / data-raw/generate_d02_wrappers.R).
.rosetta_registry_d02 <- function() {
  path <- system.file("extdata", "d02_model_registry.csv", package = "RosettaGBR")
  if (!nzchar(path)) path <- file.path("inst", "extdata", "d02_model_registry.csv")
  reg <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  reg <- tibble::as_tibble(reg)
  reg$wrapper_fun <- reg$model_name # D-02 wrappers keep RosettaCOTS's own function name verbatim
  reg$is_diagnostic <- FALSE
  reg
}

# Internal: load + lightly post-process the registry CSV shipped in
# inst/extdata/. Re-read on every call rather than cached at build time --
# this is a tiny file and it keeps the data trivially inspectable/editable
# without a data-raw/sysdata.rda round trip.
.rosetta_registry <- function() {
  path <- system.file("extdata", "model_registry.csv", package = "RosettaGBR")
  if (!nzchar(path)) {
    # devtools::load_all() / not-yet-installed fallback
    path <- file.path("inst", "extdata", "model_registry.csv")
  }
  reg <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  reg <- tibble::as_tibble(reg)
  reg$is_diagnostic <- as.logical(reg$is_diagnostic)
  reg$has_offset <- as.logical(reg$has_offset)
  reg$grouped <- as.logical(reg$grouped)
  reg$wrapper_fun <- ifelse(reg$is_diagnostic, NA_character_, vapply(reg$model_name, model_name_to_wrapper, character(1)))
  reg
}

# Internal: convert a model_name like "manta_from_surf_binary_cull_cots" into
# the wrapper function name "predMantaFromSurfBinaryCullCots", by
# PascalCase-ing each underscore-delimited part and prefixing "pred". Leading
# underscores (diagnostic files) are stripped. This is a pure, mechanical,
# 1:1-reversible transform -- deliberately NOT hand-maintained per model, so
# the wrapper name can never silently drift from the actual posterior
# filename it reads.
model_name_to_wrapper <- function(model_name) {
  parts <- strsplit(sub("^_+", "", model_name), "_")[[1]]
  parts <- parts[nzchar(parts)]
  pascal <- vapply(parts, function(p) paste0(toupper(substr(p, 1, 1)), substr(p, 2, nchar(p))), character(1))
  paste0("pred", paste(pascal, collapse = ""))
}
