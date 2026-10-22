
test_that("GBR_curve() returns a plot-ready curve with the expected structure", {
  set.seed(21)
  cv <- GBR_curve("coral_surface", "coral_manta", level = "reef", nPoints = 30)
  expect_s3_class(cv, "GBR_curve")
  expect_s3_class(cv, "data.frame")
  expect_named(cv, c("x", "mean", "lowerCI", "upperCI", "lowerPI", "upperPI", "observed"))
  expect_equal(nrow(cv), 30)
  expect_true(all(cv$observed))
  expect_true(all(cv$lowerPI <= cv$lowerCI & cv$upperPI >= cv$upperCI))
  expect_equal(attr(cv, "model"), "manta_from_surf_reef")
  expect_match(attr(cv, "xlab"), "ReefScan_surface")
  expect_true(all(diff(cv$mean) > 0))   # loglog curve increases with surface cover
})

test_that("GBR_curve() agrees with GBR_calibrate() at the same predictor value", {
  set.seed(5)
  cv <- GBR_curve("coral_deep", "coral_surface", level = "cull_site", x = 0.3)
  set.seed(5)
  ca <- GBR_calibrate("coral_deep", "coral_surface", level = "cull_site", from.metric = 0.3, sites = "s")
  expect_equal(cv$mean, ca$mean_coral_surface, tolerance = 0.03)
})

test_that("GBR_curve() COTS curves respect effort and flag extrapolation", {
  set.seed(8)
  a <- suppressMessages(GBR_curve("Manta", "ReefScan_surface", "reef", x = c(0.5, 5), to.nTows = 10, to.type = "count"))
  set.seed(8)
  b <- suppressMessages(GBR_curve("Manta", "ReefScan_surface", "reef", x = c(0.5, 5), to.nTows = 20, to.type = "count"))
  expect_equal(b$mean / a$mean, c(2, 2), tolerance = 1e-6)
  expect_equal(a$observed, c(TRUE, FALSE))
  expect_equal(unname(attr(a, "effort")), 10)
  expect_match(attr(a, "ylab"), "10 tows")
  g <- suppressMessages(GBR_curve("eDNA_conc", "Manta", "reef", nPoints = 10))
  expect_equal(g$x[1], 0)
  expect_true(all(diff(g$x) > 0))
})

test_that("GBR_curve() validates input", {
  expect_error(GBR_curve("coral_deep", "coral_surface", x = 5), "proportion")
  expect_error(GBR_curve("coral_deep", "coral_surface", x = -1), "non-negative")
  expect_error(GBR_curve("coral_deep", "Manta"), "within")
  expect_error(GBR_curve("Manta", "Manta"), "same")
  expect_error(GBR_curve("eDNA_conc", "Manta", level = "tow"), "Available levels")
})

test_that("plot.GBR_curve() draws without error", {
  set.seed(2)
  cv <- GBR_curve("coral_surface", "coral_manta", level = "tow", x = c(0.1, 0.5, 0.95))
  pdf(NULL); on.exit(dev.off())
  expect_silent(plot(cv))
  expect_false(all(cv$observed))
})

test_that("GBR_posterior() returns the bundled draws with model information", {
  d <- GBR_posterior("coral_surface", "coral_manta", level = "reef")
  expect_s3_class(d, "data.frame")
  expect_true(all(c("alpha", "beta", "phi") %in% names(d)))
  info <- attr(d, "model_info")
  expect_equal(info$model, "manta_from_surf_reef")
  expect_equal(info$link, "loglog")
  expect_equal(info$family, "beta")
  expect_match(info$equation, "Beta regression")

  n <- GBR_posterior("Manta", "ReefScan_surface", "cull_site")
  expect_true("r" %in% names(n))
  expect_true(attr(n, "model_info")$offset)

  b <- GBR_posterior("eDNA_conc", "Manta", "reef")
  expect_true("obs_re_sd" %in% names(b))
  expect_match(attr(b, "model_info")$equation, "obs_re_sd")
})

test_that("GBR_posterior(summary = TRUE) summarises each parameter", {
  s <- GBR_posterior("Manta", "ReefScan_surface", "reef", summary = TRUE)
  d <- GBR_posterior("Manta", "ReefScan_surface", "reef")
  expect_equal(s$parameter, names(d))
  expect_equal(s$mean, unname(colMeans(d)))
  expect_true(all(s$q2.5 < s$q50 & s$q50 < s$q97.5))
  expect_equal(attr(s, "model_info")$model, "surf_from_manta_reef_cots")
})
