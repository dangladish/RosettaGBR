# Builds the bundled posteriors in inst/extdata/posteriors/ from a directory of
# saved posterior files (one <model_name>.RDS per model).
#
# Usage (from the package root):
#   BR04_POSTERIORS_DIR=path/to/posteriors Rscript data-raw/build_posteriors.R
# or set the environment variable inside an R session before sourcing.
#
# Only what the prediction functions need is kept: the population-level
# columns (alpha/beta, plus phi for Beta models or r for Negative Binomial
# models), the observation-level reef SD column (renamed `obs_re_sd`) for
# models that have one, and the `link` / `obs_re_sd` attributes when present.
# Per-group random-effect draws and sampler internals are dropped, and the
# object is stored as a plain numeric matrix.

src_dir <- Sys.getenv("BR04_POSTERIORS_DIR")
if (!nzchar(src_dir) || !dir.exists(src_dir)) {
  stop("Set BR04_POSTERIORS_DIR to the directory holding <model_name>.RDS files.")
}

reg <- read.csv("inst/extdata/model_registry.csv", stringsAsFactors = FALSE)
reg <- reg[!reg$is_diagnostic, ]

out_dir <- "inst/extdata/posteriors"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

core_cols <- function(family) {
  switch(family,
    beta = c("alpha", "beta", "phi"),
    negbin = c("alpha", "beta", "r"),
    binomial = c("alpha", "beta")
  )
}

for (i in seq_len(nrow(reg))) {
  m <- reg$model_name[i]
  src <- file.path(src_dir, paste0(m, ".RDS"))
  if (!file.exists(src)) stop("Missing posterior file for model '", m, "': ", src)

  post <- readRDS(src)
  cols <- core_cols(reg$family[i])
  if (!all(cols %in% colnames(post))) {
    stop("Model '", m, "' is missing required column(s): ",
         paste(setdiff(cols, colnames(post)), collapse = ", "))
  }

  sd_col <- attr(post, "obs_re_sd")
  slim <- unclass(post)[, cols, drop = FALSE]
  if (!is.null(sd_col)) {
    slim <- cbind(slim, obs_re_sd = unclass(post)[, sd_col])
  }
  slim <- matrix(as.numeric(slim), nrow = nrow(slim), dimnames = list(NULL, colnames(slim)))
  if (!is.null(attr(post, "link"))) attr(slim, "link") <- attr(post, "link")
  if (!is.null(sd_col)) attr(slim, "obs_re_sd") <- "obs_re_sd"

  saveRDS(slim, file.path(out_dir, paste0(m, ".RDS")), compress = "xz")
}

cat("Wrote", nrow(reg), "posteriors to", out_dir, "\n")
