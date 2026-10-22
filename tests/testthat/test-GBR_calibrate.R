post_of <- function(m) RosettaGBR:::loadPosterior(m)
trimmed <- function(v) mean(v, trim = 0.01)

test_that("the package exports a single function", {
  expect_equal(getNamespaceExports("RosettaGBR"), "GBR_calibrate")
})

test_that("every registry model has a complete bundled posterior", {
  reg <- RosettaGBR:::loadRegistry()
  expect_equal(nrow(reg), 52)
  for (i in seq_len(nrow(reg))) {
    post <- post_of(reg$model_name[i])
    needed <- switch(reg$family[i], beta = c("alpha", "beta", "phi"),
                     negbin = c("alpha", "beta", "r"), binomial = c("alpha", "beta"))
    expect_true(all(needed %in% colnames(post)), info = reg$model_name[i])
    expect_false(anyNA(post), info = reg$model_name[i])
    col <- attr(post, "obs_re_sd")
    if (!is.null(col)) expect_true(col %in% colnames(post), info = reg$model_name[i])
  }
})

test_that("every model is reachable through GBR_calibrate()", {
  reg <- RosettaGBR:::loadRegistry()
  keyOf <- function(method, coral) {
    switch(method, manta = if (coral) "coral_manta" else "Manta",
           rs_surface = if (coral) "coral_surface" else "ReefScan_surface",
           rs_deep = if (coral) "coral_deep" else "ReefScan_deep",
           edna_conc = "eDNA_conc", edna_prop = "eDNA_prop")
  }
  set.seed(9120)
  for (i in seq_len(nrow(reg))) {
    r <- reg[i, ]
    coral <- r$family == "beta"
    from <- keyOf(r$predictor_method, coral)
    to <- keyOf(r$response_method, coral)
    args <- list(from = from, to = to, level = r$level, sites = c("s1", "s2"),
                 to.type = if (r$family == "negbin") "count" else "presence")
    if (r$level == "tow") args$sites <- c("t1", "t2")
    args$from.metric <- if (coral) c(0.2, 0.6) else if (from == "eDNA_prop") c(0, 1) else c(1, 3)
    if (from == "Manta") args$from.scars <- c("a", "p")
    out <- suppressMessages(do.call(GBR_calibrate, args))
    expect_equal(attr(out, "model"), r$model_name)
    expect_equal(nrow(out), 2)
    cols <- grep("^(mean|lowerCI|upperCI|lowerPI|upperPI)_", names(out), value = TRUE)
    expect_length(cols, 5)
    expect_true(all(is.finite(as.matrix(out[cols]))), info = r$model_name)
    expect_true(all(out[[cols[4]]] <= out[[cols[2]]] + 1e-9 | coral), info = r$model_name)
  }
})

test_that("Beta (loglog) predictions match a direct calculation from the posterior", {
  post <- post_of("manta_from_surf_reef")
  expect_equal(attr(post, "link"), "loglog")
  set.seed(1)
  out <- GBR_calibrate("coral_surface", "coral_manta", "reef", from.metric = c(0.2, 0.4), sites = c("a", "a"))
  direct <- trimmed(exp(-exp(-(post[, "alpha"] + post[, "beta"] * 0.3))))
  expect_equal(out$mean_coral_manta, direct, tolerance = 0.02)
})

test_that("Negative Binomial predictions scale with effort and match a direct calculation", {
  post <- post_of("surf_from_manta_reef_cots")
  set.seed(2)
  out <- suppressMessages(GBR_calibrate(
    "Manta", "ReefScan_surface", "reef", from.metric = c(0, 2, 1, 0), from.scars = c("a", "p", "p", "a"),
    sites = rep("r", 4), to.nTows = 10
  ))
  x <- (3 + 2) / 4
  direct <- trimmed(exp(post[, "alpha"] + post[, "beta"] * log(x + 0.01) + log(10)))
  expect_equal(out$mean_ReefScan_surface, direct, tolerance = 0.03)
  expect_equal(out$Manta_density, x)
  out20 <- suppressMessages(GBR_calibrate(
    "Manta", "ReefScan_surface", "reef", from.metric = c(0, 2, 1, 0), from.scars = c("a", "p", "p", "a"),
    sites = rep("r", 4), to.nTows = 20
  ))
  expect_equal(out20$mean_ReefScan_surface / out$mean_ReefScan_surface, 2, tolerance = 0.05)
})

test_that("intervals are ordered and widen with intLevel", {
  set.seed(3)
  a <- GBR_calibrate("coral_deep", "coral_surface", "reef", from.metric = c(0.3, 0.5), sites = c("x", "y"), intLevel = 0.5)
  b <- GBR_calibrate("coral_deep", "coral_surface", "reef", from.metric = c(0.3, 0.5), sites = c("x", "y"), intLevel = 0.95)
  expect_true(all(b$upperCI_coral_surface - b$lowerCI_coral_surface > a$upperCI_coral_surface - a$lowerCI_coral_surface))
  expect_true(all(b$lowerPI_coral_surface <= b$lowerCI_coral_surface & b$upperPI_coral_surface >= b$upperCI_coral_surface))
})

test_that("input is aggregated per site", {
  out <- suppressMessages(GBR_calibrate(
    "ReefScan_surface", "ReefScan_deep", "cull_site", from.metric = c(1, 2, 0, 4), from.effort = c(1, 1, 2, 2),
    sites = c("a", "a", "b", "b")
  ))
  expect_equal(out$site, c("a", "b"))
  expect_equal(out$ReefScan_surface_COTS, c(3, 4))
  expect_equal(out$ReefScan_surface_effort, c(2, 4))
  expect_equal(out$ReefScan_surface_density, c(1.5, 1))

  eco <- GBR_calibrate("eDNA_conc", "eDNA_prop", "reef", from.metric = c(10, 20, NA, 30), sites = rep("r", 4))
  expect_equal(eco$eDNA_conc_sum, 60)
  expect_equal(eco$eDNA_conc_assays, 3)
})

test_that("manta ordinal coral categories are converted to midpoints", {
  a <- GBR_calibrate("coral_manta", "coral_surface", "reef", from.metric = c("2-", "2+"), sites = c("r", "r"))
  expect_equal(a$coral_manta_cover, 0.2)
  expect_error(GBR_calibrate("coral_manta", "coral_surface", "reef", from.metric = "9z", sites = "r"), "Unrecognised")
})

test_that("'transom' is accepted as an alias for 'surface'", {
  a <- GBR_calibrate("coral_transom", "coral_manta", "reef", from.metric = c(0.2, 0.3), sites = c("r", "r"))
  expect_true("mean_coral_manta" %in% names(a))
})

test_that("bad requests give informative errors", {
  expect_error(GBR_calibrate("coral_manta", "Manta", "reef", from.metric = 0.2, sites = "r"), "within")
  expect_error(GBR_calibrate("eDNA_conc", "Manta", "tow", from.metric = 1), "Available levels: reef")
  expect_error(GBR_calibrate("eDNA_conc", "Manta", "reef", from.metric = 1, sites = "r", to.type = "count"), "to.type")
  expect_error(GBR_calibrate("Manta", "ReefScan_deep", "reef", from.metric = 1, sites = "r"), "from.scars")
  expect_error(GBR_calibrate("coral_deep", "coral_manta", "reef", from.metric = 20, sites = "r"), "proportion")
  expect_error(GBR_calibrate("nonsense", "Manta", from.metric = 1), "Unknown")
  expect_error(GBR_calibrate("ReefScan_surface", "Manta", "tow", from.metric = c(1, 2), sites = c("a", "a")), "unique")
  expect_warning(
    suppressMessages(GBR_calibrate("ReefScan_surface", "ReefScan_deep", "reef", from.metric = c(1, 2))),
    "single site"
  )
  expect_warning(
    r <- GBR_calibrate("Manta", "Manta", "reef", from.metric = 1, from.scars = "a", sites = "r"),
    "same"
  )
  expect_s3_class(r, "data.frame")
})

test_that("the reef-level new-reef effect widens only the presence prediction interval", {
  post <- post_of("manta_from_surf_binary_reef_cots")
  model <- as.list(RosettaGBR:::loadRegistry()[RosettaGBR:::loadRegistry()$model_name == "manta_from_surf_binary_reef_cots", ])
  post_no_re <- post
  attr(post_no_re, "obs_re_sd") <- NULL
  set.seed(11)
  with_re <- RosettaGBR:::predictModel(model, post, x = 0.5, effort = NA, size = 50, intLevel = 0.95)
  set.seed(11)
  without_re <- RosettaGBR:::predictModel(model, post_no_re, x = 0.5, effort = NA, size = 50, intLevel = 0.95)
  expect_equal(with_re[, c("lowerCI", "upperCI")], without_re[, c("lowerCI", "upperCI")])
  expect_gt(with_re[, "upperPI"] - with_re[, "lowerPI"], without_re[, "upperPI"] - without_re[, "lowerPI"])
})
